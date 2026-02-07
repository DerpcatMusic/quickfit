// convex/jobs.ts
// Job queries and mutations

import { query, mutation, internalQuery, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { 
  haversineDistanceMeters, 
  haversineDistanceKm,
  isWithinRadius,
  findJobsForInstructor,
  syncJobLocation,
  removeJobLocation,
} from "./geo";
import { latLngToHex11 } from "./h3";

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
    const activeClaim = await ctx.db
      .query("claims")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .filter((q) => q.eq(q.field("instructorId"), job.claimedBy))
      .first();

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
  args: { limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user || user.role !== "instructor") return [];
    if (!user.latitude || !user.longitude || !user.radiusKm) return [];
    
    // 2026 GEOSPATIAL SEARCH
    const jobResults = await findJobsForInstructor(
      ctx,
      { latitude: user.latitude, longitude: user.longitude },
      user.radiusKm,
      user.categories || ["general"],
      user.isVerified
    );
    
    // Sort by SOS first (manually sorting the enriched results later if needed)
    // For now, these results are already distance-sorted.
    const limitedResults = jobResults.slice(0, args.limit ?? 50);
    
    // Enrichment: Add studio info to enriched results from geo.ts
    const enrichedJobs = await Promise.all(
      limitedResults.map(async (match) => {
        // match already has most fields from findJobsForInstructor
        const studio = await ctx.db.get(match._id as any); // Double narrowing check
        
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
    
    const radiusKm = user.radiusKm ?? 5;
    
    // 2026 GEOSPATIAL SEARCH
    const jobResults = await findJobsForInstructor(
      ctx,
      { latitude: user.latitude, longitude: user.longitude },
      radiusKm,
      user.categories || ["general"],
      user.isVerified
    );
    
    return {
      jobs: jobResults,
      userLocation: { latitude: user.latitude, longitude: user.longitude },
    };
  },
});

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
  handler: async (ctx, args) => {
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
    
    // H3 HEX SPATIAL INDEXING
    const locationHex11 = latLngToHex11(args.latitude, args.longitude);
    
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
      locationHex11,  // H3 hex for O(1) matching
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
    
    // Schedule notification dispatch
    await ctx.scheduler.runAfter(0, internal.notifications.dispatchJobNotifications, {
      jobId,
    });
    
    return jobId;
  },
});

// ==========================================
// CONFIGURATION
// ==========================================
const MVP_SKIP_CERTIFICATION = true; // Set to true to allow non-verified instructors for MVP

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
    
    // BACKUP QUEUE LOGIC
    // First instructor becomes primary, second becomes backup
    const now = Date.now();
    
    if (job.status === "open") {
      // FIRST CLAIM - Primary instructor
      if (!MVP_SKIP_CERTIFICATION && job.requiresVerification && !user.isVerified) {
        throw new Error("This job requires a verified instructor");
      }
      
      // Use Haversine for precise distance
      const distanceKm = user.latitude && user.longitude
        ? Math.round(haversineDistanceKm(
            user.latitude,
            user.longitude,
            job.latitude,
            job.longitude
          ) * 100) / 100
        : 0;
      
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
      
      const distanceKm = user.latitude && user.longitude
        ? Math.round(haversineDistanceKm(
            user.latitude,
            user.longitude,
            job.latitude,
            job.longitude
          ) * 100) / 100
        : 0;
      
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
    
    const now = Date.now();
    
    if (args.accept) {
      await ctx.db.patch(args.claimId, {
        status: "accepted",
        respondedAt: now,
      });
      
      await ctx.db.patch(claim.jobId, {
        status: "confirmed",
        confirmedAt: now,
        updatedAt: now,
      });
      
      await ctx.scheduler.runAfter(0, internal.notifications.notifyClaimAccepted, {
        claimId: args.claimId,
      });
    } else {
      await ctx.db.patch(args.claimId, {
        status: "rejected",
        respondedAt: now,
      });
      
      await ctx.db.patch(claim.jobId, {
        status: "open",
        claimedBy: undefined,
        claimedAt: undefined,
        updatedAt: now,
      });
      
      await ctx.scheduler.runAfter(0, internal.notifications.notifyClaimRejected, {
        claimId: args.claimId,
      });
    }
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
