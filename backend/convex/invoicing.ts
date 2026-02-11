import { internalAction } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { openSealedSecret } from "./lib/secrets";
import { validateAndNormalizeProviderBaseUrl } from "./lib/urlSecurity";

type InvoiceProvider = "morning" | "icount";
type InvoiceResult =
  | { skipped: true; reason: string; invoiceId?: Id<"invoices"> }
  | {
      success: true;
      provider: InvoiceProvider;
      invoiceId: Id<"invoices">;
      externalInvoiceId: string;
    };

type InvoicingContext = {
  payment: {
    _id: Id<"payments">;
    status:
      | "created"
      | "pending"
      | "authorized"
      | "captured"
      | "failed"
      | "cancelled"
      | "refunded";
    currency: string;
    grossAmountAgorot: number;
  };
  studio: {
    _id: Id<"users">;
    name: string;
    businessName?: string;
    email: string;
  };
  job: { title: string };
};
type StudioIntegration = {
  provider: InvoiceProvider;
  baseUrl: string;
  apiToken?: string;
  apiKey?: string;
  sealedApiToken?: string;
  sealedApiKey?: string;
  accountId?: string;
  defaultVatRate?: number;
};

const toNis = (amountAgorot: number): number =>
  Number((amountAgorot / 100).toFixed(2));

export const issueInvoiceForPayment = internalAction({
  args: { paymentId: v.id("payments") },
  handler: async (ctx, { paymentId }): Promise<InvoiceResult> => {
    const context: InvoicingContext | null = (await ctx.runQuery(
      internal.payments.getPaymentForInvoicing,
      {
        paymentId,
      },
    )) as InvoicingContext | null;
    if (!context?.payment || !context.studio || !context.job) {
      throw new Error("Missing payment context for invoicing");
    }
    if (context.payment.status !== "captured") {
      return { skipped: true, reason: "payment_not_captured" as const };
    }

    const studioIntegration = (await ctx.runQuery(
      internal.billing.getActiveStudioInvoicingIntegration,
      { studioId: context.studio._id },
    )) as StudioIntegration | null;

    let provider: InvoiceProvider | null = studioIntegration?.provider ?? null;
    if (!provider) {
      const envProvider = (process.env.INVOICE_PROVIDER ?? "")
        .trim()
        .toLowerCase();
      if (envProvider === "morning" || envProvider === "icount") {
        provider = envProvider;
      }
    }
    if (!provider) {
      return {
        skipped: true,
        reason: "studio_invoice_provider_not_configured" as const,
      };
    }

    const invoice: { _id: Id<"invoices">; status: string } | null =
      (await ctx.runMutation(internal.payments.createInvoiceRecord, {
        paymentId,
        provider,
        currency: context.payment.currency,
        amountAgorot: context.payment.grossAmountAgorot,
        vatRate:
          studioIntegration?.defaultVatRate ??
          Number.parseFloat(process.env.INVOICE_DEFAULT_VAT_RATE ?? "18"),
      })) as { _id: Id<"invoices">; status: string } | null;
    if (!invoice) throw new Error("Failed to create invoice record");
    if (invoice.status === "issued") {
      return {
        skipped: true,
        reason: "already_issued" as const,
        invoiceId: invoice._id,
      };
    }

    try {
      const externalInvoiceId =
        provider === "morning"
          ? await issueMorningInvoice({
              paymentId,
              invoiceId: invoice._id,
              amountAgorot: context.payment.grossAmountAgorot,
              currency: context.payment.currency,
              customerName: context.studio.businessName ?? context.studio.name,
              customerEmail: context.studio.email,
              description: `QuickFit job: ${context.job.title}`,
              integration: studioIntegration,
            })
          : await issueIcountInvoice({
              paymentId,
              invoiceId: invoice._id,
              amountAgorot: context.payment.grossAmountAgorot,
              currency: context.payment.currency,
              customerName: context.studio.businessName ?? context.studio.name,
              customerEmail: context.studio.email,
              description: `QuickFit job: ${context.job.title}`,
              integration: studioIntegration,
            });

      await ctx.runMutation(internal.payments.markInvoiceIssued, {
        invoiceId: invoice._id,
        externalInvoiceId,
      });
      return {
        success: true,
        provider,
        invoiceId: invoice._id,
        externalInvoiceId,
      };
    } catch (error) {
      await ctx.runMutation(internal.payments.markInvoiceFailed, {
        invoiceId: invoice._id,
        error: error instanceof Error ? error.message : "Unknown invoice error",
      });
      throw error;
    }
  },
});

