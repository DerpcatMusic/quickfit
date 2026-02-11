import { internalAction, internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { openSealedSecret } from "./lib/secrets";

const RAPYD_PROVIDER = "rapyd" as const;
const TERMINAL_PAYOUT_STATUSES = new Set([
  "paid",
  "failed",
  "cancelled",
  "needs_attention",
]);
const DEFAULT_MAX_ATTEMPTS = 6;
const BASE_RETRY_MS = 30_000;
const MAX_RETRY_MS = 30 * 60 * 1000;

type PayoutStatus =
  | "queued"
  | "processing"
  | "pending_provider"
  | "paid"
  | "failed"
  | "cancelled"
  | "needs_attention";

const getOptionalEnv = (name: string): string | undefined => {
  const value = process.env[name]?.trim();
  return value && value.length > 0 ? value : undefined;
};

const clampInt = (value: number, min: number, max: number): number =>
  Math.min(max, Math.max(min, Math.floor(value)));

const buildRapydSignature = async ({
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
}): Promise<string> => {
  const toSign = `${method.toLowerCase()}${path}${salt}${timestamp}${accessKey}${secretKey}${body}`;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secretKey),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(toSign));
  const bytes = new Uint8Array(signature);
  const hex = Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return btoa(hex);
};

const normalizeRapydPayoutStatus = (
  rawStatus: string | undefined,
): { status: PayoutStatus; terminal: boolean } => {
  const status = (rawStatus ?? "").toUpperCase().trim();
  if (
    status === "CLO" ||
    status === "PAID" ||
    status === "COMPLETED" ||
    status === "SUCCESS"
  ) {
    return { status: "paid", terminal: true };
  }
  if (status === "CAN" || status === "CANCELLED" || status === "CANCELED") {
    return { status: "cancelled", terminal: true };
  }
  if (
    status === "ERR" ||
    status === "ERROR" ||
    status === "FAILED" ||
    status === "REJECTED" ||
    status === "DECLINED" ||
    status === "REV" ||
    status === "REVERSED" ||
    status === "EXPIRED"
  ) {
    return { status: "failed", terminal: true };
  }
  return { status: "pending_provider", terminal: false };
};

const computeRetryDelayMs = (attempt: number): number => {
  const backoff = Math.min(MAX_RETRY_MS, BASE_RETRY_MS * 2 ** (attempt - 1));
  const jitter = Math.min(5_000, attempt * 250);
  return backoff + jitter;
};

const isRetryableHttpFailure = (statusCode: number): boolean =>
  statusCode === 429 || statusCode >= 500;

const isLikelyPermanentRapydError = (errorCode: string | undefined): boolean => {
  const code = (errorCode ?? "").toUpperCase();
  return (
    code.includes("INVALID") ||
    code.includes("NOT_FOUND") ||
    code.includes("UNAUTHORIZED") ||
    code.includes("PERMISSION") ||
    code.includes("INSUFFICIENT_FUNDS")
  );
};

export const schedulePayoutForCapturedPayment = internalMutation({
  args: {
    paymentId: v.id("payments"),
    reason: v.optional(v.string()),
  },
  handler: async (ctx, { paymentId, reason }) => {
    const payment = await ctx.db.get(paymentId);
    if (!payment) return { scheduled: false, reason: "payment_missing" as const };
    if (payment.status !== "captured") {
      return { scheduled: false, reason: "payment_not_captured" as const };
    }
    if (!payment.instructorId) {
      return { scheduled: false, reason: "missing_instructor" as const };
    }

    const idempotencyKey = `payout:${payment._id}`;
    const existing = await ctx.db
      .query("payouts")
      .withIndex("by_idempotency", (q) => q.eq("idempotencyKey", idempotencyKey))
      .unique();
    if (existing) {
      return { scheduled: false, reason: "already_exists" as const, payoutId: existing._id };
    }

    const now = Date.now();
    const configuredMaxAttempts = clampInt(
      Number.parseInt(process.env.PAYOUT_MAX_ATTEMPTS ?? "", 10) ||
        DEFAULT_MAX_ATTEMPTS,
      1,
      20,
    );

    const payoutId = await ctx.db.insert("payouts", {
      paymentId: payment._id,
      jobId: payment.jobId,
      studioId: payment.studioId,
      instructorId: payment.instructorId,
      destinationId: undefined,
      provider: payment.provider,
      idempotencyKey,
      amountAgorot: payment.netAmountAgorot,
      currency: payment.currency,
      status: "queued",
      providerPayoutId: undefined,
      providerStatusRaw: undefined,
      attemptCount: 0,
      maxAttempts: configuredMaxAttempts,
      lastError: undefined,
      lastAttemptAt: undefined,
      nextRetryAt: undefined,
      terminalAt: undefined,
      createdAt: now,
      updatedAt: now,
    });

    await ctx.db.insert("payoutEvents", {
      payoutId,
      paymentId: payment._id,
      provider: payment.provider,
      eventType: "status_update",
      attempt: 0,
      message: reason ?? "scheduled_from_payment_capture",
      mappedStatus: "queued",
      createdAt: now,
    });

    await ctx.scheduler.runAfter(0, internal.payouts.runPayoutAttempt, {
      payoutId,
    });

    return { scheduled: true, payoutId };
  },
});

