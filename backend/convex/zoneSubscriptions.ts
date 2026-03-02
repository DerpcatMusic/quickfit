// convex/zoneSubscriptions.ts
// Zone subscription management for O(1) zone-mode dispatch
// Clean, focused module - only handles zone subscriptions

import { query, internalQuery, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { Id, Doc } from "./_generated/dataModel";

const MVP_SKIP_CERTIFICATION = process.env.MVP_SKIP_CERTIFICATION === "true";

// ==========================================
// QUERIES
// ==========================================

/**
 * Find all zone-mode instructors for a zone + category combo.
 * This is the PRIMARY zone-mode dispatch query - O(1) with compound index.
 */
export const findZoneInstructors = internalQuery({
  args: {
    zoneId: v.id("zones"),
    category: v.string(),
    requiresVerification: v.optional(v.boolean()),
    isSos: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const subs = await ctx.db
      .query("zoneSubscriptions")
      .withIndex("by_zone_category", (q) =>
        q.eq("zoneId", args.zoneId).eq("category", args.category)
      )
      .collect();

    if (subs.length === 0) return [];

    // Fetch instructor details for filtering and notification
    const instructorIds = [...new Set(subs.map((s) => s.instructorId))];
    const instructors = await Promise.all(
      instructorIds.map((id) => ctx.db.get(id))
    );

    // Filter by verification if required and notifications enabled
    return instructors
      .filter((i): i is Doc<"users"> => {
        if (!i) return false;
        if (i.notificationsEnabled === false) return false;
        if (args.isSos && i.sosJobAlerts === false) return false;
        if (!args.isSos && i.regularJobAlerts === false) return false;
        if (!MVP_SKIP_CERTIFICATION && args.requiresVerification && !i.isVerified) return false;
        return true;
      })
      .map((i) => ({
        instructorId: i._id,
        name: i.name,
        fcmToken: i.fcmToken,
        isVerified: i.isVerified,
      }));
  },
});

/**
 * Get subscriptions for an instructor (for display/debugging).
 */
export const getMyZoneSubscriptions = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];

    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    if (!user) return [];

    const subs = await ctx.db
      .query("zoneSubscriptions")
      .withIndex("by_instructor", (q) => q.eq("instructorId", user._id))
      .collect();

    // Enrich with zone names
    return Promise.all(
      subs.map(async (sub) => {
        const zone = await ctx.db.get(sub.zoneId);
        return {
          _id: sub._id,
          zoneName: zone?.name ?? "Unknown",
          zoneNameHebrew: zone?.nameHebrew ?? "",
          category: sub.category,
        };
      })
    );
  },
});

// ==========================================
// MUTATIONS
// ==========================================

/**
 * Sync zone subscriptions for an instructor.
 * Called when instructor changes dispatch mode, zones, or categories.
 * 
 * Design: Always delete-all-then-recreate for simplicity.
 * At 500K users, this is still efficient because:
 * - Each instructor has max ~50 subscriptions (10 zones × 5 categories)
 * - Only affects the single instructor being updated
 */
export const syncZoneSubscriptions = internalMutation({
  args: { instructorId: v.id("users") },
  handler: async (ctx, { instructorId }) => {
    const instructor = await ctx.db.get(instructorId);
    if (!instructor || instructor.role !== "instructor") {
      return { deleted: 0, created: 0, mode: null };
    }

    // Delete existing subscriptions
    const existing = await ctx.db
      .query("zoneSubscriptions")
      .withIndex("by_instructor", (q) => q.eq("instructorId", instructorId))
      .collect();

    for (const sub of existing) {
      await ctx.db.delete(sub._id);
    }

    // Only create if zone mode with zones and categories
    if (instructor.dispatchMode !== "zone") {
      return { deleted: existing.length, created: 0, mode: instructor.dispatchMode };
    }

    const zoneIds = instructor.zoneIds ?? [];
    const categories = instructor.categories ?? [];

    if (zoneIds.length === 0 || categories.length === 0) {
      return { deleted: existing.length, created: 0, mode: "zone" };
    }

    const now = Date.now();
    let created = 0;

    // Create subscription for each zone × category combination
    for (const zoneId of zoneIds) {
      for (const category of categories) {
        await ctx.db.insert("zoneSubscriptions", {
          instructorId,
          zoneId,
          category,
          createdAt: now,
        });
        created++;
      }
    }

    return { deleted: existing.length, created, mode: "zone" };
  },
});

/**
 * Bulk sync all zone-mode instructors.
 * Used for migration or recovery.
 */
export const syncAllZoneSubscriptions = internalMutation({
  args: {},
  handler: async (ctx) => {
    const zoneInstructors = await ctx.db
      .query("users")
      .withIndex("by_dispatchMode", (q) => q.eq("dispatchMode", "zone").eq("role", "instructor"))
      .collect();

    let totalCreated = 0;
    let totalDeleted = 0;

    for (const instructor of zoneInstructors) {
      const result = await syncZoneSubscriptionsForUser(ctx, instructor._id);
      totalCreated += result.created;
      totalDeleted += result.deleted;
    }

    return { instructors: zoneInstructors.length, totalCreated, totalDeleted };
  },
});

// Helper to avoid code duplication
async function syncZoneSubscriptionsForUser(
  ctx: { db: any },
  instructorId: Id<"users">
): Promise<{ deleted: number; created: number }> {
  const instructor = await ctx.db.get(instructorId);
  if (!instructor) return { deleted: 0, created: 0 };

  const existing = await ctx.db
    .query("zoneSubscriptions")
    .withIndex("by_instructor", (q: any) => q.eq("instructorId", instructorId))
    .collect();

  for (const sub of existing) {
    await ctx.db.delete(sub._id);
  }

  if (instructor.dispatchMode !== "zone") {
    return { deleted: existing.length, created: 0 };
  }

  const zoneIds = instructor.zoneIds ?? [];
  const categories = instructor.categories ?? [];
  const now = Date.now();
  let created = 0;

  for (const zoneId of zoneIds) {
    for (const category of categories) {
      await ctx.db.insert("zoneSubscriptions", {
        instructorId,
        zoneId,
        category,
        createdAt: now,
      });
      created++;
    }
  }

  return { deleted: existing.length, created };
}
