// convex/jobs.ts
// Job queries and mutations

import { query, mutation, internalQuery, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import { 
  haversineDistanceMeters, 
  haversineDistanceKm,
  isWithinRadius,
  findJobsForInstructor,
  syncJobLocation,
  removeJobLocation,
} from "./geo";

// Categories for Israeli market
export const CATEGORIES = [
  "yoga",
  "pilates", 
  "functional",
  "spinning",
  "hiit",
  "dance",
  "personal_training",
] as const;

// ==========================================
// QUERIES
// ==========================================

export const getJobInternal = internalQuery({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    return await ctx.db.get(jobId);
  },
});

export const getJobById = query({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const job = await ctx.db.get(jobId);
    if (!job) return null;

    const studio = await ctx.db.get(job.studioId);
    let claimedInstructor = null;
    
    if (job.claimedBy) {
      const instructor = await ctx.db.get(job.claimedBy);
      if (instructor) {
        claimedInstructor = {
          _id: instructor._id,
          name: instructor.name,
          photoUrl: instructor.avatarUrl,
          isVerified: instructor.isVerified,
        };
      }
    }

    const identity = await ctx.auth.getUserIdentity();
    const user = identity ? await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first() : null;

    const isOwner = user?._id === job.studioId;
    const isPrimary = user?._id === job.claimedBy;
    const isBackup = user?._id === job.backupClaimedBy;

    // Get the active claim ID (most recent accepted or pending claim)
    let activeClaim = null;
    if (job.claimedBy) {
      activeClaim = await ctx.db
        .query("claims")
        .withIndex("by_job", (q) => q.eq("jobId", jobId))
        .filter((q) => q.eq(q.field("instructorId"), job.claimedBy))
        .first();
    }

    return {
      ...job,
      studioName: studio?.businessName || studio?.name || "Studio",
      claimedInstructor,
      claimId: activeClaim?._id,
      canClaimAsPrimary: job.status === "open",
      canClaimAsBackup: job.status === "claimed" && !job.backupClaimedBy && !isPrimary && !isOwner,
      userRole: isOwner ? "owner" : (isPrimary ? "primary" : (isBackup ? "backup" : "viewer")),
    };
  },
});

/**
 * Get jobs within instructor's configured radius.
 * Uses Haversine formula for meter-level precision.
 * A 2.95km job WILL match a 3.00km radius.
 */
export const getNearbyJobs = query({
  args: { limit: v.optional(v.union(v.number(), v.string())) },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user || user.role !== "instructor") return [];
    
    const categories =
      user.categories && user.categories.length > 0
        ? user.categories
        : ["general"];

    let jobResults: Array<{
      _id: Id<"jobs">;
      title: string;
      category: string;
      latitude: number;
      longitude: number;
      sosBoostApplied: boolean;
      currentRate: number;
      distanceMeters: number;
    }> = [];

    if (user.dispatchMode === "zone") {
      jobResults = await findJobsForInstructorByZones(
        ctx,
        user,
        user.zoneIds ?? [],
        categories
      );
    } else {
      if (!user.latitude || !user.longitude || !user.radiusKm) return [];
      jobResults = await findJobsForInstructor(
        ctx,
        { latitude: user.latitude, longitude: user.longitude },
        user.radiusKm,
        categories,
        user.isVerified
      );
    }
    
    // Sort by SOS first (manually sorting the enriched results later if needed)
    // For now, these results are already distance-sorted.
    const parsedLimit =
      typeof args.limit === "string"
        ? parseInt(args.limit, 10)
        : args.limit;
    const safeLimit = Number.isFinite(parsedLimit ?? NaN)
      ? (parsedLimit as number)
      : 50;
    const limitedResults = jobResults.slice(0, safeLimit ?? 50);
    
    // Enrichment: Add studio info to enriched results from geo.ts
    const enrichedJobs = await Promise.all(
      limitedResults.map(async (match) => {
        // Fetch full job for relations if needed, but match contains the key data
        const jobDoc = await ctx.db.get(match._id);
        if (!jobDoc) return null;

        const studioDoc = await ctx.db.get(jobDoc.studioId);
        
        return {
          ...jobDoc,
          distanceMeters: match.distanceMeters,
          distanceKm: match.distanceMeters / 1000,
          studioName: studioDoc?.businessName || studioDoc?.name || "Unknown Studio",
          studioAvatarUrl: studioDoc?.avatarUrl,
        };
      })
    );
    
    return enrichedJobs.filter((j): j is NonNullable<typeof j> => j !== null);
  },
});