export const runPayoutAttempt = internalMutation({
  args: { payoutId: v.id("payouts") },
  handler: async (ctx, { payoutId }) => {
    const payout = await ctx.db.get(payoutId);
    if (!payout) return { started: false, reason: "missing" as const };
    if (TERMINAL_PAYOUT_STATUSES.has(payout.status)) {
      return { started: false, reason: "terminal" as const };
    }
    if (payout.status === "processing") {
      return { started: false, reason: "already_processing" as const };
    }

    const now = Date.now();
    if (payout.nextRetryAt && payout.nextRetryAt > now) {
      await ctx.scheduler.runAfter(
        payout.nextRetryAt - now,
        internal.payouts.runPayoutAttempt,
        { payoutId },
      );
      return { started: false, reason: "not_due" as const };
    }

    const payment = await ctx.db.get(payout.paymentId);
    if (!payment) {
      await ctx.db.patch(payoutId, {
        status: "needs_attention",
        lastError: "Missing source payment",
        terminalAt: now,
        updatedAt: now,
      });
      return { started: false, reason: "payment_missing" as const };
    }

    if (payment.status !== "captured") {
      const cancelled = ["cancelled", "failed", "refunded"].includes(payment.status);
      const nextStatus: PayoutStatus = cancelled ? "cancelled" : "needs_attention";
      await ctx.db.patch(payoutId, {
        status: nextStatus,
        lastError: `Payment status is ${payment.status}; payout halted`,
        terminalAt: now,
        updatedAt: now,
      });
      await ctx.db.insert("payoutEvents", {
        payoutId,
        paymentId: payout.paymentId,
        provider: payout.provider,
        eventType: "terminal_failure",
        attempt: payout.attemptCount,
        statusRaw: payment.status,
        mappedStatus: nextStatus,
        message: "Payment left captured state",
        createdAt: now,
      });
      return { started: false, reason: "payment_not_captured" as const };
    }

    const attempt = payout.attemptCount + 1;
    await ctx.db.patch(payoutId, {
      status: "processing",
      attemptCount: attempt,
      lastAttemptAt: now,
      nextRetryAt: undefined,
      updatedAt: now,
    });

    await ctx.db.insert("payoutEvents", {
      payoutId,
      paymentId: payout.paymentId,
      provider: payout.provider,
      eventType: "attempt_started",
      attempt,
      mappedStatus: "processing",
      createdAt: now,
    });

    await ctx.scheduler.runAfter(0, internal.payouts.executePayoutAttemptAction, {
      payoutId,
      attempt,
    });

    return { started: true, attempt };
  },
});

