// convex/geo.ts
// Geospatial indexes and helper functions for QuickFit
// Primary spatial indexing using Convex geospatial component

import { GeospatialIndex, Point } from "@convex-dev/geospatial";
import { v } from "convex/values";
import { components } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import { ActionCtx, MutationCtx, QueryCtx, query, mutation, internalQuery, internalMutation } from "./_generated/server";

const MVP_SKIP_CERTIFICATION = true; // Set to true to bypass verification checks for MVP
const MAX_RADIUS_KM = 15;

// ============================================
// GEOSPATIAL INDEX DEFINITIONS
// ============================================

/**
 * Instructor geospatial index.
 * Only contains radius-mode instructors - zone-mode uses zoneSubscriptions table.
 */
export const instructorGeo = new GeospatialIndex<
  Id<"users">,
  { 
    dispatchMode: "radius";  // Only radius mode in geo index
    categories: string[];
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
  dispatchMode: "radius" | "zone",
  categories: string[],
  verified: boolean,
  notificationsEnabled: boolean,
  radiusKm: number
): Promise<void> {
  // Always remove first
  try { 
    await instructorGeo.remove(ctx, instructorId); 
  } catch (e) {
    // Only log real errors, not "not found"
    const errStr = String(e);
    if (!errStr.includes("not found") && !errStr.includes("does not exist")) {
      console.error(`[geo:syncInstructorLocation] Remove failed for ${instructorId}:`, e);
    }
  }
  
  // Only add to geo index if radius mode
  if (dispatchMode !== "radius") {
    return;
  }
  
  const filterCategories = categories.length > 0 ? categories : ["general"];
  await instructorGeo.insert(
    ctx,
    instructorId,
    point,
    { dispatchMode: "radius", categories: filterCategories, verified, notificationsEnabled },
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
  try { 
    await instructorGeo.remove(ctx, instructorId); 
  } catch (e) {
    const errStr = String(e);
    if (!errStr.includes("not found") && !errStr.includes("does not exist")) {
      console.error(`[geo:removeInstructorLocation] Remove failed for ${instructorId}:`, e);
    }
  }
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
  const MAX_RADIUS_METERS = MAX_RADIUS_KM * 1000;

  const rectangle = boundingBox(jobPoint, MAX_RADIUS_METERS);
  const PAGE_SIZE = 512;
  let cursor: string | undefined = undefined;
  const results: Array<{ key: Id<"users">; coordinates: Point }> = [];

  do {
    const page = await instructorGeo.query(
      ctx,
      {
        shape: { type: "rectangle", rectangle },
        limit: PAGE_SIZE,
        filter: (q) => {
          let query = q.in("categories", [jobCategory]).eq("notificationsEnabled", true);
          if (!MVP_SKIP_CERTIFICATION && requiresVerification) {
            query = query.eq("verified", true);
          }
          return query;
        },
      },
      cursor
    );
    results.push(...page.results);
    cursor = page.nextCursor;
  } while (cursor);
  
  // Post-filter: Check if job is within each instructor's personal radius
  const matches: Array<{ instructorId: Id<"users">; distanceMeters: number; radiusKm: number }> = [];
  
  for (const result of results) {
    const instructor = await ctx.db.get(result.key);
    if (!instructor) continue;

    const distanceMeters = haversineDistanceMeters(
      instructor.latitude ?? result.coordinates.latitude,
      instructor.longitude ?? result.coordinates.longitude,
      jobPoint.latitude,
      jobPoint.longitude
    );

    if (distanceMeters > MAX_RADIUS_METERS) continue;

    const radiusKm = Math.min(instructor.radiusKm ?? MAX_RADIUS_KM, MAX_RADIUS_KM);
    const radiusMeters = radiusKm * 1000;

    if (distanceMeters <= radiusMeters) {
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
  const effectiveRadiusKm = Math.min(radiusKm, MAX_RADIUS_KM);
  const radiusMeters = effectiveRadiusKm * 1000;
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

/**
 * Build a bounding box around a point for a given radius (meters).
 */
function boundingBox(point: Point, radiusMeters: number) {
  const latRad = (point.latitude * Math.PI) / 180;
  const metersPerDegreeLat = 111_320;
  const metersPerDegreeLng = 111_320 * Math.cos(latRad);

  const deltaLat = radiusMeters / metersPerDegreeLat;
  const deltaLng = radiusMeters / metersPerDegreeLng;

  const south = clamp(point.latitude - deltaLat, -90, 90);
  const north = clamp(point.latitude + deltaLat, -90, 90);
  const west = clamp(point.longitude - deltaLng, -180, 180);
  const east = clamp(point.longitude + deltaLng, -180, 180);

  return { west, south, east, north };
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}