/**
 * Get jobs within a specific radius for map display.
 * Returns all open jobs with precise distance.
 */
export const getJobsForMap = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return { jobs: [], userLocation: null };
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user || user.role !== "instructor") {
      return { jobs: [], userLocation: null };
    }
    
    if (!user.latitude || !user.longitude) {
      return { jobs: [], userLocation: null };
    }

    const categories =
      user.categories && user.categories.length > 0
        ? user.categories
        : ["general"];

    let jobResults: Array<{
      _id: Id<"jobs">;
      title: string;
      category: string;
      latitude: number;
      longitude: number;
      sosBoostApplied: boolean;
      currentRate: number;
      distanceMeters: number;
    }> = [];

    if (user.dispatchMode === "zone") {
      jobResults = await findJobsForInstructorByZones(
        ctx,
        user,
        user.zoneIds ?? [],
        categories
      );
    } else {
      const radiusKm = user.radiusKm ?? 5;
      jobResults = await findJobsForInstructor(
        ctx,
        { latitude: user.latitude, longitude: user.longitude },
        radiusKm,
        categories,
        user.isVerified
      );
    }
    
    return {
      jobs: jobResults,
      userLocation: { latitude: user.latitude, longitude: user.longitude },
    };
  },
});

/**
 * Zone-mode jobs for map/list. Optional zoneIds override for preview.
 */
export const getZoneJobsForInstructor = query({
  args: {
    zoneIds: v.optional(v.string()),
    categories: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];

    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    if (!user || user.role !== "instructor") return [];

    const categories =
      args.categories?.split(",").map((c) => c.trim()).filter(Boolean) ??
      (user.categories && user.categories.length > 0
        ? user.categories
        : ["general"]);

    let zoneIds: Id<"zones">[] = user.zoneIds ?? [];
    if (args.zoneIds) {
      try {
        const parsed = JSON.parse(args.zoneIds) as string[];
        if (Array.isArray(parsed) && parsed.length > 0) {
          zoneIds = parsed as Id<"zones">[];
        }
      } catch {}
    }

    if (zoneIds.length === 0) return [];

    return await findJobsForInstructorByZones(ctx, user, zoneIds, categories);
  },
});

async function findJobsForInstructorByZones(
  ctx: { db: any },
  user: any,
  zoneIds: Id<"zones">[],
  categories: string[]
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
  const MAX_RESULTS = 200;
  const jobsMap = new Map<string, any>();
  const hasUserLocation = !!(user.latitude && user.longitude);

  for (const zoneId of zoneIds) {
    if (jobsMap.size >= MAX_RESULTS) break;

    if (categories.length > 0) {
      for (const category of categories) {
        const jobs = await ctx.db
          .query("jobs")
          .withIndex("by_zone_category_status", (q: any) =>
            q.eq("zoneId", zoneId).eq("category", category).eq("status", "open")
          )
          .collect();

        for (const job of jobs) {
          if (!user.isVerified && job.requiresVerification) continue;
          if (!jobsMap.has(job._id)) {
            const distanceMeters = hasUserLocation
              ? Math.round(
                  haversineDistanceMeters(
                    user.latitude,
                    user.longitude,
                    job.latitude,
                    job.longitude
                  )
                )
              : 0;
            jobsMap.set(job._id, {
              _id: job._id,
              title: job.title,
              category: job.category,
              latitude: job.latitude,
              longitude: job.longitude,
              sosBoostApplied: job.sosBoostApplied,
              currentRate: job.currentRate,
              distanceMeters,
              createdAt: job.createdAt,
            });
            if (jobsMap.size >= MAX_RESULTS) break;
          }
        }
        if (jobsMap.size >= MAX_RESULTS) break;
      }
    } else {
      const jobs = await ctx.db
        .query("jobs")
        .withIndex("by_zone_status", (q: any) =>
          q.eq("zoneId", zoneId).eq("status", "open")
        )
        .collect();

      for (const job of jobs) {
        if (!user.isVerified && job.requiresVerification) continue;
        if (!jobsMap.has(job._id)) {
          const distanceMeters = hasUserLocation
            ? Math.round(
                haversineDistanceMeters(
                  user.latitude,
                  user.longitude,
                  job.latitude,
                  job.longitude
                )
              )
            : 0;
          jobsMap.set(job._id, {
            _id: job._id,
            title: job.title,
            category: job.category,
            latitude: job.latitude,
            longitude: job.longitude,
            sosBoostApplied: job.sosBoostApplied,
            currentRate: job.currentRate,
            distanceMeters,
            createdAt: job.createdAt,
          });
          if (jobsMap.size >= MAX_RESULTS) break;
        }
      }
    }
  }

  const results = Array.from(jobsMap.values());
  if (hasUserLocation) {
    results.sort((a, b) => a.distanceMeters - b.distanceMeters);
  } else {
    results.sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0));
  }
  return results;
}