export const getPayoutExecutionContext = internalQuery({
  args: { payoutId: v.id("payouts") },
  handler: async (ctx, { payoutId }) => {
    const payout = await ctx.db.get(payoutId);
    if (!payout) return null;

    const [payment, integration] = await Promise.all([
      ctx.db.get(payout.paymentId),
      ctx.db
        .query("studioPaymentIntegrations")
        .withIndex("by_studio_provider", (q) =>
          q.eq("studioId", payout.studioId).eq("provider", payout.provider),
        )
        .unique(),
    ]);
    if (!payment) return null;

    const defaultDestinations = await ctx.db
      .query("payoutDestinations")
      .withIndex("by_user_default", (q) =>
        q.eq("userId", payout.instructorId).eq("isDefault", true),
      )
      .order("desc")
      .take(1);
    const destination =
      defaultDestinations[0] ??
      (await ctx.db
        .query("payoutDestinations")
        .withIndex("by_user", (q) => q.eq("userId", payout.instructorId))
        .order("desc")
        .first());

    return {
      payout,
      payment,
      destination: destination ?? null,
      integration: integration ?? null,
    };
  },
});

export const executePayoutAttemptAction = internalAction({
  args: {
    payoutId: v.id("payouts"),
    attempt: v.number(),
  },
  handler: async (ctx, { payoutId, attempt }) => {
    const context = await ctx.runQuery(internal.payouts.getPayoutExecutionContext, {
      payoutId,
    });
    if (!context) return;

    const { payout, payment, destination, integration } = context;
    if (payout.status !== "processing" || payout.attemptCount !== attempt) return;

    if (payment.status !== "captured") {
      await ctx.runMutation(internal.payouts.recordPayoutAttemptResult, {
        payoutId,
        attempt,
        mappedStatus: "cancelled",
        retryable: false,
        message: `Payment status changed to ${payment.status}`,
      });
      return;
    }

    if (payout.provider !== RAPYD_PROVIDER) {
      await ctx.runMutation(internal.payouts.recordPayoutAttemptResult, {
        payoutId,
        attempt,
        mappedStatus: "needs_attention",
        retryable: false,
        message: `Unsupported payout provider: ${payout.provider}`,
      });
      return;
    }

    if (!destination) {
      await ctx.runMutation(internal.payouts.recordPayoutAttemptResult, {
        payoutId,
        attempt,
        mappedStatus: "queued",
        retryable: true,
        errorCode: "missing_destination",
        message: "Instructor payout destination is not configured",
      });
      return;
    }

    if (destination.provider !== RAPYD_PROVIDER) {
      await ctx.runMutation(internal.payouts.recordPayoutAttemptResult, {
        payoutId,
        attempt,
        mappedStatus: "needs_attention",
        retryable: false,
        errorCode: "provider_mismatch",
        message: `Destination provider ${destination.provider} does not match payout provider ${payout.provider}`,
      });
      return;
    }

    if (!integration?.isActive) {
      await ctx.runMutation(internal.payouts.recordPayoutAttemptResult, {
        payoutId,
        attempt,
        mappedStatus: "queued",
        retryable: true,
        errorCode: "integration_inactive",
        message: "Active studio payment integration is required for payouts",
      });
      return;
    }

    const accessKey =
      integration.sealedApiToken != null
        ? await openSealedSecret(integration.sealedApiToken)
        : (integration.apiToken?.trim() ?? getOptionalEnv("RAPYD_ACCESS_KEY") ?? "");
    const secretKey =
      integration.sealedApiKey != null
        ? await openSealedSecret(integration.sealedApiKey)
        : (integration.apiKey?.trim() ?? getOptionalEnv("RAPYD_SECRET_KEY") ?? "");
    const ewalletId =
      integration.accountId?.trim() ?? getOptionalEnv("RAPYD_EWALLET") ?? "";
    const payoutMethodType = destination.type.trim();
    const beneficiaryId = destination.externalRecipientId.trim();

    if (!accessKey || !secretKey || !ewalletId || !beneficiaryId || !payoutMethodType) {
      await ctx.runMutation(internal.payouts.recordPayoutAttemptResult, {
        payoutId,
        attempt,
        mappedStatus: "needs_attention",
        retryable: false,
        errorCode: "configuration_error",
        message: "Missing Rapyd payout credentials, ewallet, or destination details",
      });
      return;
    }

    const rapydBaseUrl = (
      integration.mode === "production"
        ? (process.env.RAPYD_PROD_BASE_URL ??
          process.env.RAPYD_BASE_URL ??
          "https://api.rapyd.net")
        : (process.env.RAPYD_SANDBOX_BASE_URL ??
          process.env.RAPYD_BASE_URL ??
          "https://sandboxapi.rapyd.net")
    ).trim();
    const requestPath = "/v1/payouts";
    const country = (destination.country ?? process.env.RAPYD_COUNTRY ?? "IL")
      .trim()
      .toUpperCase();
    const bodyPayload: Record<string, unknown> = {
      beneficiary: beneficiaryId,
      beneficiary_country: country,
      beneficiary_entity_type: "individual",
      confirm_automatically: true,
      description: `QuickFit payout for payment ${payment._id}`,
      ewallet: ewalletId,
      merchant_reference_id: payout._id,
      payout_amount: Number((payout.amountAgorot / 100).toFixed(2)),
      payout_currency: payout.currency,
      payout_method_type: payoutMethodType,
      sender_country: country,
      sender_currency: payout.currency,
      sender_entity_type: "company",
      metadata: {
        payoutId: payout._id,
        paymentId: payment._id,
        instructorId: payout.instructorId,
      },
    };
    const senderId = integration.merchantId?.trim();
    if (senderId) {
      bodyPayload.sender = senderId;
    }

    const body = JSON.stringify(bodyPayload);
    const timestamp = Math.floor(Date.now() / 1000).toString();
    const salt = crypto.randomUUID().replace(/-/g, "");
    const signature = await buildRapydSignature({
      method: "POST",
      path: requestPath,
      salt,
      timestamp,
      accessKey,
      secretKey,
      body,
    });

    try {
      const response = await fetch(`${rapydBaseUrl}${requestPath}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          access_key: accessKey,
          salt,
          timestamp,
          signature,
          idempotency: payout.idempotencyKey,
        },
        body,
      });

      const responseText = await response.text();
      if (!response.ok) {
        await ctx.runMutation(internal.payouts.recordPayoutAttemptResult, {
          payoutId,
          attempt,
          mappedStatus: "queued",
          retryable: isRetryableHttpFailure(response.status),
          httpStatus: response.status,
          message: `Rapyd payout HTTP ${response.status}: ${responseText.slice(0, 500)}`,
        });
        return;
      }

      let payload: {
        status?: { status?: string; error_code?: string; message?: string };
        data?: { id?: string; status?: string };
      };
      try {
        payload = JSON.parse(responseText) as {
          status?: { status?: string; error_code?: string; message?: string };
          data?: { id?: string; status?: string };
        };
      } catch {
        await ctx.runMutation(internal.payouts.recordPayoutAttemptResult, {
          payoutId,
          attempt,
          mappedStatus: "queued",
          retryable: true,
          errorCode: "invalid_json",
          message: "Rapyd payout response was not valid JSON",
        });
        return;
      }

      const operationStatus = (payload.status?.status ?? "").toUpperCase();
      const operationErrorCode = payload.status?.error_code;
      const operationMessage = payload.status?.message;
      if (operationStatus && operationStatus !== "SUCCESS") {
        await ctx.runMutation(internal.payouts.recordPayoutAttemptResult, {
          payoutId,
          attempt,
          mappedStatus: "queued",
          retryable: !isLikelyPermanentRapydError(operationErrorCode),
          errorCode: operationErrorCode,
          message: operationMessage ?? "Rapyd payout request rejected",
          payload,
        });
        return;
      }

      const rawProviderStatus = payload.data?.status;
      const mapped = normalizeRapydPayoutStatus(rawProviderStatus);
      await ctx.runMutation(internal.payouts.recordPayoutAttemptResult, {
        payoutId,
        attempt,
        mappedStatus: mapped.status,
        retryable: false,
        providerPayoutId: payload.data?.id,
        providerStatusRaw: rawProviderStatus,
        message: mapped.terminal
          ? "Payout reached terminal status from provider response"
          : "Payout accepted by provider and pending settlement",
        payload,
      });
    } catch (error) {
      await ctx.runMutation(internal.payouts.recordPayoutAttemptResult, {
        payoutId,
        attempt,
        mappedStatus: "queued",
        retryable: true,
        errorCode: "request_exception",
        message:
          error instanceof Error ? error.message : "Unknown payout request error",
      });
    }
  },
});

export const recordPayoutAttemptResult = internalMutation({
  args: {
    payoutId: v.id("payouts"),
    attempt: v.number(),
    mappedStatus: v.union(
      v.literal("queued"),
      v.literal("processing"),
      v.literal("pending_provider"),
      v.literal("paid"),
      v.literal("failed"),
      v.literal("cancelled"),
      v.literal("needs_attention"),
    ),
    retryable: v.boolean(),
    providerPayoutId: v.optional(v.string()),
    providerStatusRaw: v.optional(v.string()),
    httpStatus: v.optional(v.number()),
    errorCode: v.optional(v.string()),
    message: v.optional(v.string()),
    payload: v.optional(v.any()),
  },
  handler: async (ctx, args) => {
    const payout = await ctx.db.get(args.payoutId);
    if (!payout) return { applied: false, reason: "missing" as const };
    if (payout.attemptCount !== args.attempt) {
      return { applied: false, reason: "stale_attempt" as const };
    }
    if (TERMINAL_PAYOUT_STATUSES.has(payout.status)) {
      return { applied: false, reason: "already_terminal" as const };
    }

    const now = Date.now();
    let nextStatus: PayoutStatus = args.mappedStatus;
    let nextRetryAt: number | undefined;
    let terminalAt: number | undefined;
    let shouldScheduleRetry = false;

    if (args.retryable) {
      if (args.attempt >= payout.maxAttempts) {
        nextStatus = "needs_attention";
        terminalAt = now;
      } else {
        nextStatus = "queued";
        nextRetryAt = now + computeRetryDelayMs(args.attempt);
        shouldScheduleRetry = true;
      }
    } else if (TERMINAL_PAYOUT_STATUSES.has(nextStatus)) {
      terminalAt = now;
    } else if (nextStatus === "processing") {
      nextStatus = "queued";
      nextRetryAt = now + computeRetryDelayMs(args.attempt);
      shouldScheduleRetry = true;
    }

    await ctx.db.patch(args.payoutId, {
      status: nextStatus,
      providerPayoutId: args.providerPayoutId ?? payout.providerPayoutId,
      providerStatusRaw: args.providerStatusRaw ?? payout.providerStatusRaw,
      lastError: args.message,
      nextRetryAt,
      terminalAt: terminalAt ?? payout.terminalAt,
      destinationId: payout.destinationId,
      updatedAt: now,
    });

    await ctx.db.insert("payoutEvents", {
      payoutId: args.payoutId,
      paymentId: payout.paymentId,
      provider: payout.provider,
      eventType: "provider_response",
      attempt: args.attempt,
      providerPayoutId: args.providerPayoutId,
      statusRaw: args.providerStatusRaw,
      mappedStatus: nextStatus,
      retryable: args.retryable,
      httpStatus: args.httpStatus,
      errorCode: args.errorCode,
      message: args.message,
      payload: args.payload,
      createdAt: now,
    });

    if (shouldScheduleRetry && nextRetryAt) {
      await ctx.db.insert("payoutEvents", {
        payoutId: args.payoutId,
        paymentId: payout.paymentId,
        provider: payout.provider,
        eventType: "retry_scheduled",
        attempt: args.attempt,
        mappedStatus: nextStatus,
        retryable: true,
        message: `Retry scheduled in ${nextRetryAt - now}ms`,
        createdAt: now,
      });
      await ctx.scheduler.runAfter(
        nextRetryAt - now,
        internal.payouts.runPayoutAttempt,
        { payoutId: args.payoutId },
      );
    }

    if (nextStatus === "failed" || nextStatus === "cancelled" || nextStatus === "needs_attention") {
      await ctx.db.insert("payoutEvents", {
        payoutId: args.payoutId,
        paymentId: payout.paymentId,
        provider: payout.provider,
        eventType: "terminal_failure",
        attempt: args.attempt,
        mappedStatus: nextStatus,
        message: args.message ?? "Payout moved to terminal state",
        createdAt: now,
      });
    }

    return {
      applied: true,
      status: nextStatus,
      retryScheduled: shouldScheduleRetry,
      nextRetryAt,
    };
  },
});
