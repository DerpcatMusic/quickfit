import {
  internalQuery,
  mutation,
  query,
  type MutationCtx,
  type QueryCtx,
} from "./_generated/server";
import { v } from "convex/values";
import { sealSecret } from "./lib/secrets";
import { validateAndNormalizeProviderBaseUrl } from "./lib/urlSecurity";

const requireStudioUser = async (ctx: QueryCtx | MutationCtx) => {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) throw new Error("Not authenticated");
  const user = await ctx.db
    .query("users")
    .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
    .unique();
  if (!user) throw new Error("User not found");
  if (user.role !== "studio")
    throw new Error("Only studios can manage billing");
  return user;
};

export const listMyInvoicingIntegrations = query({
  args: {},
  handler: async (ctx) => {
    const user = await requireStudioUser(ctx);

    const rows = await ctx.db
      .query("studioBillingIntegrations")
      .withIndex("by_studio", (q) => q.eq("studioId", user._id))
      .order("desc")
      .take(10);

    return rows.map((row) => ({
      _id: row._id,
      studioId: row.studioId,
      provider: row.provider,
      isActive: row.isActive,
      displayName: row.displayName,
      baseUrl: row.baseUrl,
      accountId: row.accountId,
      defaultVatRate: row.defaultVatRate,
      lastSyncError: row.lastSyncError,
      lastVerifiedAt: row.lastVerifiedAt,
      hasApiToken: Boolean(row.sealedApiToken),
      hasApiKey: Boolean(row.sealedApiKey),
      maskedApiToken: undefined,
      maskedApiKey: undefined,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    }));
  },
});