/**
 * Get instructor statistics for dashboard.
 */
export const getInstructorStats = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user || user.role !== "instructor") return null;
    
    // Get confirmed/completed jobs claimed by this instructor
    const claims = await ctx.db
      .query("claims")
      .withIndex("by_instructor", (q) => q.eq("instructorId", user._id))
      .collect();
    
    const acceptedClaims = claims.filter((c) => c.status === "accepted");
    
    // Get job details for earnings calculation
    const jobIds = acceptedClaims.map((c) => c.jobId);
    const jobs = await Promise.all(jobIds.map((id) => ctx.db.get(id)));
    
    // Calculate stats
    const now = Date.now();
    const oneMonthAgo = now - 30 * 24 * 60 * 60 * 1000;
    
    const thisMonthJobs = jobs.filter(
      (j) => j && j.createdAt >= oneMonthAgo
    );
    
    const totalEarnings = jobs.reduce(
      (sum, j) => sum + (j?.currentRate || 0),
      0
    );
    
    const thisMonthEarnings = thisMonthJobs.reduce(
      (sum, j) => sum + (j?.currentRate || 0),
      0
    );
    
    return {
      totalJobsCompleted: acceptedClaims.length,
      jobsThisMonth: thisMonthJobs.length,
      totalEarnings: Math.round(totalEarnings),
      earningsThisMonth: Math.round(thisMonthEarnings),
      rating: user.rating ?? 0,
      ratingCount: user.ratingCount ?? 0,
      isVerified: user.isVerified,
      radiusKm: user.radiusKm ?? 5,
      categories: user.categories ?? [],
    };
  },
});


export const getStudioJobs = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user || user.role !== "studio") return [];
    
    const jobs = await ctx.db
      .query("jobs")
      .withIndex("by_studio", (q) => q.eq("studioId", user._id))
      .order("desc")
      .take(100);
    
    // Add claimed instructor info
    const jobsWithDetails = await Promise.all(
      jobs.map(async (job) => {
        let claimedInstructor = null;
        if (job.claimedBy) {
          const instructor = await ctx.db.get(job.claimedBy);
          if (instructor) {
            claimedInstructor = {
              _id: instructor._id,
              name: instructor.name,
              avatarUrl: instructor.avatarUrl,
              rating: instructor.rating,
              isVerified: instructor.isVerified,
            };
          }
        }
        
        return { ...job, claimedInstructor };
      })
    );
    
    return jobsWithDetails;
  },
});

// ==========================================
// MUTATIONS
// ==========================================

