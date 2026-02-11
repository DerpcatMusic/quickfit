// convex/zones.ts
// Zone management - Pikud HaOref geographic zones
// Real geographic boundaries for precision dispatch

import { query, mutation, internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { Id, Doc } from "./_generated/dataModel";
import { syncJobReadModels } from "./jobReadModels";

// ==========================================
// ZONE QUERIES
// ==========================================

/**
 * Get all zones (for initial map load)
 * Returns a compact format for efficient transfer
 */
export const getAllZones = query({
  args: {},
  handler: async (ctx) => {
    const zones = await ctx.db.query("zones").collect();
    return zones.map((z) => ({
      _id: z._id,
      orefId: z.orefId,
      name: z.name,
      nameHebrew: z.nameHebrew,
      city: z.city,
      centroid: z.centroid,
      polygon: z.polygon,
    }));
  },
});

export const getAllZonesPaginated = query({
  args: { paginationOpts: v.any() }, // Using v.any() or specific shape for pagination options
  handler: async (ctx, args) => {
    let opts = args.paginationOpts;
    if (typeof opts === "string") {
      opts = JSON.parse(opts);
    }
    const result = await ctx.db.query("zones").paginate(opts);
    
    return {
      ...result,
      page: result.page.map((z) => ({
        _id: z._id,
        orefId: z.orefId,
        name: z.name,
        nameHebrew: z.nameHebrew,
        city: z.city,
        centroid: z.centroid,
        polygon: z.polygon,
      })),
    };
  },
});

/**
 * Get zones by city (for filtered selection)
 */
export const getZonesByCity = query({
  args: { city: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("zones")
      .withIndex("by_city", (q) => q.eq("city", args.city))
      .collect();
  },
});

/**
 * Get unique cities (for zone grouping in UI)
 */
export const getCities = query({
  args: {},
  handler: async (ctx) => {
    const zones = await ctx.db.query("zones").collect();
    const cities = new Set<string>();
    for (const zone of zones) {
      if (zone.city) cities.add(zone.city);
    }
    return Array.from(cities).sort();
  },
});

/**
 * Search zones by name (for autocomplete)
 */
export const searchZones = query({
  args: { query: v.string() },
  handler: async (ctx, args) => {
    const q = args.query.toLowerCase();
    if (q.length < 2) return [];
    
    const zones = await ctx.db.query("zones").collect();
    return zones
      .filter((z) => 
        z.name.toLowerCase().includes(q) || 
        z.nameHebrew.includes(q) ||
        (z.city && z.city.toLowerCase().includes(q))
      )
      .slice(0, 20);
  },
});

/**
 * Get zone by ID
 */
export const getZone = query({
  args: { zoneId: v.id("zones") },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.zoneId);
  },
});

// ==========================================
// POINT-IN-POLYGON UTILITIES
// ==========================================

/**
 * Check if a point is inside a polygon using ray casting algorithm
 */
function isPointInPolygon(
  point: { lat: number; lng: number },
  polygon: { lat: number; lng: number }[]
): boolean {
  let inside = false;
  const x = point.lng;
  const y = point.lat;
  
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const xi = polygon[i].lng;
    const yi = polygon[i].lat;
    const xj = polygon[j].lng;
    const yj = polygon[j].lat;
    
    if (((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
      inside = !inside;
    }
  }
  
  return inside;
}

/**
 * Find which zone a point belongs to
 */
export const findZoneForPoint = query({
  args: { lat: v.float64(), lng: v.float64() },
  handler: async (ctx, args) => {
    const zones = await ctx.db.query("zones").collect();
    const point = { lat: args.lat, lng: args.lng };
    
    for (const zone of zones) {
      if (isPointInPolygon(point, zone.polygon)) {
        return zone;
      }
    }
    
    return null;
  },
});

// ==========================================
// INTERNAL: Zone detection for studios
// ==========================================

export const detectZoneForLocation = internalQuery({
  args: { lat: v.float64(), lng: v.float64() },
  handler: async (ctx, args): Promise<Id<"zones"> | null> => {
    const zones = await ctx.db.query("zones").collect();
    const point = { lat: args.lat, lng: args.lng };
    
    for (const zone of zones) {
      if (isPointInPolygon(point, zone.polygon)) {
        return zone._id;
      }
    }
    
    return null;
  },
});

export const backfillJobZoneForPostedJob = internalMutation({
  args: {
    jobId: v.id("jobs"),
  },
  handler: async (ctx, { jobId }) => {
    const job = await ctx.db.get(jobId);
    if (!job) return { updated: false, reason: "missing" };
    if (job.zoneId) return { updated: false, reason: "already_set" };

    const zones = await ctx.db.query("zones").collect();
    const point = { lat: job.latitude, lng: job.longitude };

    let detectedZoneId: Id<"zones"> | undefined;
    for (const zone of zones) {
      if (isPointInPolygon(point, zone.polygon)) {
        detectedZoneId = zone._id;
        break;
      }
    }

    if (!detectedZoneId) return { updated: false, reason: "not_found" };

    await ctx.db.patch(jobId, {
      zoneId: detectedZoneId,
      updatedAt: Date.now(),
    });
    await syncJobReadModels(ctx as any, jobId);

    return { updated: true, zoneId: detectedZoneId };
  },
});

// ==========================================
// ZONE SEEDING (Admin only)
// ==========================================

/**
 * Seed a single zone (called from bulk import action)
 */
export const seedZone = internalMutation({
  args: {
    orefId: v.string(),
    name: v.string(),
    nameHebrew: v.string(),
    city: v.optional(v.string()),
    polygon: v.array(v.object({ lat: v.float64(), lng: v.float64() })),
    centroid: v.object({ lat: v.float64(), lng: v.float64() }),
    shelterTime: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    // Check if zone already exists
    const existing = await ctx.db
      .query("zones")
      .withIndex("by_oref_id", (q) => q.eq("orefId", args.orefId))
      .first();
    
    if (existing) {
      // Update existing
      await ctx.db.patch(existing._id, {
        name: args.name,
        nameHebrew: args.nameHebrew,
        city: args.city,
        polygon: args.polygon,
        centroid: args.centroid,
        shelterTime: args.shelterTime,
      });
      return existing._id;
    }
    
    // Insert new
    return await ctx.db.insert("zones", {
      orefId: args.orefId,
      name: args.name,
      nameHebrew: args.nameHebrew,
      city: args.city,
      polygon: args.polygon,
      centroid: args.centroid,
      shelterTime: args.shelterTime,
    });
  },
});

/**
 * Clear all zones (for re-seeding)
 */
export const clearAllZones = internalMutation({
  args: {},
  handler: async (ctx) => {
    const zones = await ctx.db.query("zones").collect();
    for (const zone of zones) {
      await ctx.db.delete(zone._id);
    }
    return zones.length;
  },
});

// ==========================================
// ZONE STATS
// ==========================================

export const getZoneStats = query({
  args: {},
  handler: async (ctx) => {
    const zones = await ctx.db.query("zones").collect();
    const cities = new Set<string>();
    for (const zone of zones) {
      if (zone.city) cities.add(zone.city);
    }
    
    return {
      totalZones: zones.length,
      totalCities: cities.size,
    };
  },
});
