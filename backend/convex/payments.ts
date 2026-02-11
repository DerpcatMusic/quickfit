import {
  internalMutation,
  internalQuery,
  mutation,
  query,
} from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
const RAPYD_PROVIDER = "rapyd" as const;
type AppRole = "studio" | "instructor";
export type PaymentStatus =
  | "created"
  | "pending"
  | "authorized"
  | "captured"
  | "failed"
  | "cancelled"
  | "refunded";
type MappedPaymentStatus = Exclude<PaymentStatus, "created">;
type InvoiceStatus = "pending" | "issued" | "failed" | "voided";

type TimelineEventInput = {
  _id: Id<"paymentEvents">;
  provider: "rapyd" | "bitpay";
  createdAt: number;
  eventType?: string;
  statusRaw?: string;
  signatureValid: boolean;
  processed: boolean;
};

type InvoiceInput = {
  _id: Id<"invoices">;
  status: InvoiceStatus;
  externalInvoiceId?: string;
  issuedAt?: number;
};

export const derivePayoutStatus = (
  paymentStatus: PaymentStatus,
): PaymentStatus =>
  paymentStatus === "captured" ? "pending" : paymentStatus;

export const computeNextWebhookPaymentStatus = (
  currentStatus: PaymentStatus,
  mappedStatus: MappedPaymentStatus,
): MappedPaymentStatus => {
  // Terminal states should never be reopened by out-of-order webhooks.
  if (currentStatus === "refunded") {
    return "refunded";
  }
  if (currentStatus === "failed") {
    return "failed";
  }
  if (currentStatus === "cancelled") {
    return "cancelled";
  }

  // Captured is sticky unless we receive an explicit refund signal.
  if (currentStatus === "captured" && mappedStatus !== "refunded") {
    return "captured";
  }

  // Prevent regressions on the non-terminal progression path.
  if (currentStatus === "authorized" && mappedStatus === "pending") {
    return "authorized";
  }

  return mappedStatus;
};

export const shouldScheduleInvoiceForTransition = (
  previousStatus: PaymentStatus,
  nextStatus: MappedPaymentStatus,
): boolean => previousStatus !== "captured" && nextStatus === "captured";

export const toPaymentTimeline = (events: TimelineEventInput[]) =>
  events.map((event) => ({
    _id: event._id,
    provider: event.provider,
    createdAt: event.createdAt,
    title: event.eventType ?? "provider_event",
    description: event.statusRaw ?? "status_update",
    signatureValid: event.signatureValid,
    processed: event.processed,
  }));

export const toInvoiceSummary = (invoice: InvoiceInput | null) =>
  invoice
    ? {
        _id: invoice._id,
        status: invoice.status,
        externalInvoiceId: invoice.externalInvoiceId,
        externalInvoiceUrl: invoice.externalInvoiceId,
        issuedAt: invoice.issuedAt,
      }
    : null;

const requireAuthedUser = async (ctx: any) => {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) throw new Error("Not authenticated");
  const user = await ctx.db
    .query("users")
    .withIndex("by_firebaseUid", (q: any) =>
      q.eq("firebaseUid", identity.subject),
    )
    .unique();
  if (!user) throw new Error("User not found");
  return user as { _id: Id<"users">; role: AppRole };
};

const resolveNextPaymentState = (
  payment: {
    status: PaymentStatus;
    capturedAt?: number;
  },
  mappedStatus: MappedPaymentStatus,
) => {
  const nextStatus = computeNextWebhookPaymentStatus(payment.status, mappedStatus);
  const transitionedToCaptured = shouldScheduleInvoiceForTransition(
    payment.status,
    nextStatus,
  );
  const transitionedToRefunded =
    payment.status !== "refunded" && nextStatus === "refunded";
  return { nextStatus, transitionedToCaptured, transitionedToRefunded };
};

export const toRapydPaymentStatus = (
  rawStatus: string | undefined,
):
  | "pending"
  | "authorized"
  | "captured"
  | "failed"
  | "cancelled"
  | "refunded" => {
  const status = (rawStatus ?? "").toUpperCase();
  if (["CLO", "CAPTURED", "SUCCESS", "COMPLETED"].includes(status)) {
    return "captured";
  }
  if (["AUTH", "AUTHORIZED"].includes(status)) {
    return "authorized";
  }
  if (["ACT", "NEW", "PENDING", "INIT", "OPEN"].includes(status)) {
    return "pending";
  }
  if (["CAN", "CANCELLED", "CANCELED"].includes(status)) {
    return "cancelled";
  }
  if (["REV", "REFUNDED", "PARTIAL_REFUND"].includes(status)) {
    return "refunded";
  }
  return "failed";
};