export const postJob = mutation({
  args: {
    title: v.string(),
    description: v.optional(v.string()),
    category: v.string(),
    startTime: v.number(),
    endTime: v.number(),
    baseRate: v.float64(),
    address: v.string(),
    latitude: v.float64(),
    longitude: v.float64(),
    requiresVerification: v.optional(v.boolean()),
  },
  handler: async (ctx, args): Promise<Id<"jobs">> => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user || user.role !== "studio") {
      throw new Error("Only studios can post jobs");
    }
    
    const now = Date.now();
    const hoursUntilStart = (args.startTime - now) / (1000 * 60 * 60);
    
    // SOS Detection: < 3 hours = 15% boost
    const isSOS = hoursUntilStart < 3 && hoursUntilStart > 0;
    const sosBoostPercentage = isSOS ? 15 : 0;
    const currentRate = isSOS ? args.baseRate * 1.15 : args.baseRate;
    
    const durationMinutes = Math.round((args.endTime - args.startTime) / (1000 * 60));
    const zoneId = await ctx.runQuery(internal.zones.detectZoneForLocation, {
      lat: args.latitude,
      lng: args.longitude,
    });
    
    const jobId = await ctx.db.insert("jobs", {
      studioId: user._id,
      title: args.title,
      description: args.description,
      category: args.category,
      startTime: args.startTime,
      endTime: args.endTime,
      durationMinutes,
      baseRate: args.baseRate,
      currentRate,
      sosBoostApplied: isSOS,
      sosBoostPercentage: isSOS ? sosBoostPercentage : undefined,
      latitude: args.latitude,
      longitude: args.longitude,
      address: args.address,
      zoneId: zoneId ?? undefined,
      status: "open",
      requiresVerification: args.requiresVerification ?? true,
      notificationsSent: false,
      createdAt: now,
      updatedAt: now,
    });

    // 2026 GEOSPATIAL SYNC
    // ==========================================
    await syncJobLocation(
      ctx,
      jobId,
      { latitude: args.latitude, longitude: args.longitude },
      args.category,
      "open",
      args.requiresVerification ?? true,
      currentRate
    );
    
    // If SOS, add to priority queue
    if (isSOS) {
      await ctx.db.insert("sosPriorityQueue", {
        jobId,
        startTime: args.startTime,
        hoursUntilStart,
        boostPercentage: sosBoostPercentage,
        processed: false,
        createdAt: now,
      });
    }
    
    // Schedule notification dispatch with version guard
    await scheduleJobDispatch(ctx, jobId);
    
    return jobId;
  },
});

// ==========================================
// CONFIGURATION
// ==========================================
const MVP_SKIP_CERTIFICATION = true; // Set to true to allow non-verified instructors for MVP
const MAX_RADIUS_KM = 15;
const CLAIM_RESPONSE_TIMEOUT_MS = 2 * 60 * 1000;
const DISPATCH_MAX_RETRIES = 4;
const DISPATCH_BASE_DELAY_MS = 2 * 1000;
const DISPATCH_MAX_DELAY_MS = 60 * 1000;

async function scheduleJobDispatch(
  ctx: { db: any; scheduler: any },
  jobId: Id<"jobs">,
) {
  const job = await ctx.db.get(jobId);
  if (!job || job.status !== "open") return;

  const nextVersion = (job.dispatchVersion ?? 0) + 1;
  const now = Date.now();

  await ctx.db.patch(jobId, {
    dispatchVersion: nextVersion,
    dispatchAttempt: 0,
    dispatchScheduledAt: now,
    dispatchLastError: undefined,
    notificationsSent: false,
    notifiedInstructors: undefined,
    updatedAt: now,
  });

  await ctx.scheduler.runAfter(0, internal.notifications.dispatchJobNotifications, {
    jobId,
    dispatchVersion: nextVersion,
  });
}

