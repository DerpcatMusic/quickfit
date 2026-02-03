// convex/geo.ts
// Geospatial indexes and helper functions for QuickFit
// Replaces H3 with Convex's native geospatial component

import { GeospatialIndex, Point } from "@convex-dev/geospatial";
import { v } from "convex/values";
import { components } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import { ActionCtx, MutationCtx, QueryCtx, query, mutation, internalQuery, internalMutation } from "./_generated/server";

// ============================================
// GEOSPATIAL INDEX DEFINITIONS
// ============================================

/**
 * Instructor geospatial index.
 */
export const instructorGeo = new GeospatialIndex<
  Id<"users">,
  { 
    category: string;
    verified: boolean;
    notificationsEnabled: boolean;
  }
>(components.geospatial);

/**
 * Job geospatial index.
 */
export const jobGeo = new GeospatialIndex<
  Id<"jobs">,
  {
    category: string;
    status: string;
    requiresVerification: boolean;
  }
>(components.geospatial);

// ============================================
// API ENDPOINTS (Wrappers)
// ============================================

export const findInstructorsForJobQuery = internalQuery({
  args: {
    jobPoint: v.object({ latitude: v.number(), longitude: v.number() }),
    jobCategory: v.string(),
    requiresVerification: v.boolean(),
  },
  handler: async (ctx, args) => {
    return await findInstructorsForJob(ctx, args.jobPoint, args.jobCategory, args.requiresVerification);
  },
});

export const getNearbyJobsForInstructor = query({
  args: {
    latitude: v.string(),
    longitude: v.string(),
    radiusKm: v.string(),
    categories: v.string(), // comma separated
    isVerified: v.string(), // "true" or "false"
  },
  handler: async (ctx, args) => {
    return await findJobsForInstructor(
      ctx, 
      { 
        latitude: parseFloat(args.latitude), 
        longitude: parseFloat(args.longitude) 
      }, 
      parseFloat(args.radiusKm), 
      args.categories.split(','), 
      args.isVerified === 'true'
    );
  },
});

// ============================================
// GEOSPATIAL SYNC FUNCTIONS (Internal)
// ============================================

/**
 * Sync instructor location to geospatial index.
 */
export async function syncInstructorLocation(
  ctx: MutationCtx,
  instructorId: Id<"users">,
  point: Point,
  category: string,
  verified: boolean,
  notificationsEnabled: boolean,
  radiusKm: number
): Promise<void> {
  try { await instructorGeo.remove(ctx, instructorId); } catch {}
  await instructorGeo.insert(
    ctx,
    instructorId,
    point,
    { category, verified, notificationsEnabled },
    radiusKm
  );
}

/**
 * Remove instructor from geospatial index.
 */
export async function removeInstructorLocation(
  ctx: MutationCtx,
  instructorId: Id<"users">
): Promise<void> {
  try { await instructorGeo.remove(ctx, instructorId); } catch {}
}

/**
 * Sync job location to geospatial index.
 */
export async function syncJobLocation(
  ctx: MutationCtx,
  jobId: Id<"jobs">,
  point: Point,
  category: string,
  status: string,
  requiresVerification: boolean,
  currentRate: number
): Promise<void> {
  try { await jobGeo.remove(ctx, jobId); } catch {}
  await jobGeo.insert(
    ctx,
    jobId,
    point,
    { category, status, requiresVerification },
    currentRate
  );
}

/**
 * Remove job from geospatial index.
 */
export async function removeJobLocation(
  ctx: MutationCtx,
  jobId: Id<"jobs">
): Promise<void> {
  try { await jobGeo.remove(ctx, jobId); } catch {}
}

// ============================================
// INTERNAL HELPER FUNCTIONS
// ============================================

/**
 * Find instructors who should be notified about a job.
 */
