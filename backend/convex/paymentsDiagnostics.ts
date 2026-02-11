import { query } from "./_generated/server";
import { v } from "convex/values";

const getTrimmedEnv = (name: string): string => (process.env[name] ?? "").trim();

export const getPaymentsPreflight = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .unique();
    if (!user) throw new Error("User not found");

    const required = [
      "RAPYD_ACCESS_KEY",
      "RAPYD_SECRET_KEY",
      "RAPYD_EWALLET",
      "CONVEX_SITE_URL",
    ] as const;

    const optional = [
      "RAPYD_BASE_URL",
      "RAPYD_SANDBOX_BASE_URL",
      "RAPYD_COUNTRY",
      "RAPYD_PAYOUT_METHOD_TYPE",
      "PAYMENTS_CURRENCY",
      "QUICKFIT_PLATFORM_FEE_BPS",
    ] as const;

    const requiredStatus = required.map((name) => ({
      name,
      configured: getTrimmedEnv(name).length > 0,
    }));
    const optionalStatus = optional.map((name) => ({
      name,
      configured: getTrimmedEnv(name).length > 0,
    }));

    const missingRequired = requiredStatus
      .filter((row) => !row.configured)
      .map((row) => row.name);

    const convexSiteUrl = getTrimmedEnv("CONVEX_SITE_URL");
    const rapydWebhookUrl = convexSiteUrl
      ? `${convexSiteUrl.replace(/\/+$/, "")}/webhooks/rapyd`
      : null;

    return {
      ready: missingRequired.length === 0,
      missingRequired,
      requiredStatus,
      optionalStatus,
      derived: {
        rapydWebhookUrl,
        rapydBaseUrl:
          getTrimmedEnv("RAPYD_BASE_URL") ||
          getTrimmedEnv("RAPYD_SANDBOX_BASE_URL") ||
          "https://sandboxapi.rapyd.net",
      },
      notes: [
        "Webhook signature uses RAPYD_SECRET_KEY when RAPYD_WEBHOOK_SECRET is absent.",
        "Use rapyd:createCheckoutForJob for studio checkout flow.",
      ],
      viewer: {
        userId: user._id,
        role: user.role,
      },
    };
  },
});

export const getEnvTemplate = query({
  args: {
    includeOptional: v.optional(v.boolean()),
  },
  handler: async (ctx, { includeOptional }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    const site = getTrimmedEnv("CONVEX_SITE_URL") || "https://your-deployment.convex.site";
    const lines = [
      "RAPYD_ACCESS_KEY=",
      "RAPYD_SECRET_KEY=",
      "RAPYD_EWALLET=",
      `# Rapyd callback: ${site.replace(/\/+$/, "")}/webhooks/rapyd`,
    ];
    if (includeOptional ?? true) {
      lines.push(
        "RAPYD_BASE_URL=https://sandboxapi.rapyd.net",
        "RAPYD_COUNTRY=IL",
        "RAPYD_PAYOUT_METHOD_TYPE=il_bank_transfer",
        "PAYMENTS_CURRENCY=ILS",
        "QUICKFIT_PLATFORM_FEE_BPS=1200",
      );
    }
    return lines.join("\n");
  },
});