export const claimJob = mutation({
  args: {
    jobId: v.id("jobs"),
    message: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user || user.role !== "instructor") {
      throw new Error("Only instructors can claim jobs");
    }
    
    const job = await ctx.db.get(args.jobId);
    if (!job) throw new Error("Job not found");

    const isZoneMode = user.dispatchMode === "zone";
    if (!isZoneMode && (!user.latitude || !user.longitude || !user.radiusKm)) {
      throw new Error("Complete your profile location and radius before claiming jobs");
    }

    const hasCategory =
      (user.categories && user.categories.includes(job.category)) ||
      user.primaryCategory === job.category;
    if (!hasCategory) {
      throw new Error("This job category does not match your profile");
    }

    let distanceKm = 0;
    if (!isZoneMode) {
      const radiusKm = Math.min(user.radiusKm ?? MAX_RADIUS_KM, MAX_RADIUS_KM);
      distanceKm = Math.round(
        haversineDistanceKm(
          user.latitude!,
          user.longitude!,
          job.latitude,
          job.longitude
        ) * 100
      ) / 100;

      if (distanceKm > radiusKm) {
        throw new Error("Job is outside your search radius");
      }
    }
    
    // BACKUP QUEUE LOGIC
    // First instructor becomes primary, second becomes backup
    const now = Date.now();
    
    if (job.status === "open") {
      // FIRST CLAIM - Primary instructor
      if (!MVP_SKIP_CERTIFICATION && job.requiresVerification && !user.isVerified) {
        throw new Error("This job requires a verified instructor");
      }
      
      // Use Haversine for precise distance
      const claimId = await ctx.db.insert("claims", {
        jobId: args.jobId,
        instructorId: user._id,
        status: "pending",
        distanceKm,
        message: args.message,
        createdAt: now,
      });
      
      await ctx.db.patch(args.jobId, {
        status: "claimed",
        claimedBy: user._id,
        claimedAt: now,
        updatedAt: now,
      });

      // 2026 GEOSPATIAL REMOVE
      await removeJobLocation(ctx, args.jobId);
      
      // Notify studio
      await ctx.scheduler.runAfter(0, internal.notifications.notifyStudioOfClaim, {
        jobId: args.jobId,
        claimId,
      });
      
      return { claimId, role: "primary" };
      
    } else if (job.status === "claimed" && job.claimedBy !== user._id) {
      // SECOND CLAIM - Backup instructor (race condition prevention!)
      // Only allow backup if primary is different user
      
      // Check if already has backup
      if (job.backupClaimedBy) {
        throw new Error("Job already has a backup instructor");
      }
      
      // Verify instructor is eligible
      if (!MVP_SKIP_CERTIFICATION && job.requiresVerification && !user.isVerified) {
        throw new Error("This job requires a verified instructor");
      }
      
      // Create backup claim
      const backupClaimId = await ctx.db.insert("claims", {
        jobId: args.jobId,
        instructorId: user._id,
        status: "pending",
        distanceKm,
        message: args.message,
        createdAt: now,
      });
      
      // Update job with backup
      await ctx.db.patch(args.jobId, {
        status: "backup_claimed",
        backupClaimedBy: user._id,
        backupClaimedAt: now,
        updatedAt: now,
      });
      
      // Notify studio about backup
      await ctx.scheduler.runAfter(0, internal.notifications.notifyStudioOfBackupClaim, {
        jobId: args.jobId,
        backupClaimId,
        primaryInstructorId: job.claimedBy!,
        backupInstructorId: user._id,
      });
      
      return { claimId: backupClaimId, role: "backup" };
      
    } else {
      throw new Error("Job is no longer available");
    }
  },
});

export const withdrawClaim = mutation({
  args: {
    jobId: v.id("jobs"),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user || user.role !== "instructor") {
      throw new Error("Only instructors can withdraw claims");
    }
    
    const job = await ctx.db.get(args.jobId);
    if (!job) throw new Error("Job not found");
    
    // Find the pending claim
    const claim = await ctx.db
      .query("claims")
      .withIndex("by_job_status", (q) => q.eq("jobId", args.jobId).eq("status", "pending"))
      .filter((q) => q.eq(q.field("instructorId"), user._id))
      .first();
    
    if (!claim) throw new Error("No pending claim found to withdraw");
    
    const now = Date.now();
    
    // Mark claim as withdrawn
    await ctx.db.patch(claim._id, {
      status: "withdrawn",
      respondedAt: now,
    });
    
    // Handle withdrawal based on claim type (primary or backup)
    if (job.claimedBy === user._id) {
      // PRIMARY INSTRUCTOR WITHDRAWING
      
      if (job.backupClaimedBy) {
        // AUTO-PROMOTE BACKUP TO PRIMARY! 🎉
        // This is the magic - seamless failover
        await ctx.db.patch(args.jobId, {
          status: "claimed",  // Back to single claim status
          claimedBy: job.backupClaimedBy,
          claimedAt: job.backupClaimedAt,
          backupClaimedBy: undefined,
          backupClaimedAt: undefined,
          backupAutoPromoted: true,
          updatedAt: now,
        });
        
        // Notify the promoted backup
        await ctx.scheduler.runAfter(0, internal.notifications.notifyBackupPromoted, {
          jobId: args.jobId,
          newPrimaryInstructorId: job.backupClaimedBy,
        });
        
        console.log(`[withdrawClaim] Backup ${job.backupClaimedBy} auto-promoted to primary for job ${args.jobId}`);
        
      } else {
        // No backup - job goes back to open
        await ctx.db.patch(args.jobId, {
          status: "open",
          claimedBy: undefined,
          claimedAt: undefined,
          updatedAt: now,
        });

        // 2026 GEOSPATIAL RE-ADD
        await syncJobLocation(
          ctx,
          args.jobId,
          { latitude: job.latitude, longitude: job.longitude },
          job.category,
          "open",
          job.requiresVerification,
          job.currentRate
        );

        await scheduleJobDispatch(ctx, args.jobId);
      }
      
    } else if (job.backupClaimedBy === user._id) {
      // BACKUP INSTRUCTOR WITHDRAWING
      await ctx.db.patch(args.jobId, {
        status: "claimed",  // Back to single claim
        backupClaimedBy: undefined,
        backupClaimedAt: undefined,
        updatedAt: now,
      });
    }
  },
});