export const upsertMyInvoicingIntegration = mutation({
  args: {
    provider: v.union(v.literal("morning"), v.literal("icount")),
    isActive: v.optional(v.boolean()),
    displayName: v.optional(v.string()),
    baseUrl: v.string(),
    apiToken: v.optional(v.string()),
    apiKey: v.optional(v.string()),
    accountId: v.optional(v.string()),
    defaultVatRate: v.optional(v.float64()),
  },
  handler: async (ctx, args) => {
    const user = await requireStudioUser(ctx);

    const now = Date.now();
    const normalizedBaseUrl = validateAndNormalizeProviderBaseUrl(
      args.provider,
      args.baseUrl,
    );

    const existing = await ctx.db
      .query("studioBillingIntegrations")
      .withIndex("by_studio_provider", (q) =>
        q.eq("studioId", user._id).eq("provider", args.provider),
      )
      .unique();

    if (
      args.provider === "morning" &&
      !args.apiToken?.trim() &&
      !existing?.sealedApiToken
    ) {
      throw new Error("Morning integration requires API token");
    }
    if (
      args.provider === "icount" &&
      !args.apiKey?.trim() &&
      !existing?.sealedApiKey
    ) {
      throw new Error("iCount integration requires API key");
    }

    const sealedApiToken = args.apiToken?.trim()
      ? await sealSecret(args.apiToken.trim())
      : undefined;
    const sealedApiKey = args.apiKey?.trim()
      ? await sealSecret(args.apiKey.trim())
      : undefined;

    if (args.isActive === true) {
      const activeRows = await ctx.db
        .query("studioBillingIntegrations")
        .withIndex("by_studio_active", (q) =>
          q.eq("studioId", user._id).eq("isActive", true),
        )
        .take(10);
      for (const row of activeRows) {
        if (existing && row._id === existing._id) continue;
        if (row.isActive) {
          await ctx.db.patch(row._id, { isActive: false, updatedAt: now });
        }
      }
    }

    if (existing) {
      await ctx.db.patch(existing._id, {
        isActive: args.isActive ?? existing.isActive,
        displayName: args.displayName ?? existing.displayName,
        baseUrl: normalizedBaseUrl,
        apiToken: null,
        apiKey: null,
        sealedApiToken: sealedApiToken ?? existing.sealedApiToken,
        sealedApiKey: sealedApiKey ?? existing.sealedApiKey,
        accountId: args.accountId?.trim() || existing.accountId,
        defaultVatRate: args.defaultVatRate ?? existing.defaultVatRate,
        lastSyncError: undefined,
        updatedAt: now,
      });
      return existing._id;
    }

    return await ctx.db.insert("studioBillingIntegrations", {
      studioId: user._id,
      provider: args.provider,
      isActive: args.isActive ?? true,
      displayName: args.displayName?.trim(),
      baseUrl: normalizedBaseUrl,
      apiToken: null,
      apiKey: null,
      sealedApiToken,
      sealedApiKey,
      accountId: args.accountId?.trim(),
      defaultVatRate: args.defaultVatRate,
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const setMyInvoicingIntegrationActive = mutation({
  args: {
    provider: v.union(v.literal("morning"), v.literal("icount")),
    isActive: v.boolean(),
  },
  handler: async (ctx, args) => {
    const user = await requireStudioUser(ctx);

    const row = await ctx.db
      .query("studioBillingIntegrations")
      .withIndex("by_studio_provider", (q) =>
        q.eq("studioId", user._id).eq("provider", args.provider),
      )
      .unique();
    if (!row) throw new Error("Integration not found");

    const now = Date.now();
    if (args.isActive) {
      const allRows = await ctx.db
        .query("studioBillingIntegrations")
        .withIndex("by_studio_active", (q) =>
          q.eq("studioId", user._id).eq("isActive", true),
        )
        .take(10);
      for (const integration of allRows) {
        if (integration.isActive && integration._id !== row._id) {
          await ctx.db.patch(integration._id, {
            isActive: false,
            updatedAt: now,
          });
        }
      }
    }
    await ctx.db.patch(row._id, { isActive: args.isActive, updatedAt: now });
    return { success: true };
  },
});

export const removeMyInvoicingIntegration = mutation({
  args: { provider: v.union(v.literal("morning"), v.literal("icount")) },
  handler: async (ctx, args) => {
    const user = await requireStudioUser(ctx);

    const row = await ctx.db
      .query("studioBillingIntegrations")
      .withIndex("by_studio_provider", (q) =>
        q.eq("studioId", user._id).eq("provider", args.provider),
      )
      .unique();
    if (!row) return { success: true };
    await ctx.db.delete(row._id);
    return { success: true };
  },
});

export const getActiveStudioInvoicingIntegration = internalQuery({
  args: { studioId: v.id("users") },
  handler: async (ctx, { studioId }) => {
    const rows = await ctx.db
      .query("studioBillingIntegrations")
      .withIndex("by_studio_active", (q) =>
        q.eq("studioId", studioId).eq("isActive", true),
      )
      .order("desc")
      .take(1);
    return rows[0] ?? null;
  },
});

export const listMyPaymentIntegrations = query({
  args: {},
  handler: async (ctx) => {
    await requireStudioUser(ctx);
    return [];
  },
});

export const upsertMyPaymentIntegration = mutation({
  args: {
    provider: v.union(v.literal("rapyd"), v.literal("bitpay")),
    isActive: v.optional(v.boolean()),
    displayName: v.optional(v.string()),
    mode: v.optional(v.union(v.literal("sandbox"), v.literal("production"))),
    apiToken: v.optional(v.string()),
    apiKey: v.optional(v.string()),
    webhookSecret: v.optional(v.string()),
    accountId: v.optional(v.string()),
    merchantId: v.optional(v.string()),
  },
  handler: async (ctx, _args) => {
    await requireStudioUser(ctx);
    throw new Error(
      "Studio payment integrations are deprecated. Payments are managed by QuickFit platform.",
    );
  },
});

export const setMyPaymentIntegrationActive = mutation({
  args: {
    provider: v.union(v.literal("rapyd"), v.literal("bitpay")),
    isActive: v.boolean(),
  },
  handler: async (ctx, _args) => {
    await requireStudioUser(ctx);
    throw new Error(
      "Studio payment integrations are deprecated. Payments are managed by QuickFit platform.",
    );
  },
});

export const removeMyPaymentIntegration = mutation({
  args: { provider: v.union(v.literal("rapyd"), v.literal("bitpay")) },
  handler: async (ctx, _args) => {
    await requireStudioUser(ctx);
    throw new Error(
      "Studio payment integrations are deprecated. Payments are managed by QuickFit platform.",
    );
  },
});

export const getActiveStudioPaymentIntegration = internalQuery({
  args: { studioId: v.id("users") },
  handler: async (_ctx, _args) => {
    return null;
  },
});

export const getStudioPaymentIntegrationByProvider = internalQuery({
  args: {
    studioId: v.id("users"),
    provider: v.union(v.literal("rapyd"), v.literal("bitpay")),
  },
  handler: async (_ctx, _args) => {
    return null;
  },
});

export const migrateLegacyPlaintextSecrets = mutation({
  args: {},
  handler: async (ctx) => {
    const user = await requireStudioUser(ctx);
    const now = Date.now();
    let cleaned = 0;

    const billingRows = await ctx.db
      .query("studioBillingIntegrations")
      .withIndex("by_studio", (q) => q.eq("studioId", user._id))
      .collect();
    for (const row of billingRows) {
      const updates: Record<string, string | null | number | undefined> = {
        updatedAt: now,
      };
      let changed = false;
      if (!row.sealedApiToken && row.apiToken?.trim()) {
        updates.sealedApiToken = await sealSecret(row.apiToken.trim());
        changed = true;
      }
      if (!row.sealedApiKey && row.apiKey?.trim()) {
        updates.sealedApiKey = await sealSecret(row.apiKey.trim());
        changed = true;
      }
      if (row.apiToken != null) {
        updates.apiToken = null;
        changed = true;
      }
      if (row.apiKey != null) {
        updates.apiKey = null;
        changed = true;
      }
      if (changed) {
        await ctx.db.patch(row._id, updates);
        cleaned += 1;
      }
    }

    const paymentRows = await ctx.db
      .query("studioPaymentIntegrations")
      .withIndex("by_studio", (q) => q.eq("studioId", user._id))
      .collect();
    for (const row of paymentRows) {
      const updates: Record<string, string | null | number | undefined> = {
        updatedAt: now,
      };
      let changed = false;
      if (!row.sealedApiToken && row.apiToken?.trim()) {
        updates.sealedApiToken = await sealSecret(row.apiToken.trim());
        changed = true;
      }
      if (!row.sealedApiKey && row.apiKey?.trim()) {
        updates.sealedApiKey = await sealSecret(row.apiKey.trim());
        changed = true;
      }
      if (!row.sealedWebhookSecret && row.webhookSecret?.trim()) {
        updates.sealedWebhookSecret = await sealSecret(row.webhookSecret.trim());
        changed = true;
      }
      if (row.apiToken != null) {
        updates.apiToken = null;
        changed = true;
      }
      if (row.apiKey != null) {
        updates.apiKey = null;
        changed = true;
      }
      if (row.webhookSecret != null) {
        updates.webhookSecret = null;
        changed = true;
      }
      if (changed) {
        await ctx.db.patch(row._id, updates);
        cleaned += 1;
      }
    }

    return { cleaned };
  },
});
