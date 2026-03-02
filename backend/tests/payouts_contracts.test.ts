import { describe, expect, it } from "bun:test";
import {
  computeNextPayoutWebhookStatus,
  normalizeRapydPayoutStatus,
} from "../convex/payouts";

describe("payout webhook contracts", () => {
  it("maps Rapyd payout raw statuses to internal payout states", () => {
    expect(normalizeRapydPayoutStatus("CLO")).toEqual({
      status: "paid",
      terminal: true,
    });
    expect(normalizeRapydPayoutStatus("CANCELED")).toEqual({
      status: "cancelled",
      terminal: true,
    });
    expect(normalizeRapydPayoutStatus("rejected")).toEqual({
      status: "failed",
      terminal: true,
    });
    expect(normalizeRapydPayoutStatus("NEW")).toEqual({
      status: "pending_provider",
      terminal: false,
    });
  });

  it("keeps terminal payouts sticky and normalizes transient webhook states", () => {
    expect(computeNextPayoutWebhookStatus("paid", "failed")).toBe("paid");
    expect(computeNextPayoutWebhookStatus("queued", "processing")).toBe(
      "pending_provider",
    );
    expect(computeNextPayoutWebhookStatus("processing", "queued")).toBe(
      "pending_provider",
    );
    expect(computeNextPayoutWebhookStatus("pending_provider", "failed")).toBe(
      "failed",
    );
  });
});
