"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { createHmac, randomUUID } from "node:crypto";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { openSealedSecret } from "./lib/secrets";

const RAPYD_PROVIDER = "rapyd" as const;

const getEnv = (name: string): string => {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
};

const toAgorot = (nisAmount: number): number =>
  Math.max(0, Math.round(nisAmount * 100));

const buildRapydSignature = ({
  method,
  path,
  salt,
  timestamp,
  accessKey,
  secretKey,
  body,
}: {
  method: string;
  path: string;
  salt: string;
  timestamp: string;
  accessKey: string;
  secretKey: string;
  body: string;
}): string => {
  const toSign = `${method.toLowerCase()}${path}${salt}${timestamp}${accessKey}${secretKey}${body}`;
  const hmacHex = createHmac("sha256", secretKey).update(toSign).digest("hex");
  return Buffer.from(hmacHex, "hex").toString("base64");
};

type CheckoutContext = {
  user: {
    _id: Id<"users">;
    role: "studio" | "instructor";
    email: string;
    name: string;
    businessName?: string;
  };
  job: {
    _id: Id<"jobs">;
    studioId: Id<"users">;
    claimedBy?: Id<"users">;
    status:
      | "open"
      | "claimed"
      | "backup_claimed"
      | "confirmed"
      | "completed"
      | "cancelled"
      | "expired";
    title: string;
    startTime: number;
    currentRate: number;
  };
};

type StudioPaymentIntegration = {
  provider: "rapyd" | "bitpay";
  mode: "sandbox" | "production";
  apiToken?: string;
  apiKey?: string;
  sealedApiToken?: string;
  sealedApiKey?: string;
};

type CreateCheckoutResult = {
  paymentId: Id<"payments">;
  provider: "rapyd";
  checkoutId: string;
  checkoutUrl: string;
  amountAgorot: number;
  feeAmountAgorot: number;
  netAmountAgorot: number;
  currency: string;
  idempotencyKey: string;
};