export const getCheckoutContext = internalQuery({
  args: {
    firebaseUid: v.string(),
    jobId: v.id("jobs"),
  },
  handler: async (ctx, { firebaseUid, jobId }) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", firebaseUid))
      .unique();
    if (!user) return null;

    const job = await ctx.db.get(jobId);
    if (!job) return null;

    return { user, job };
  },
});

export const getPaymentByProviderRefs = internalQuery({
  args: {
    provider: v.union(v.literal("rapyd"), v.literal("bitpay")),
    providerPaymentId: v.optional(v.string()),
    providerCheckoutId: v.optional(v.string()),
    paymentId: v.optional(v.id("payments")),
  },
  handler: async (ctx, args) => {
    if (args.paymentId) {
      const direct = await ctx.db.get(args.paymentId);
      if (direct && direct.provider === args.provider) return direct;
    }
    if (args.providerPaymentId) {
      const byPaymentId = await ctx.db
        .query("payments")
        .withIndex("by_provider_paymentId", (q) =>
          q
            .eq("provider", args.provider)
            .eq("providerPaymentId", args.providerPaymentId),
        )
        .unique();
      if (byPaymentId) return byPaymentId;
    }
    if (args.providerCheckoutId) {
      return await ctx.db
        .query("payments")
        .withIndex("by_provider_checkoutId", (q) =>
          q
            .eq("provider", args.provider)
            .eq("providerCheckoutId", args.providerCheckoutId),
        )
        .unique();
    }
    return null;
  },
});