export async function findInstructorsForJob(
  ctx: QueryCtx,
  jobPoint: Point,
  jobCategory: string,
  requiresVerification: boolean
): Promise<Array<{ instructorId: Id<"users">; distanceMeters: number; radiusKm: number }>> {
  const MAX_RADIUS_METERS = 50_000; // 50km max search radius
  
  // Query instructors within max radius who match category
  const results = await instructorGeo.nearest(ctx, {
    point: jobPoint,
    limit: 1000, 
    maxDistance: MAX_RADIUS_METERS,
    filter: (q) => q
      .eq("category", jobCategory)
      .eq("notificationsEnabled", true),
  });
  
  // Post-filter: Check if job is within each instructor's personal radius
  const matches: Array<{ instructorId: Id<"users">; distanceMeters: number; radiusKm: number }> = [];
  
  for (const result of results) {
    // Calculate distance from result coordinates to job point
    const instructorCoords = result.coordinates;
    const distanceMeters = haversineDistanceMeters(
      instructorCoords.latitude,
      instructorCoords.longitude,
      jobPoint.latitude,
      jobPoint.longitude
    );
    
    // Get instructor's radius from sortKey
    const radiusKm = (result as any).sortKey ?? 5; 
    const radiusMeters = radiusKm * 1000;
    
    // CRITICAL: Job must be within instructor's personal radius
    if (distanceMeters <= radiusMeters) {
      if (requiresVerification) {
        const instructor = await ctx.db.get(result.key);
        if (!instructor?.isVerified) {
          continue;
        }
      }
      
      matches.push({
        instructorId: result.key,
        distanceMeters: Math.round(distanceMeters),
        radiusKm,
      });
    }
  }
  
  return matches.sort((a, b) => a.distanceMeters - b.distanceMeters);
}

/**
 * Find jobs within an instructor's radius.
 */
export async function findJobsForInstructor(
  ctx: QueryCtx,
  instructorPoint: Point,
  radiusKm: number,
  categories: string[],
  isVerified: boolean
): Promise<Array<{ 
  _id: Id<"jobs">; 
  title: string;
  category: string;
  latitude: number;
  longitude: number;
  sosBoostApplied: boolean;
  currentRate: number;
  distanceMeters: number;
}>> {
  const radiusMeters = radiusKm * 1000;
  const allJobs: Array<{ 
    _id: Id<"jobs">; 
    title: string;
    category: string;
    latitude: number;
    longitude: number;
    sosBoostApplied: boolean;
    currentRate: number;
    distanceMeters: number;
  }> = [];
  
  for (const category of categories) {
    const results = await jobGeo.nearest(ctx, {
      point: instructorPoint,
      limit: 100,
      maxDistance: radiusMeters,
      filter: (q) => {
        let query = q.eq("category", category).eq("status", "open");
        if (!isVerified) {
          query = query.eq("requiresVerification", false);
        }
        return query;
      },
    });
    
    for (const result of results) {
      const job = await ctx.db.get(result.key);
      if (!job) continue;

      const jobCoords = result.coordinates;
      const distanceMeters = haversineDistanceMeters(
        instructorPoint.latitude,
        instructorPoint.longitude,
        jobCoords.latitude,
        jobCoords.longitude
      );
      
      allJobs.push({
        _id: result.key,
        title: job.title,
        category: job.category,
        latitude: jobCoords.latitude,
        longitude: jobCoords.longitude,
        sosBoostApplied: job.sosBoostApplied,
        currentRate: job.currentRate,
        distanceMeters: Math.round(distanceMeters),
      });
    }
  }
  
  const uniqueJobs = new Map<string, typeof allJobs[0]>();
  for (const job of allJobs) {
    if (!uniqueJobs.has(job._id)) {
      uniqueJobs.set(job._id, job);
    }
  }
  
  return Array.from(uniqueJobs.values()).sort((a, b) => a.distanceMeters - b.distanceMeters);
}

// ============================================
// HAVERSINE HELPER (for legacy compatibility)
// ============================================

/**
 * Calculate distance between two points in meters.
 * Useful for manual distance checks.
 */
export function haversineDistanceMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const EARTH_RADIUS_KM = 6371;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  
  return EARTH_RADIUS_KM * c * 1000;
}

/**
 * Calculate distance between two points in km.
 */
export function haversineDistanceKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  return haversineDistanceMeters(lat1, lng1, lat2, lng2) / 1000;
}

/**
 * Check if a point is within a radius of another point.
 * Returns distance info for use in distance displays.
 */
export function isWithinRadius(
  centerLat: number,
  centerLng: number,
  radiusKm: number,
  pointLat: number,
  pointLng: number
): { isWithin: boolean; distanceKm: number; distanceMeters: number } {
  const distanceMeters = haversineDistanceMeters(centerLat, centerLng, pointLat, pointLng);
  const distanceKm = distanceMeters / 1000;
  
  return {
    isWithin: distanceKm <= radiusKm,
    distanceKm: Math.round(distanceKm * 100) / 100,
    distanceMeters: Math.round(distanceMeters),
  };
}
