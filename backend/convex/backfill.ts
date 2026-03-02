// convex/backfill.ts
// One-time migration script to populate geospatial indexes

import { mutation } from "./_generated/server";
import { syncInstructorLocation, syncJobLocation } from "./geo";

/**
 * Migration: Move all users and jobs into geospatial indexes.
 */
export const runGeospatialMigration = mutation({
  handler: async (ctx) => {
    // 1. Migrate Instructors
    const instructors = await ctx.db
      .query("users")
      .withIndex("by_role", (q) => q.eq("role", "instructor"))
      .collect();
    
    let instructorsSynced = 0;
    for (const instructor of instructors) {
      if (instructor.latitude && instructor.longitude) {
        await syncInstructorLocation(
          ctx,
          instructor._id,
          { latitude: instructor.latitude, longitude: instructor.longitude },
          instructor.dispatchMode ?? "radius", // Default to radius for existing users
          instructor.categories ??
            (instructor.primaryCategory
              ? [instructor.primaryCategory]
              : ["general"]),
          instructor.isVerified,
          instructor.notificationsEnabled ?? true,
          instructor.radiusKm ?? 5
        );
        instructorsSynced++;
      }
    }
    
    // 2. Migrate Open Jobs
    const jobs = await ctx.db
      .query("jobs")
      .withIndex("by_status", (q) => q.eq("status", "open"))
      .collect();
    
    let jobsSynced = 0;
    for (const job of jobs) {
      await syncJobLocation(
        ctx,
        job._id,
        { latitude: job.latitude, longitude: job.longitude },
        job.category,
        job.status,
        job.requiresVerification,
        job.currentRate
      );
      jobsSynced++;
    }
    
    return {
      instructorsSynced,
      jobsSynced,
      totalInstructors: instructors.length,
      totalJobs: jobs.length,
    };
  },
});