export const respondToClaim = mutation({
  args: {
    claimId: v.id("claims"),
    accept: v.boolean(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    const claim = await ctx.db.get(args.claimId);
    if (!claim) throw new Error("Claim not found");
    
    const job = await ctx.db.get(claim.jobId);
    if (!job) throw new Error("Job not found");
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user || user._id !== job.studioId) {
      throw new Error("Only the studio owner can respond to claims");
    }
    
    await applyRespondToClaim(ctx, args.claimId, args.accept);
  },
});

export const respondToClaimInternal = internalMutation({
  args: {
    claimId: v.id("claims"),
    accept: v.boolean(),
  },
  handler: async (ctx, args) => {
    await applyRespondToClaim(ctx, args.claimId, args.accept);
  },
});

export const cancelJob = mutation({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    const job = await ctx.db.get(jobId);
    if (!job) throw new Error("Job not found");
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user || user._id !== job.studioId) {
      throw new Error("Only the studio owner can cancel jobs");
    }
    
    await ctx.db.patch(jobId, {
      status: "cancelled",
      updatedAt: Date.now(),
    });

    // 2026 GEOSPATIAL REMOVE
    await removeJobLocation(ctx, jobId);
    
    // Notify claimed instructor if any
    if (job.claimedBy) {
      await ctx.scheduler.runAfter(0, internal.notifications.notifyJobCancelled, {
        jobId,
        instructorId: job.claimedBy,
      });
    }
  },
});

async function applyRespondToClaim(
  ctx: { db: any; scheduler: any },
  claimId: any,
  accept: boolean
) {
  const claim = await ctx.db.get(claimId);
  if (!claim) throw new Error("Claim not found");

  const job = await ctx.db.get(claim.jobId);
  if (!job) throw new Error("Job not found");

  const now = Date.now();

  if (accept) {
    await ctx.db.patch(claimId, {
      status: "accepted",
      respondedAt: now,
    });

    await ctx.db.patch(claim.jobId, {
      status: "confirmed",
      confirmedAt: now,
      updatedAt: now,
      backupClaimedBy: undefined,
      backupClaimedAt: undefined,
      backupAutoPromoted: undefined,
    });

    // Reject any other pending claims (including backup)
    const otherClaims = await ctx.db
      .query("claims")
      .withIndex("by_job", (q: any) => q.eq("jobId", claim.jobId))
      .collect();
    for (const other of otherClaims) {
      if (other._id === claim._id) continue;
      if (other.status !== "pending") continue;
      await ctx.db.patch(other._id, {
        status: "rejected",
        respondedAt: now,
      });
      await ctx.scheduler.runAfter(0, internal.notifications.notifyClaimRejected, {
        claimId: other._id,
      });
    }

    await ctx.scheduler.runAfter(0, internal.notifications.notifyClaimAccepted, {
      claimId,
    });
    return;
  }

  await ctx.db.patch(claimId, {
    status: "rejected",
    respondedAt: now,
  });

  if (job.backupClaimedBy) {
    // Promote backup to primary
    await ctx.db.patch(claim.jobId, {
      status: "claimed",
      claimedBy: job.backupClaimedBy,
      claimedAt: job.backupClaimedAt ?? now,
      backupClaimedBy: undefined,
      backupClaimedAt: undefined,
      backupAutoPromoted: true,
      updatedAt: now,
    });

    await ctx.scheduler.runAfter(0, internal.notifications.notifyBackupPromoted, {
      jobId: claim.jobId,
      newPrimaryInstructorId: job.backupClaimedBy,
    });
  } else {
    await ctx.db.patch(claim.jobId, {
      status: "open",
      claimedBy: undefined,
      claimedAt: undefined,
      updatedAt: now,
    });

    // Re-add job to geospatial index so it appears in searches again
    await syncJobLocation(
      ctx as any, // Cast to MutationCtx for geo component compatibility
      claim.jobId,
      { latitude: job.latitude, longitude: job.longitude },
      job.category,
      "open",
      job.requiresVerification,
      job.currentRate
    );

    await scheduleJobDispatch(ctx, claim.jobId);
  }

  await ctx.scheduler.runAfter(0, internal.notifications.notifyClaimRejected, {
    claimId,
  });
}