export const createPendingPayment = internalMutation({
  args: {
    jobId: v.id("jobs"),
    studioId: v.id("users"),
    instructorId: v.optional(v.id("users")),
    provider: v.union(v.literal("rapyd"), v.literal("bitpay")),
    currency: v.string(),
    grossAmountAgorot: v.number(),
    feeAmountAgorot: v.number(),
    netAmountAgorot: v.number(),
    feeBps: v.number(),
    idempotencyKey: v.string(),
    metadata: v.optional(v.any()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const existing = await ctx.db
      .query("payments")
      .withIndex("by_studio_idempotency", (q) =>
        q
          .eq("studioId", args.studioId)
          .eq("idempotencyKey", args.idempotencyKey),
      )
      .unique();

    if (existing) {
      if (
        existing.jobId !== args.jobId ||
        existing.provider !== args.provider
      ) {
        throw new Error(
          "Idempotency key already used for a different job/provider",
        );
      }
      return existing;
    }

    const paymentId = await ctx.db.insert("payments", {
      jobId: args.jobId,
      studioId: args.studioId,
      instructorId: args.instructorId,
      provider: args.provider,
      status: "created",
      currency: args.currency,
      grossAmountAgorot: args.grossAmountAgorot,
      feeAmountAgorot: args.feeAmountAgorot,
      netAmountAgorot: args.netAmountAgorot,
      feeBps: args.feeBps,
      idempotencyKey: args.idempotencyKey,
      metadata: args.metadata,
      createdAt: now,
      updatedAt: now,
    });

    await ctx.runMutation(internal.events.emitDomainEvent, {
      aggregateType: "payment",
      aggregateId: paymentId,
      eventType: "payment.created",
      source: "mutation",
      actorUserId: args.studioId,
      idempotencyKey: args.idempotencyKey,
      payload: {
        jobId: args.jobId,
        studioId: args.studioId,
        instructorId: args.instructorId,
        provider: args.provider,
        currency: args.currency,
        grossAmountAgorot: args.grossAmountAgorot,
        feeAmountAgorot: args.feeAmountAgorot,
        netAmountAgorot: args.netAmountAgorot,
        feeBps: args.feeBps,
      },
      occurredAt: now,
    });

    return await ctx.db.get(paymentId);
  },
});

export const markCheckoutCreated = internalMutation({
  args: {
    paymentId: v.id("payments"),
    providerCheckoutId: v.optional(v.string()),
    providerPaymentId: v.optional(v.string()),
    metadata: v.optional(v.any()),
  },
  handler: async (ctx, args) => {
    const payment = await ctx.db.get(args.paymentId);
    if (!payment) throw new Error("Payment not found");
    const now = Date.now();

    await ctx.db.patch(args.paymentId, {
      providerCheckoutId: args.providerCheckoutId ?? payment.providerCheckoutId,
      providerPaymentId: args.providerPaymentId ?? payment.providerPaymentId,
      metadata: {
        ...(payment.metadata ?? {}),
        ...(args.metadata ?? {}),
      },
      status: payment.status === "created" ? "pending" : payment.status,
      updatedAt: now,
    });

    await ctx.runMutation(internal.events.emitDomainEvent, {
      aggregateType: "payment",
      aggregateId: args.paymentId,
      eventType: "payment.checkout_created",
      source: "mutation",
      payload: {
        provider: payment.provider,
        providerCheckoutId: args.providerCheckoutId ?? payment.providerCheckoutId,
        providerPaymentId: args.providerPaymentId ?? payment.providerPaymentId,
        status: payment.status === "created" ? "pending" : payment.status,
      },
      occurredAt: now,
    });

    await ctx.runMutation(internal.payments.reprocessUnmatchedEventsForPayment, {
      paymentId: args.paymentId,
      provider: payment.provider,
      providerPaymentId: args.providerPaymentId ?? payment.providerPaymentId,
      providerCheckoutId: args.providerCheckoutId ?? payment.providerCheckoutId,
    });
  },
});

export const reprocessUnmatchedEventsForPayment = internalMutation({
  args: {
    paymentId: v.id("payments"),
    provider: v.union(v.literal("rapyd"), v.literal("bitpay")),
    providerPaymentId: v.optional(v.string()),
    providerCheckoutId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const payment = await ctx.db.get(args.paymentId);
    if (!payment) return { processed: 0 };
    const now = Date.now();
    const toProcess = new Map<string, any>();

    if (args.providerPaymentId) {
      let cursor: string | null = null;
      let isDone = false;
      while (!isDone) {
        const byPaymentId = await ctx.db
          .query("paymentEvents")
          .withIndex("by_provider_payment_processed", (q) =>
            q
              .eq("provider", args.provider)
              .eq("providerPaymentId", args.providerPaymentId)
              .eq("processed", false),
          )
          .order("asc")
          .paginate({ numItems: 64, cursor });
        for (const row of byPaymentId.page) {
          toProcess.set(row._id, row);
        }
        cursor = byPaymentId.continueCursor;
        isDone = byPaymentId.isDone;
      }
    }

    if (args.providerCheckoutId) {
      let cursor: string | null = null;
      let isDone = false;
      while (!isDone) {
        const byCheckoutId = await ctx.db
          .query("paymentEvents")
          .withIndex("by_provider_checkout_processed", (q) =>
            q
              .eq("provider", args.provider)
              .eq("providerCheckoutId", args.providerCheckoutId)
              .eq("processed", false),
          )
          .order("asc")
          .paginate({ numItems: 64, cursor });
        for (const row of byCheckoutId.page) {
          toProcess.set(row._id, row);
        }
        cursor = byCheckoutId.continueCursor;
        isDone = byCheckoutId.isDone;
      }
    }

    let current = payment;
    let processed = 0;
    const sorted = Array.from(toProcess.values()).sort(
      (a, b) => a.createdAt - b.createdAt,
    );

    for (const event of sorted) {
      if (!event.signatureValid) continue;
      const mappedStatus =
        args.provider === RAPYD_PROVIDER
          ? toRapydPaymentStatus(event.statusRaw)
          : toBitpayPaymentStatus(event.statusRaw);
      const { nextStatus, transitionedToCaptured, transitionedToRefunded } =
        resolveNextPaymentState(
        current,
        mappedStatus,
      );

      await ctx.db.patch(args.paymentId, {
        status: nextStatus,
        providerPaymentId: event.providerPaymentId ?? current.providerPaymentId,
        providerCheckoutId: event.providerCheckoutId ?? current.providerCheckoutId,
        capturedAt:
          nextStatus === "captured" ? (current.capturedAt ?? now) : current.capturedAt,
        updatedAt: now,
      });
      if (current.status !== nextStatus) {
        await ctx.runMutation(internal.events.emitDomainEvent, {
          aggregateType: "payment",
          aggregateId: args.paymentId,
          eventType: "payment.status_changed",
          source: "webhook_reprocess",
          idempotencyKey: `payment-event:${event._id}`,
          payload: {
            fromStatus: current.status,
            toStatus: nextStatus,
            provider: args.provider,
            providerEventId: event.providerEventId,
            providerPaymentId:
              event.providerPaymentId ?? current.providerPaymentId,
            providerCheckoutId:
              event.providerCheckoutId ?? current.providerCheckoutId,
            statusRaw: event.statusRaw,
          },
          occurredAt: now,
        });
      }
      await ctx.db.patch(event._id, {
        paymentId: args.paymentId,
        processed: true,
        updatedAt: now,
      });
      processed += 1;

      if (transitionedToCaptured) {
        await ctx.scheduler.runAfter(0, internal.invoicing.issueInvoiceForPayment, {
          paymentId: args.paymentId,
        });
        await ctx.scheduler.runAfter(
          0,
          internal.payouts.schedulePayoutForCapturedPayment,
          {
            paymentId: args.paymentId,
            reason: "captured_via_reprocessed_webhook",
          },
        );
      }
      if (transitionedToRefunded) {
        await ctx.scheduler.runAfter(
          0,
          internal.payouts.flagPayoutNeedsAttentionForRefund,
          {
            paymentId: args.paymentId,
            reason: "payment_refunded_via_reprocessed_webhook",
          },
        );
      }

      current = {
        ...current,
        status: nextStatus,
        providerPaymentId: event.providerPaymentId ?? current.providerPaymentId,
        providerCheckoutId: event.providerCheckoutId ?? current.providerCheckoutId,
        capturedAt:
          nextStatus === "captured" ? (current.capturedAt ?? now) : current.capturedAt,
      };
    }

    return { processed };
  },
});

export const processRapydWebhookEvent = internalMutation({
  args: {
    providerEventId: v.string(),
    eventType: v.optional(v.string()),
    providerPaymentId: v.optional(v.string()),
    providerCheckoutId: v.optional(v.string()),
    statusRaw: v.optional(v.string()),
    signatureValid: v.boolean(),
    payloadHash: v.string(),
    payload: v.any(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    const existingEvent = await ctx.db
      .query("paymentEvents")
      .withIndex("by_provider_eventId", (q) =>
        q
          .eq("provider", RAPYD_PROVIDER)
          .eq("providerEventId", args.providerEventId),
      )
      .unique();

    if (existingEvent) {
      return { ignored: true, reason: "duplicate_event" as const };
    }

    if (!args.signatureValid) {
      const eventId = await ctx.db.insert("paymentEvents", {
        provider: RAPYD_PROVIDER,
        providerEventId: args.providerEventId,
        eventType: args.eventType,
        paymentId: undefined,
        providerPaymentId: args.providerPaymentId,
        providerCheckoutId: args.providerCheckoutId,
        statusRaw: args.statusRaw,
        signatureValid: false,
        processed: false,
        payloadHash: args.payloadHash,
        payload: args.payload,
        processingError: "invalid_signature",
        createdAt: now,
        updatedAt: now,
      });
      return { ignored: true, reason: "invalid_signature" as const, eventId };
    }
    const existingPayload = await ctx.db
      .query("paymentEvents")
      .withIndex("by_provider_payloadHash_signatureValid", (q) =>
        q
          .eq("provider", RAPYD_PROVIDER)
          .eq("payloadHash", args.payloadHash)
          .eq("signatureValid", true),
      )
      .first();
    if (existingPayload) {
      return { ignored: true, reason: "duplicate_payload" as const };
    }

    let payment: {
      _id: Id<"payments">;
      status:
        | "created"
        | "pending"
        | "authorized"
        | "captured"
        | "failed"
        | "cancelled"
        | "refunded";
      capturedAt?: number;
    } | null = null;

    if (args.providerPaymentId) {
      payment = await ctx.db
        .query("payments")
        .withIndex("by_provider_paymentId", (q) =>
          q
            .eq("provider", RAPYD_PROVIDER)
            .eq("providerPaymentId", args.providerPaymentId),
        )
        .unique();
    }

    if (!payment && args.providerCheckoutId) {
      payment = await ctx.db
        .query("payments")
        .withIndex("by_provider_checkoutId", (q) =>
          q
            .eq("provider", RAPYD_PROVIDER)
            .eq("providerCheckoutId", args.providerCheckoutId),
        )
        .unique();
    }

    const mappedStatus = toRapydPaymentStatus(args.statusRaw);

    const eventId = await ctx.db.insert("paymentEvents", {
      provider: RAPYD_PROVIDER,
      providerEventId: args.providerEventId,
      eventType: args.eventType,
      paymentId: payment?._id,
      providerPaymentId: args.providerPaymentId,
      providerCheckoutId: args.providerCheckoutId,
      statusRaw: args.statusRaw,
      signatureValid: args.signatureValid,
      processed: payment ? true : false,
      payloadHash: args.payloadHash,
      payload: args.payload,
      createdAt: now,
      updatedAt: now,
    });

    if (!payment) {
      return {
        ignored: false,
        processed: false,
        reason: "payment_not_found" as const,
        eventId,
      };
    }

    const { nextStatus, transitionedToCaptured, transitionedToRefunded } =
      resolveNextPaymentState(
      payment,
      mappedStatus,
    );
    await ctx.db.patch(payment._id, {
      status: nextStatus,
      providerPaymentId: args.providerPaymentId,
      providerCheckoutId: args.providerCheckoutId,
      capturedAt: nextStatus === "captured" ? Date.now() : payment.capturedAt,
      updatedAt: now,
    });

    if (transitionedToCaptured) {
      await ctx.scheduler.runAfter(
        0,
        internal.invoicing.issueInvoiceForPayment,
        {
          paymentId: payment._id,
        },
      );
      await ctx.scheduler.runAfter(
        0,
        internal.payouts.schedulePayoutForCapturedPayment,
        {
          paymentId: payment._id,
          reason: "captured_via_rapyd_webhook",
        },
      );
    }
    if (transitionedToRefunded) {
      await ctx.scheduler.runAfter(
        0,
        internal.payouts.flagPayoutNeedsAttentionForRefund,
        {
          paymentId: payment._id,
          reason: "payment_refunded_via_rapyd_webhook",
        },
      );
    }

    return { ignored: false, processed: true, eventId, paymentId: payment._id };
  },
});

export const toBitpayPaymentStatus = (
  rawStatus: string | undefined,
):
  | "pending"
  | "authorized"
  | "captured"
  | "failed"
  | "cancelled"
  | "refunded" => {
  const status = (rawStatus ?? "").toLowerCase();
  if (["paid", "confirmed", "complete", "completed"].includes(status)) {
    return "captured";
  }
  if (["new", "processing"].includes(status)) {
    return "pending";
  }
  if (["expired", "invalid"].includes(status)) {
    return "failed";
  }
  if (["cancelled", "canceled"].includes(status)) {
    return "cancelled";
  }
  if (["refunded", "refund"].includes(status)) {
    return "refunded";
  }
  return "failed";
};

export const processBitpayWebhookEvent = internalMutation({
  args: {
    providerEventId: v.string(),
    eventType: v.optional(v.string()),
    providerPaymentId: v.optional(v.string()),
    providerCheckoutId: v.optional(v.string()),
    statusRaw: v.optional(v.string()),
    signatureValid: v.boolean(),
    payloadHash: v.string(),
    payload: v.any(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const existingEvent = await ctx.db
      .query("paymentEvents")
      .withIndex("by_provider_eventId", (q) =>
        q.eq("provider", "bitpay").eq("providerEventId", args.providerEventId),
      )
      .unique();
    if (existingEvent) {
      return { ignored: true, reason: "duplicate_event" as const };
    }

    if (!args.signatureValid) {
      const eventId = await ctx.db.insert("paymentEvents", {
        provider: "bitpay",
        providerEventId: args.providerEventId,
        eventType: args.eventType,
        paymentId: undefined,
        providerPaymentId: args.providerPaymentId,
        providerCheckoutId: args.providerCheckoutId,
        statusRaw: args.statusRaw,
        signatureValid: false,
        processed: false,
        payloadHash: args.payloadHash,
        payload: args.payload,
        processingError: "invalid_signature",
        createdAt: now,
        updatedAt: now,
      });
      return { ignored: true, reason: "invalid_signature" as const, eventId };
    }
    const existingPayload = await ctx.db
      .query("paymentEvents")
      .withIndex("by_provider_payloadHash_signatureValid", (q) =>
        q
          .eq("provider", "bitpay")
          .eq("payloadHash", args.payloadHash)
          .eq("signatureValid", true),
      )
      .first();
    if (existingPayload) {
      return { ignored: true, reason: "duplicate_payload" as const };
    }

    let payment: {
      _id: Id<"payments">;
      status:
        | "created"
        | "pending"
        | "authorized"
        | "captured"
        | "failed"
        | "cancelled"
        | "refunded";
      capturedAt?: number;
    } | null = null;

    if (args.providerPaymentId) {
      payment = await ctx.db
        .query("payments")
        .withIndex("by_provider_paymentId", (q) =>
          q
            .eq("provider", "bitpay")
            .eq("providerPaymentId", args.providerPaymentId),
        )
        .unique();
    }
    if (!payment && args.providerCheckoutId) {
      payment = await ctx.db
        .query("payments")
        .withIndex("by_provider_checkoutId", (q) =>
          q
            .eq("provider", "bitpay")
            .eq("providerCheckoutId", args.providerCheckoutId),
        )
        .unique();
    }

    const mappedStatus = toBitpayPaymentStatus(args.statusRaw);
    const eventId = await ctx.db.insert("paymentEvents", {
      provider: "bitpay",
      providerEventId: args.providerEventId,
      eventType: args.eventType,
      paymentId: payment?._id,
      providerPaymentId: args.providerPaymentId,
      providerCheckoutId: args.providerCheckoutId,
      statusRaw: args.statusRaw,
      signatureValid: true,
      processed: payment ? true : false,
      payloadHash: args.payloadHash,
      payload: args.payload,
      createdAt: now,
      updatedAt: now,
    });

    if (!payment) {
      return {
        ignored: false,
        processed: false,
        reason: "payment_not_found" as const,
        eventId,
      };
    }

    const { nextStatus, transitionedToCaptured, transitionedToRefunded } =
      resolveNextPaymentState(
      payment,
      mappedStatus,
    );
    await ctx.db.patch(payment._id, {
      status: nextStatus,
      providerPaymentId: args.providerPaymentId,
      providerCheckoutId: args.providerCheckoutId,
      capturedAt: nextStatus === "captured" ? Date.now() : payment.capturedAt,
      updatedAt: now,
    });

    if (transitionedToCaptured) {
      await ctx.scheduler.runAfter(
        0,
        internal.invoicing.issueInvoiceForPayment,
        {
          paymentId: payment._id,
        },
      );
      await ctx.scheduler.runAfter(
        0,
        internal.payouts.schedulePayoutForCapturedPayment,
        {
          paymentId: payment._id,
          reason: "captured_via_bitpay_webhook",
        },
      );
    }
    if (transitionedToRefunded) {
      await ctx.scheduler.runAfter(
        0,
        internal.payouts.flagPayoutNeedsAttentionForRefund,
        {
          paymentId: payment._id,
          reason: "payment_refunded_via_bitpay_webhook",
        },
      );
    }
    return { ignored: false, processed: true, eventId, paymentId: payment._id };
  },
});

export const getPaymentForInvoicing = internalQuery({
  args: { paymentId: v.id("payments") },
  handler: async (ctx, { paymentId }) => {
    const payment = await ctx.db.get(paymentId);
    if (!payment) return null;

    const studio = await ctx.db.get(payment.studioId);
    const job = await ctx.db.get(payment.jobId);
    const instructor = payment.instructorId
      ? await ctx.db.get(payment.instructorId)
      : null;

    return { payment, studio, job, instructor };
  },
});

export const createInvoiceRecord = internalMutation({
  args: {
    paymentId: v.id("payments"),
    provider: v.union(v.literal("morning"), v.literal("icount")),
    currency: v.string(),
    amountAgorot: v.number(),
    vatRate: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const payment = await ctx.db.get(args.paymentId);
    if (!payment) throw new Error("Payment not found");

    const metadata = (payment.metadata ?? {}) as {
      invoiceRecordId?: Id<"invoices">;
    };
    if (metadata.invoiceRecordId) {
      const existingByMetadata = await ctx.db.get(metadata.invoiceRecordId);
      if (existingByMetadata) return existingByMetadata;
    }

    const existing = await ctx.db
      .query("invoices")
      .withIndex("by_payment", (q) => q.eq("paymentId", args.paymentId))
      .first();
    if (existing) {
      await ctx.db.patch(args.paymentId, {
        metadata: {
          ...(payment.metadata ?? {}),
          invoiceRecordId: existing._id,
        },
        updatedAt: now,
      });
      return existing;
    }

    const invoiceId = await ctx.db.insert("invoices", {
      paymentId: args.paymentId,
      provider: args.provider,
      status: "pending",
      currency: args.currency,
      amountAgorot: args.amountAgorot,
      vatRate: args.vatRate,
      createdAt: now,
      updatedAt: now,
    });
    await ctx.db.patch(args.paymentId, {
      metadata: {
        ...(payment.metadata ?? {}),
        invoiceRecordId: invoiceId,
      },
      updatedAt: now,
    });
    return await ctx.db.get(invoiceId);
  },
});

export const markInvoiceIssued = internalMutation({
  args: {
    invoiceId: v.id("invoices"),
    externalInvoiceId: v.string(),
  },
  handler: async (ctx, { invoiceId, externalInvoiceId }) => {
    await ctx.db.patch(invoiceId, {
      status: "issued",
      externalInvoiceId,
      issuedAt: Date.now(),
      updatedAt: Date.now(),
    });
  },
});

export const markInvoiceFailed = internalMutation({
  args: {
    invoiceId: v.id("invoices"),
    error: v.string(),
  },
  handler: async (ctx, { invoiceId, error }) => {
    await ctx.db.patch(invoiceId, {
      status: "failed",
      error,
      updatedAt: Date.now(),
    });
  },
});

export const listMyPayments = query({
  args: { limit: v.optional(v.number()) },
  handler: async (ctx, { limit }) => {
    const user = await requireAuthedUser(ctx);

    const capped = Math.min(Math.max(limit ?? 50, 1), 200);
    const rows =
      user.role === "studio"
        ? await ctx.db
            .query("payments")
            .withIndex("by_studio", (q) => q.eq("studioId", user._id))
            .order("desc")
            .take(capped)
        : await ctx.db
            .query("payments")
            .withIndex("by_instructor", (q) => q.eq("instructorId", user._id))
            .order("desc")
            .take(capped);

    const enriched = await Promise.all(
      rows.map(async (payment) => {
        const [job, invoice, payout] = await Promise.all([
          ctx.db.get(payment.jobId),
          ctx.db
            .query("invoices")
            .withIndex("by_payment", (q) => q.eq("paymentId", payment._id))
            .order("desc")
            .first(),
          ctx.db
            .query("payouts")
            .withIndex("by_payment", (q) => q.eq("paymentId", payment._id))
            .order("desc")
            .first(),
        ]);

        return {
          ...payment,
          job: job
            ? {
                _id: job._id,
                title: job.title,
                startTime: job.startTime,
                category: job.category,
              }
            : null,
          payout: {
            status: payout?.status ?? derivePayoutStatus(payment.status),
            settledAt: payout?.terminalAt,
          },
          invoice: toInvoiceSummary(invoice),
        };
      }),
    );

    return enriched;
  },
});

export const getMyPaymentForJob = query({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const user = await requireAuthedUser(ctx);
    const payment = await ctx.db
      .query("payments")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .order("desc")
      .first();
    if (!payment) return null;
    if (payment.studioId !== user._id && payment.instructorId !== user._id) {
      throw new Error("Unauthorized");
    }
    const [job, invoice, payout] = await Promise.all([
      ctx.db.get(payment.jobId),
      ctx.db
        .query("invoices")
        .withIndex("by_payment", (q) => q.eq("paymentId", payment._id))
        .order("desc")
        .first(),
      ctx.db
        .query("payouts")
        .withIndex("by_payment", (q) => q.eq("paymentId", payment._id))
        .order("desc")
        .first(),
    ]);
    return {
      ...payment,
      job,
      payout: {
        status: payout?.status ?? derivePayoutStatus(payment.status),
        settledAt: payout?.terminalAt,
      },
      invoice: toInvoiceSummary(invoice),
    };
  },
});

export const getMyPaymentDetail = query({
  args: { paymentId: v.id("payments") },
  handler: async (ctx, { paymentId }) => {
    const user = await requireAuthedUser(ctx);
    const payment = await ctx.db.get(paymentId);
    if (!payment) return null;
    if (payment.studioId !== user._id && payment.instructorId !== user._id) {
      throw new Error("Unauthorized");
    }

    const [job, invoice, events, payout] = await Promise.all([
      ctx.db.get(payment.jobId),
      ctx.db
        .query("invoices")
        .withIndex("by_payment", (q) => q.eq("paymentId", payment._id))
        .order("desc")
        .first(),
      ctx.db
        .query("paymentEvents")
        .withIndex("by_payment", (q) => q.eq("paymentId", payment._id))
        .order("desc")
        .take(50),
      ctx.db
        .query("payouts")
        .withIndex("by_payment", (q) => q.eq("paymentId", payment._id))
        .order("desc")
        .first(),
    ]);

    const timeline = toPaymentTimeline(events);

    return {
      payment,
      job,
      payout: {
        status: payout?.status ?? derivePayoutStatus(payment.status),
        settledAt: payout?.terminalAt,
      },
      invoice: toInvoiceSummary(invoice),
      timeline,
    };
  },
});

export const listMyPayoutDestinations = query({
  args: {},
  handler: async (ctx) => {
    const user = await requireAuthedUser(ctx);
    return await ctx.db
      .query("payoutDestinations")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .order("desc")
      .collect();
  },
});

export const upsertMyPayoutDestination = mutation({
  args: {
    provider: v.union(v.literal("rapyd"), v.literal("bitpay")),
    type: v.string(),
    externalRecipientId: v.string(),
    label: v.optional(v.string()),
    country: v.optional(v.string()),
    currency: v.optional(v.string()),
    last4: v.optional(v.string()),
    isDefault: v.optional(v.boolean()),
    status: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const user = await requireAuthedUser(ctx);
    const now = Date.now();
    const externalRecipientId = args.externalRecipientId.trim();
    if (!externalRecipientId) {
      throw new Error("externalRecipientId is required");
    }

    const existing = await ctx.db
      .query("payoutDestinations")
      .withIndex("by_user_provider_external", (q) =>
        q
          .eq("userId", user._id)
          .eq("provider", args.provider)
          .eq("externalRecipientId", externalRecipientId),
      )
      .unique();

    if ((args.isDefault ?? true) === true) {
      const active = await ctx.db
        .query("payoutDestinations")
        .withIndex("by_user_default", (q) =>
          q.eq("userId", user._id).eq("isDefault", true),
        )
        .collect();
      for (const row of active) {
        if (!existing || row._id !== existing._id) {
          await ctx.db.patch(row._id, { isDefault: false, updatedAt: now });
        }
      }
    }

    if (existing) {
      await ctx.db.patch(existing._id, {
        type: args.type,
        label: args.label ?? existing.label,
        country: args.country ?? existing.country,
        currency: args.currency ?? existing.currency,
        last4: args.last4 ?? existing.last4,
        isDefault: args.isDefault ?? existing.isDefault,
        status: args.status ?? existing.status,
        updatedAt: now,
      });
      return await ctx.db.get(existing._id);
    }

    const id = await ctx.db.insert("payoutDestinations", {
      userId: user._id,
      provider: args.provider,
      type: args.type,
      externalRecipientId,
      label: args.label,
      country: args.country,
      currency: args.currency,
      last4: args.last4,
      isDefault: args.isDefault ?? true,
      status: args.status ?? "verified",
      createdAt: now,
      updatedAt: now,
    });
    return await ctx.db.get(id);
  },
});

export const markPaymentError = internalMutation({
  args: {
    paymentId: v.id("payments"),
    error: v.string(),
  },
  handler: async (ctx, { paymentId, error }) => {
    await ctx.db.patch(paymentId, {
      status: "failed",
      lastError: error,
      updatedAt: Date.now(),
    });
  },
});