const issueMorningInvoice = async ({
  paymentId,
  invoiceId,
  amountAgorot,
  currency,
  customerName,
  customerEmail,
  description,
  integration,
}: {
  paymentId: string;
  invoiceId: string;
  amountAgorot: number;
  currency: string;
  customerName: string;
  customerEmail: string;
  description: string;
  integration: StudioIntegration | null;
}): Promise<string> => {
  const tokenFromIntegration =
    integration?.provider === "morning"
      ? integration.sealedApiToken
        ? await openSealedSecret(integration.sealedApiToken)
        : integration.apiToken?.trim()
      : undefined;
  const apiBase =
    integration?.provider === "morning"
      ? validateAndNormalizeProviderBaseUrl("morning", integration.baseUrl)
      : process.env.MORNING_API_BASE_URL?.trim();
  const token =
    integration?.provider === "morning"
      ? tokenFromIntegration
      : process.env.MORNING_API_TOKEN?.trim();
  if (!apiBase || !token) {
    throw new Error("Morning API is not configured");
  }

  const response = await fetch(`${apiBase.replace(/\/$/, "")}/documents`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      external_reference: paymentId,
      currency,
      amount: toNis(amountAgorot),
      customer: {
        name: customerName,
        email: customerEmail,
      },
      items: [
        {
          description,
          quantity: 1,
          unit_price: toNis(amountAgorot),
        },
      ],
      metadata: {
        invoiceId,
        accountId:
          integration?.provider === "morning"
            ? integration.accountId
            : undefined,
      },
    }),
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(
      `Morning API HTTP ${response.status}: ${text.slice(0, 500)}`,
    );
  }
  const payload = JSON.parse(text) as { id?: string; data?: { id?: string } };
  return payload.id ?? payload.data?.id ?? `${paymentId}-morning`;
};

const issueIcountInvoice = async ({
  paymentId,
  invoiceId,
  amountAgorot,
  currency,
  customerName,
  customerEmail,
  description,
  integration,
}: {
  paymentId: string;
  invoiceId: string;
  amountAgorot: number;
  currency: string;
  customerName: string;
  customerEmail: string;
  description: string;
  integration: StudioIntegration | null;
}): Promise<string> => {
  const apiKeyFromIntegration =
    integration?.provider === "icount"
      ? integration.sealedApiKey
        ? await openSealedSecret(integration.sealedApiKey)
        : integration.apiKey?.trim()
      : undefined;
  const apiBase =
    integration?.provider === "icount"
      ? validateAndNormalizeProviderBaseUrl("icount", integration.baseUrl)
      : process.env.ICOUNT_API_BASE_URL?.trim();
  const apiKey =
    integration?.provider === "icount"
      ? apiKeyFromIntegration
      : process.env.ICOUNT_API_KEY?.trim();
  if (!apiBase || !apiKey) {
    throw new Error("iCount API is not configured");
  }

  const response = await fetch(`${apiBase.replace(/\/$/, "")}/documents`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-API-KEY": apiKey,
    },
    body: JSON.stringify({
      external_reference: paymentId,
      currency_code: currency,
      customer_name: customerName,
      customer_email: customerEmail,
      items: [
        {
          description,
          quantity: 1,
          unit_price: toNis(amountAgorot),
        },
      ],
      metadata: {
        invoiceId,
        accountId:
          integration?.provider === "icount"
            ? integration.accountId
            : undefined,
      },
    }),
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(
      `iCount API HTTP ${response.status}: ${text.slice(0, 500)}`,
    );
  }
  const payload = JSON.parse(text) as { id?: string; data?: { id?: string } };
  return payload.id ?? payload.data?.id ?? `${paymentId}-icount`;
};