/**
 * Expire stale claims and reopen jobs.
 * Runs on a cron (see convex/crons.ts).
 */
export const expireStaleClaims = internalMutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    const cutoff = now - CLAIM_RESPONSE_TIMEOUT_MS;

    let expiredCount = 0;
    const statuses: Array<"claimed" | "backup_claimed"> = ["claimed", "backup_claimed"];

    for (const status of statuses) {
      const staleJobs = await ctx.db
        .query("jobs")
        .withIndex("by_status", (q) => q.eq("status", status))
        .filter((q) => q.lt(q.field("claimedAt"), cutoff))
        .collect();

      for (const job of staleJobs) {
        const current = await ctx.db.get(job._id);
        if (!current) continue;
        if (
          current.status !== status ||
          !current.claimedAt ||
          current.claimedAt >= cutoff
        ) {
          continue;
        }

        await ctx.db.patch(current._id, {
          status: "open",
          claimedBy: undefined,
          claimedAt: undefined,
          backupClaimedBy: undefined,
          backupClaimedAt: undefined,
          backupAutoPromoted: undefined,
          updatedAt: now,
        });

        // Re-add job to geospatial index so it appears in searches again
        await syncJobLocation(
          ctx,
          current._id,
          { latitude: current.latitude, longitude: current.longitude },
          current.category,
          "open",
          current.requiresVerification,
          current.currentRate
        );

        await scheduleJobDispatch(ctx, current._id);

        // Reject any pending claims for this job
        const pendingClaims = await ctx.db
          .query("claims")
          .withIndex("by_job_status", (q) =>
            q.eq("jobId", current._id).eq("status", "pending")
          )
          .collect();
        for (const claim of pendingClaims) {
          await ctx.db.patch(claim._id, {
            status: "rejected",
            respondedAt: now,
          });
        }

        expiredCount++;
      }
    }

    return { expiredCount };
  },
});

export const scheduleDispatchRetry = internalMutation({
  args: {
    jobId: v.id("jobs"),
    dispatchVersion: v.number(),
    error: v.optional(v.string()),
  },
  handler: async (ctx, { jobId, dispatchVersion, error }) => {
    const job = await ctx.db.get(jobId);
    if (!job) return { scheduled: false, reason: "missing" };
    if (job.status !== "open") return { scheduled: false, reason: "not_open" };
    if ((job.dispatchVersion ?? 0) !== dispatchVersion) {
      return { scheduled: false, reason: "stale_version" };
    }
    if (job.notificationsSent) {
      return { scheduled: false, reason: "already_notified" };
    }

    const attempt = (job.dispatchAttempt ?? 0) + 1;
    if (attempt > DISPATCH_MAX_RETRIES) {
      await ctx.db.patch(jobId, {
        dispatchLastError: error ?? "dispatch_retry_exhausted",
        updatedAt: Date.now(),
      });
      return { scheduled: false, reason: "max_retries" };
    }

    const delay = Math.min(
      DISPATCH_BASE_DELAY_MS * Math.pow(2, attempt - 1),
      DISPATCH_MAX_DELAY_MS
    );
    const now = Date.now();

    await ctx.db.patch(jobId, {
      dispatchAttempt: attempt,
      dispatchLastError: error,
      dispatchScheduledAt: now + delay,
      updatedAt: now,
    });

    await ctx.scheduler.runAfter(delay, internal.notifications.dispatchJobNotifications, {
      jobId,
      dispatchVersion,
    });

    return { scheduled: true, attempt, delay };
  },
});

export const markNotified = internalMutation({
  args: {
    jobId: v.id("jobs"),
    instructorIds: v.array(v.id("users")),
  },
  handler: async (ctx, { jobId, instructorIds }) => {
    await ctx.db.patch(jobId, {
      notificationsSent: true,
      notifiedInstructors: instructorIds,
      updatedAt: Date.now(),
    });
  },
});
