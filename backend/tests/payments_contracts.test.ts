import { describe, expect, it } from "bun:test";
import {
  computeNextWebhookPaymentStatus,
  derivePayoutStatus,
  shouldScheduleInvoiceForTransition,
  toBitpayPaymentStatus,
  toInvoiceSummary,
  toPaymentTimeline,
  toRapydPaymentStatus,
  type PaymentStatus,
} from "../convex/payments";

const fakePaymentEventId = "jh7abc_payment_event" as any;
const fakeInvoiceId = "jh7abc_invoice" as any;

describe("payments payout pipeline semantics", () => {
  it("maps Rapyd statuses to internal status contract", () => {
    expect(toRapydPaymentStatus("CLO")).toBe("captured");
    expect(toRapydPaymentStatus("AUTHORIZED")).toBe("authorized");
    expect(toRapydPaymentStatus("OPEN")).toBe("pending");
    expect(toRapydPaymentStatus("canceled")).toBe("cancelled");
    expect(toRapydPaymentStatus("partial_refund")).toBe("refunded");
    expect(toRapydPaymentStatus("unknown_status")).toBe("failed");
  });

  it("maps BitPay statuses to internal status contract", () => {
    expect(toBitpayPaymentStatus("paid")).toBe("captured");
    expect(toBitpayPaymentStatus("processing")).toBe("pending");
    expect(toBitpayPaymentStatus("expired")).toBe("failed");
    expect(toBitpayPaymentStatus("canceled")).toBe("cancelled");
    expect(toBitpayPaymentStatus("refund")).toBe("refunded");
    expect(toBitpayPaymentStatus("nope")).toBe("failed");
  });

  it("keeps captured sticky except refund and schedules only captured transitions", () => {
    expect(computeNextWebhookPaymentStatus("captured", "failed")).toBe(
      "captured",
    );
    expect(computeNextWebhookPaymentStatus("captured", "refunded")).toBe(
      "refunded",
    );
    expect(computeNextWebhookPaymentStatus("pending", "captured")).toBe(
      "captured",
    );

    expect(shouldScheduleInvoiceForTransition("pending", "captured")).toBe(
      true,
    );
    expect(shouldScheduleInvoiceForTransition("captured", "captured")).toBe(
      false,
    );
    expect(shouldScheduleInvoiceForTransition("captured", "refunded")).toBe(
      false,
    );
  });

  it("projects payout status contract for payment detail/list responses", () => {
    const passthroughStatuses: PaymentStatus[] = [
      "created",
      "pending",
      "authorized",
      "failed",
      "cancelled",
      "refunded",
    ];

    for (const status of passthroughStatuses) {
      expect(derivePayoutStatus(status)).toBe(status);
    }
    expect(derivePayoutStatus("captured")).toBe("pending");
  });

  it("shapes payment detail timeline and invoice fields deterministically", () => {
    const timeline = toPaymentTimeline([
      {
        _id: fakePaymentEventId,
        provider: "rapyd",
        createdAt: 1700000000000,
        eventType: undefined,
        statusRaw: undefined,
        signatureValid: true,
        processed: true,
      },
    ]);

    expect(timeline).toEqual([
      {
        _id: fakePaymentEventId,
        provider: "rapyd",
        createdAt: 1700000000000,
        title: "provider_event",
        description: "status_update",
        signatureValid: true,
        processed: true,
      },
    ]);

    expect(
      toInvoiceSummary({
        _id: fakeInvoiceId,
        status: "issued",
        externalInvoiceId: "INV-123",
        issuedAt: 1700000001000,
      }),
    ).toEqual({
      _id: fakeInvoiceId,
      status: "issued",
      externalInvoiceId: "INV-123",
      externalInvoiceUrl: "INV-123",
      issuedAt: 1700000001000,
    });

    expect(toInvoiceSummary(null)).toBeNull();
  });
});
