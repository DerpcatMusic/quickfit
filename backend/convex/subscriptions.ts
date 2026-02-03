// convex/subscriptions.ts
// Subscription management - Pre-computed instructor-studio relationships
// Enables O(1) job dispatch queries

import { query, mutation, internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { Id, Doc } from "./_generated/dataModel";
import { internal } from "./_generated/api";

// ==========================================
// SUBSCRIPTION QUERIES
// ==========================================

/**
 * Get all instructors subscribed to a studio for a category
 * This is the PRIMARY dispatch query - O(1) with index
 */
export const getSubscribedInstructors = internalQuery({
  args: {
    studioId: v.id("users"),
    category: v.string(),
  },
  handler: async (ctx, args) => {
    const subs = await ctx.db
      .query("subscriptions")
      .withIndex("by_studio_category", (q) =>
        q.eq("studioId", args.studioId).eq("category", args.category)
      )
      .collect();
    
    // Fetch instructor details
    const instructorIds = [...new Set(subs.map((s) => s.instructorId))];
    const instructors = await Promise.all(
      instructorIds.map((id) => ctx.db.get(id))
    );
    
    return instructors.filter((i): i is Doc<"users"> => i !== null);
  },
});

/**
 * Get subscriptions for an instructor (for debugging/display)
 */
export const getInstructorSubscriptions = query({
  args: { instructorId: v.id("users") },
  handler: async (ctx, args) => {
    const subs = await ctx.db
      .query("subscriptions")
      .withIndex("by_instructor", (q) => q.eq("instructorId", args.instructorId))
      .collect();
    
    // Fetch studio names
    const result = await Promise.all(
      subs.map(async (sub) => {
        const studio = await ctx.db.get(sub.studioId);
        const zone = await ctx.db.get(sub.zoneId);
        return {
          _id: sub._id,
          studioName: studio?.name ?? "Unknown",
          category: sub.category,
          zoneName: zone?.name ?? "Unknown",
        };
      })
    );
    
    return result;
  },
});

// ==========================================
// SUBSCRIPTION MUTATIONS
// ==========================================

/**
 * Recalculate subscriptions for an instructor based on their selected zones
 * Called when instructor updates their profile (zones or categories)
 */
export const recalculateInstructorSubscriptions = internalMutation({
  args: { instructorId: v.id("users") },
  handler: async (ctx, args) => {
    const instructor = await ctx.db.get(args.instructorId);
    if (!instructor || instructor.role !== "instructor") {
      return { deleted: 0, created: 0 };
    }
    
    // Clear existing subscriptions
    const existingSubs = await ctx.db
      .query("subscriptions")
      .withIndex("by_instructor", (q) => q.eq("instructorId", args.instructorId))
      .collect();
    
    for (const sub of existingSubs) {
      await ctx.db.delete(sub._id);
    }
    
    const selectedZones = instructor.selectedZones ?? [];
    const categories = instructor.categories ?? [];
    
    if (selectedZones.length === 0 || categories.length === 0) {
      return { deleted: existingSubs.length, created: 0 };
    }
    
    // Find all studios in the selected zones
    const studios = await ctx.db
      .query("users")
      .withIndex("by_role", (q) => q.eq("role", "studio"))
      .collect();
    
    let created = 0;
    const now = Date.now();
    
    for (const studio of studios) {
      if (!studio.zoneId) continue;
      
      // Check if studio's zone is in instructor's selected zones
      if (!selectedZones.includes(studio.zoneId)) continue;
      
      // Create subscription for each matching category
      const studioCategories = studio.categories ?? [];
      const matchingCategories = categories.filter((c) =>
        studioCategories.includes(c)
      );
      
      for (const category of matchingCategories) {
        await ctx.db.insert("subscriptions", {
          instructorId: args.instructorId,
          studioId: studio._id,
          category,
          zoneId: studio.zoneId,
          createdAt: now,
        });
        created++;
      }
    }
    
    return { deleted: existingSubs.length, created };
  },
});

/**
 * Recalculate subscriptions for a studio (when studio is created/updated)
 * Finds all instructors whose zones include this studio's zone
 */
export const recalculateStudioSubscriptions = internalMutation({
  args: { studioId: v.id("users") },
  handler: async (ctx, args) => {
    const studio = await ctx.db.get(args.studioId);
    if (!studio || studio.role !== "studio" || !studio.zoneId) {
      return { deleted: 0, created: 0 };
    }
    
    // Clear existing subscriptions for this studio
    const existingSubs = await ctx.db
      .query("subscriptions")
      .withIndex("by_studio_category", (q) => q.eq("studioId", args.studioId))
      .collect();
    
    // Note: This is inefficient but we're gathering all before deleting
    // to avoid index modification during iteration
    const subsToDelete = existingSubs.filter((s) => s.studioId === args.studioId);
    for (const sub of subsToDelete) {
      await ctx.db.delete(sub._id);
    }
    
    const studioCategories = studio.categories ?? [];
    if (studioCategories.length === 0) {
      return { deleted: subsToDelete.length, created: 0 };
    }
    
    // Find all instructors who have this zone in their selected zones
    const instructors = await ctx.db
      .query("users")
      .withIndex("by_role", (q) => q.eq("role", "instructor"))
      .collect();
    
    let created = 0;
    const now = Date.now();
    
    for (const instructor of instructors) {
      const selectedZones = instructor.selectedZones ?? [];
      if (!selectedZones.includes(studio.zoneId)) continue;
      
      const instructorCategories = instructor.categories ?? [];
      const matchingCategories = studioCategories.filter((c) =>
        instructorCategories.includes(c)
      );
      
      for (const category of matchingCategories) {
        await ctx.db.insert("subscriptions", {
          instructorId: instructor._id,
          studioId: args.studioId,
          category,
          zoneId: studio.zoneId,
          createdAt: now,
        });
        created++;
      }
    }
    
    return { deleted: subsToDelete.length, created };
  },
});
