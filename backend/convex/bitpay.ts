"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";

const BITPAY_PROVIDER = "bitpay" as const;
const ENABLE_BITPAY_CHECKOUT = process.env.ENABLE_BITPAY_CHECKOUT === "true";

const toAgorot = (nisAmount: number): number =>
  Math.max(0, Math.round(nisAmount * 100));

type CheckoutContext = {
  user: {
    _id: Id<"users">;
    role: "studio" | "instructor";
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

type CreateCheckoutResult = {
  paymentId: Id<"payments">;
  provider: "bitpay";
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
    idempotencyKey: v.optional(v.string()),
  },
  handler: async (
    ctx,
    { jobId, returnUrl, idempotencyKey },
  ): Promise<CreateCheckoutResult> => {
    if (!ENABLE_BITPAY_CHECKOUT) {
      throw new Error(
        "BitPay checkout is disabled. Use Rapyd checkout for platform-managed payments.",
      );
    }

    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const checkoutContext = (await ctx.runQuery(
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

    const bitpayMode = (process.env.BITPAY_MODE ?? "sandbox")
      .trim()
      .toLowerCase();
    const isProduction = bitpayMode === "production";
    const token = (
      isProduction
        ? (process.env.BITPAY_PROD_API_TOKEN ?? process.env.BITPAY_API_TOKEN)
        : (process.env.BITPAY_SANDBOX_API_TOKEN ?? process.env.BITPAY_API_TOKEN)
    )?.trim() ?? "";
    if (!token) throw new Error("BitPay API token is missing");

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
      idempotencyKey?.trim() || `${BITPAY_PROVIDER}:${user._id}:${job._id}`;

    const pendingPayment = (await ctx.runMutation(
      internal.payments.createPendingPayment,
      {
        jobId: job._id,
        studioId: user._id,
        instructorId: job.claimedBy,
        provider: BITPAY_PROVIDER,
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
      },
    )) as { _id: Id<"payments"> } | null;
    if (!pendingPayment) throw new Error("Failed to create pending payment");

    const bitpayBaseUrl = (
      isProduction
        ? (process.env.BITPAY_PROD_BASE_URL ??
          process.env.BITPAY_BASE_URL ??
          "https://bitpay.com/api")
        : (process.env.BITPAY_SANDBOX_BASE_URL ??
          process.env.BITPAY_BASE_URL ??
          "https://test.bitpay.com/api")
    ).trim();
    if (!bitpayBaseUrl) throw new Error("BitPay base URL is not configured");

    const body = {
      price: Number((grossAmountAgorot / 100).toFixed(2)),
      currency,
      token,
      orderId: pendingPayment._id,
      notificationURL: process.env.BITPAY_WEBHOOK_URL?.trim(),
      redirectURL: returnUrl,
      itemDesc: `QuickFit job: ${job.title}`,
      extendedNotifications: true,
      transactionSpeed: "medium",
      posData: JSON.stringify({
        paymentId: pendingPayment._id,
        jobId: job._id,
        studioId: user._id,
      }),
    };

    const response = await fetch(`${bitpayBaseUrl.replace(/\/+$/, "")}/invoices`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-accept-version": "2.0.0",
      },
      body: JSON.stringify(body),
    });

    const responseText = await response.text();
    if (!response.ok) {
      await ctx.runMutation(internal.payments.markPaymentError, {
        paymentId: pendingPayment._id,
        error: `BitPay checkout HTTP ${response.status}: ${responseText.slice(0, 500)}`,
      });
      throw new Error("Failed to create BitPay checkout");
    }

    const payload = JSON.parse(responseText) as {
      data?: { id?: string; url?: string };
    };
    const checkoutId = payload.data?.id?.toString().trim();
    if (!checkoutId) {
      await ctx.runMutation(internal.payments.markPaymentError, {
        paymentId: pendingPayment._id,
        error: "BitPay response missing checkout id",
      });
      throw new Error("BitPay checkout response was invalid");
    }

    await ctx.runMutation(internal.payments.markCheckoutCreated, {
      paymentId: pendingPayment._id,
      providerCheckoutId: checkoutId,
      providerPaymentId: checkoutId,
      metadata: {
        bitpayInvoiceId: checkoutId,
      },
    });

    return {
      paymentId: pendingPayment._id,
      provider: BITPAY_PROVIDER,
      checkoutId,
      checkoutUrl: payload.data?.url?.toString().trim() || returnUrl,
      amountAgorot: grossAmountAgorot,
      feeAmountAgorot,
      netAmountAgorot,
      currency,
      idempotencyKey: effectiveIdempotencyKey,
    };
  },
});