export const createCheckoutForJob = action({
  args: {
    jobId: v.id("jobs"),
    returnUrl: v.string(),
    cancelUrl: v.optional(v.string()),
    idempotencyKey: v.optional(v.string()),
  },
  handler: async (
    ctx,
    { jobId, returnUrl, cancelUrl, idempotencyKey },
  ): Promise<CreateCheckoutResult> => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const checkoutContext: CheckoutContext | null = (await ctx.runQuery(
      internal.payments.getCheckoutContext,
      {
        firebaseUid: identity.subject,
        jobId,
      },
    )) as CheckoutContext | null;
    if (!checkoutContext) throw new Error("User or job not found");

    const { user, job } = checkoutContext;
    if (user.role !== "studio")
      throw new Error("Only studios can create job payments");
    if (job.studioId !== user._id)
      throw new Error("Unauthorized job payment attempt");
    if (!["confirmed", "completed"].includes(job.status)) {
      throw new Error("Job is not payable yet");
    }

    const currency = (process.env.PAYMENTS_CURRENCY ?? "ILS")
      .trim()
      .toUpperCase();
    const feeBps = Math.min(
      5000,
      Math.max(
        0,
        Number.parseInt(process.env.QUICKFIT_PLATFORM_FEE_BPS ?? "1200", 10),
      ),
    );
    const grossAmountAgorot = toAgorot(job.currentRate);
    const feeAmountAgorot = Math.floor((grossAmountAgorot * feeBps) / 10000);
    const netAmountAgorot = Math.max(0, grossAmountAgorot - feeAmountAgorot);
    const effectiveIdempotencyKey =
      idempotencyKey?.trim() || `${RAPYD_PROVIDER}:${user._id}:${job._id}`;

    const paymentIntegration = (await ctx.runQuery(
      internal.billing.getActiveStudioPaymentIntegration,
      { studioId: user._id },
    )) as StudioPaymentIntegration | null;
    if (paymentIntegration && paymentIntegration.provider !== RAPYD_PROVIDER) {
      throw new Error(
        `Active payment provider is ${paymentIntegration.provider}. Use matching checkout action.`,
      );
    }

    const pendingPayment: { _id: Id<"payments"> } | null =
      (await ctx.runMutation(internal.payments.createPendingPayment, {
        jobId: job._id,
        studioId: user._id,
        instructorId: job.claimedBy,
        provider: RAPYD_PROVIDER,
        currency,
        grossAmountAgorot,
        feeAmountAgorot,
        netAmountAgorot,
        feeBps,
        idempotencyKey: effectiveIdempotencyKey,
        metadata: {
          jobTitle: job.title,
          jobStartTime: job.startTime,
        },
      })) as { _id: Id<"payments"> } | null;
    if (!pendingPayment) throw new Error("Failed to create pending payment");

    const accessKey =
      paymentIntegration?.sealedApiToken != null
        ? await openSealedSecret(paymentIntegration.sealedApiToken)
        : paymentIntegration?.apiToken?.trim() || getEnv("RAPYD_ACCESS_KEY");
    const secretKey =
      paymentIntegration?.sealedApiKey != null
        ? await openSealedSecret(paymentIntegration.sealedApiKey)
        : paymentIntegration?.apiKey?.trim() || getEnv("RAPYD_SECRET_KEY");
    const rapydBaseUrl = (
      paymentIntegration?.mode === "production"
        ? (process.env.RAPYD_PROD_BASE_URL ??
          process.env.RAPYD_BASE_URL ??
          "https://api.rapyd.net")
        : (process.env.RAPYD_SANDBOX_BASE_URL ??
          process.env.RAPYD_BASE_URL ??
          "https://sandboxapi.rapyd.net")
    ).trim();

    const requestPath = "/v1/checkout";
    const country = (process.env.RAPYD_COUNTRY ?? "IL").trim().toUpperCase();
    const bodyPayload = {
      amount: Number((grossAmountAgorot / 100).toFixed(2)),
      complete_checkout_url: returnUrl,
      cancel_checkout_url: cancelUrl,
      country,
      currency,
      customer: {
        email: user.email,
        name: user.businessName ?? user.name,
      },
      merchant_reference_id: pendingPayment._id,
      metadata: {
        paymentId: pendingPayment._id,
        jobId: job._id,
        studioId: user._id,
        feeAmountAgorot,
        netAmountAgorot,
      },
      payment_method_types_include: ["il_card", "apple_pay", "google_pay"],
    };
    const body = JSON.stringify(bodyPayload);
    const timestamp = Math.floor(Date.now() / 1000).toString();
    const salt = randomUUID().replace(/-/g, "");
    const signature = buildRapydSignature({
      method: "POST",
      path: requestPath,
      salt,
      timestamp,
      accessKey,
      secretKey,
      body,
    });

    const response = await fetch(`${rapydBaseUrl}${requestPath}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        access_key: accessKey,
        salt,
        timestamp,
        signature,
        idempotency: effectiveIdempotencyKey,
      },
      body,
    });

    const responseText = await response.text();
    if (!response.ok) {
      await ctx.runMutation(internal.payments.markPaymentError, {
        paymentId: pendingPayment._id,
        error: `Rapyd checkout HTTP ${response.status}: ${responseText.slice(0, 500)}`,
      });
      throw new Error("Failed to create Rapyd checkout");
    }

    const payload = JSON.parse(responseText) as {
      status?: { status?: string; error_code?: string; message?: string };
      data?: {
        id?: string;
        payment?: { id?: string; status?: string };
        redirect_url?: string;
        complete_checkout_url?: string;
      };
    };

    const providerStatus = payload.status?.status ?? "ERROR";
    if (providerStatus !== "SUCCESS" || !payload.data?.id) {
      await ctx.runMutation(internal.payments.markPaymentError, {
        paymentId: pendingPayment._id,
        error: `Rapyd checkout rejected: ${
          payload.status?.message ??
          payload.status?.error_code ??
          "Unknown error"
        }`,
      });
      throw new Error("Rapyd checkout request was rejected");
    }

    await ctx.runMutation(internal.payments.markCheckoutCreated, {
      paymentId: pendingPayment._id,
      providerCheckoutId: payload.data.id,
      providerPaymentId: payload.data.payment?.id,
      metadata: {
        rapydProviderStatus: providerStatus,
      },
    });

    return {
      paymentId: pendingPayment._id,
      provider: RAPYD_PROVIDER,
      checkoutId: payload.data.id,
      checkoutUrl:
        payload.data.redirect_url ??
        payload.data.complete_checkout_url ??
        returnUrl,
      amountAgorot: grossAmountAgorot,
      feeAmountAgorot,
      netAmountAgorot,
      currency,
      idempotencyKey: effectiveIdempotencyKey,
    };
  },
});
