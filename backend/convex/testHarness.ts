// convex/testHarness.ts
// Test harness for end-to-end job flow (post -> notify -> claim -> accept)

import { action, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import {
  syncInstructorLocation,
  syncJobLocation,
  removeInstructorLocation,
  removeJobLocation,
  haversineDistanceKm,
} from "./geo";

const DEFAULT_RADIUS_KM = 5;

function nowPlusMinutes(mins: number) {
  return Date.now() + mins * 60 * 1000;
}

export const createTestUser = internalMutation({
  args: {
    role: v.union(v.literal("studio"), v.literal("instructor")),
    name: v.string(),
    email: v.string(),
    categories: v.array(v.string()),
    latitude: v.number(),
    longitude: v.number(),
    radiusKm: v.optional(v.number()),
    dispatchMode: v.optional(v.union(v.literal("radius"), v.literal("zone"))),
  },
  handler: async (ctx, args) => {
    const dispatchMode = args.dispatchMode ?? "radius";
    const userId = await ctx.db.insert("users", {
      firebaseUid: `test_${args.role}_${Date.now()}_${Math.random().toString(36).slice(2)}`,
      email: args.email,
      name: args.name,
      role: args.role,
      hasCompletedOnboarding: true,
      isVerified: true,
      categories: args.categories,
      primaryCategory: args.categories[0] ?? "general",
      dispatchMode: args.role === "instructor" ? dispatchMode : undefined,
      radiusKm: args.radiusKm ?? DEFAULT_RADIUS_KM,
      latitude: args.latitude,
      longitude: args.longitude,
      notificationsEnabled: true,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    if (args.role === "instructor") {
      await syncInstructorLocation(
        ctx,
        userId,
        { latitude: args.latitude, longitude: args.longitude },
        dispatchMode,
        args.categories,
        true,
        true,
        args.radiusKm ?? DEFAULT_RADIUS_KM
      );
    }

    return userId;
  },
});

export const createTestJob = internalMutation({
  args: {
    studioId: v.id("users"),
    title: v.string(),
    category: v.string(),
    latitude: v.number(),
    longitude: v.number(),
    address: v.string(),
    baseRate: v.number(),
  },
  handler: async (ctx, args) => {
    const startTime = nowPlusMinutes(60);
    const endTime = nowPlusMinutes(120);
    const durationMinutes = 60;

    const jobId = await ctx.db.insert("jobs", {
      studioId: args.studioId,
      title: args.title,
      description: "Test job",
      category: args.category,
      startTime,
      endTime,
      durationMinutes,
      baseRate: args.baseRate,
      currentRate: args.baseRate,
      sosBoostApplied: false,
      latitude: args.latitude,
      longitude: args.longitude,
      address: args.address,
      status: "open",
      requiresVerification: false,
      notificationsSent: false,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await syncJobLocation(
      ctx,
      jobId,
      { latitude: args.latitude, longitude: args.longitude },
      args.category,
      "open",
      false,
      args.baseRate
    );

    return jobId;
  },
});

export const claimJobAs = internalMutation({
  args: { jobId: v.id("jobs"), instructorId: v.id("users") },
  handler: async (ctx, { jobId, instructorId }) => {
    const job = await ctx.db.get(jobId);
    if (!job) throw new Error("Job not found");

    const instructor = await ctx.db.get(instructorId);
    if (!instructor) throw new Error("Instructor not found");

    const distanceKm = haversineDistanceKm(
      instructor.latitude ?? 0,
      instructor.longitude ?? 0,
      job.latitude,
      job.longitude
    );
    const now = Date.now();

    if (job.status === "open") {
      const claimId = await ctx.db.insert("claims", {
        jobId,
        instructorId,
        status: "pending",
        distanceKm,
        createdAt: now,
      });

      await ctx.db.patch(jobId, {
        status: "claimed",
        claimedBy: instructorId,
        claimedAt: now,
        updatedAt: now,
      });

      // Remove from geo index while claimed
      await removeJobLocation(ctx, jobId);

      return claimId;
    }

    if (job.status === "claimed" && job.claimedBy !== instructorId && !job.backupClaimedBy) {
      const claimId = await ctx.db.insert("claims", {
        jobId,
        instructorId,
        status: "pending",
        distanceKm,
        createdAt: now,
      });

      await ctx.db.patch(jobId, {
        status: "backup_claimed",
        backupClaimedBy: instructorId,
        backupClaimedAt: now,
        updatedAt: now,
      });

      return claimId;
    }

    throw new Error("Job is not open");
  },
});

export const respondToClaimAs = internalMutation({
  args: {
    claimId: v.id("claims"),
    accept: v.boolean(),
  },
  handler: async (ctx, { claimId, accept }) => {
    const claim = await ctx.db.get(claimId);
    if (!claim) throw new Error("Claim not found");
    const job = await ctx.db.get(claim.jobId);
    if (!job) throw new Error("Job not found");

    if (accept) {
      await ctx.db.patch(claimId, {
        status: "accepted",
        respondedAt: Date.now(),
      });
      await ctx.db.patch(job._id, {
        status: "confirmed",
        confirmedAt: Date.now(),
        updatedAt: Date.now(),
      });
    } else {
      await ctx.db.patch(claimId, {
        status: "rejected",
        respondedAt: Date.now(),
      });
      await ctx.db.patch(job._id, {
        status: "open",
        claimedBy: undefined,
        claimedAt: undefined,
        updatedAt: Date.now(),
      });

      await syncJobLocation(
        ctx,
        job._id,
        { latitude: job.latitude, longitude: job.longitude },
        job.category,
        "open",
        job.requiresVerification,
        job.currentRate
      );
    }
  },
});

export const cleanupTestData = internalMutation({
  args: {
    jobId: v.id("jobs"),
    claimId: v.id("claims"),
    instructorId: v.id("users"),
    studioId: v.id("users"),
  },
  handler: async (ctx, args) => {
    await removeJobLocation(ctx, args.jobId);
    await removeInstructorLocation(ctx, args.instructorId);
    await ctx.db.delete(args.claimId);
    await ctx.db.delete(args.jobId);
    await ctx.db.delete(args.instructorId);
    await ctx.db.delete(args.studioId);

    const logs = await ctx.db
      .query("notificationLogs")
      .withIndex("by_job", (q) => q.eq("jobId", args.jobId))
      .collect();
    for (const log of logs) {
      await ctx.db.delete(log._id);
    }
  },
});

export const cleanupTestJob = internalMutation({
  args: {
    jobId: v.id("jobs"),
    claimIds: v.array(v.id("claims")),
  },
  handler: async (ctx, args) => {
    await removeJobLocation(ctx, args.jobId);
    for (const claimId of args.claimIds) {
      await ctx.db.delete(claimId);
    }
    await ctx.db.delete(args.jobId);

    const logs = await ctx.db
      .query("notificationLogs")
      .withIndex("by_job", (q) => q.eq("jobId", args.jobId))
      .collect();
    for (const log of logs) {
      await ctx.db.delete(log._id);
    }
  },
});

export const cleanupTestUser = internalMutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, { userId }) => {
    await removeInstructorLocation(ctx, userId);
    await ctx.db.delete(userId);
  },
});

export const backdateClaim = internalMutation({
  args: {
    jobId: v.id("jobs"),
    minutesAgo: v.number(),
  },
  handler: async (ctx, { jobId, minutesAgo }) => {
    const job = await ctx.db.get(jobId);
    if (!job) throw new Error("Job not found");
    if (!job.claimedAt) throw new Error("Job is not claimed");
    const backdated = Date.now() - minutesAgo * 60 * 1000;
    await ctx.db.patch(jobId, {
      claimedAt: backdated,
      updatedAt: Date.now(),
    });
  },
});

export const runTestSuite = action({
  args: {
    token: v.string(),
    cleanup: v.optional(v.boolean()),
  },
  handler: async (ctx, { token, cleanup }): Promise<{
    studioId: Id<"users">;
    instructorId: Id<"users">;
    backupInstructorId: Id<"users">;
    jobId: Id<"jobs">;
    claimId: Id<"claims">;
    matchCount: number;
    mismatchCount: number;
    jobStatus: string | undefined;
    notificationsSent: boolean | undefined;
    staleJobStatus: string | undefined;
    backupJobStatus: string | undefined;
    backupPromoted: boolean;
    redispatchStatus: string | undefined;
    redispatchNotificationsSent: boolean | undefined;
  }> => {
    const expected = process.env.TEST_HARNESS_TOKEN;
    if (!expected || token !== expected) {
      throw new Error("Unauthorized test harness call");
    }

    const studioId = await ctx.runMutation(internal.testHarness.createTestUser, {
      role: "studio",
      name: "Test Studio",
      email: "studio@test.local",
      categories: ["pilates"],
      latitude: 32.0853,
      longitude: 34.7818,
    });

    const instructorId = await ctx.runMutation(internal.testHarness.createTestUser, {
      role: "instructor",
      name: "Test Instructor",
      email: "instructor@test.local",
      categories: ["pilates"],
      latitude: 32.0865,
      longitude: 34.7825,
      radiusKm: 5,
    });
    const backupInstructorId = await ctx.runMutation(internal.testHarness.createTestUser, {
      role: "instructor",
      name: "Backup Instructor",
      email: "backup@test.local",
      categories: ["pilates"],
      latitude: 32.0866,
      longitude: 34.7826,
      radiusKm: 5,
    });

    const jobId = await ctx.runMutation(internal.testHarness.createTestJob, {
      studioId,
      title: "Test Pilates Class",
      category: "pilates",
      latitude: 32.0858,
      longitude: 34.7820,
      address: "Tel Aviv",
      baseRate: 200,
    });

    const matches = await ctx.runQuery(internal.geo.findInstructorsForJobQuery, {
      jobPoint: { latitude: 32.0858, longitude: 34.7820 },
      jobCategory: "pilates",
      requiresVerification: false,
    });
    const mismatched = await ctx.runQuery(internal.geo.findInstructorsForJobQuery, {
      jobPoint: { latitude: 32.0858, longitude: 34.7820 },
      jobCategory: "yoga",
      requiresVerification: false,
    });

    await ctx.runAction(internal.notifications.dispatchJobNotifications, { jobId });

    const claimId = await ctx.runMutation(internal.testHarness.claimJobAs, {
      jobId,
      instructorId,
    });

    await ctx.runMutation(internal.testHarness.respondToClaimAs, {
      claimId,
      accept: true,
    });

    const job = await ctx.runQuery(internal.jobs.getJobInternal, { jobId });

    // Expiry flow test (stale claim)
    const staleJobId = await ctx.runMutation(internal.testHarness.createTestJob, {
      studioId,
      title: "Stale Claim Pilates",
      category: "pilates",
      latitude: 32.0858,
      longitude: 34.7820,
      address: "Tel Aviv",
      baseRate: 180,
    });
    const staleClaimId = await ctx.runMutation(internal.testHarness.claimJobAs, {
      jobId: staleJobId,
      instructorId,
    });
    await ctx.runMutation(internal.testHarness.backdateClaim, {
      jobId: staleJobId,
      minutesAgo: 5,
    });
    await ctx.runMutation(internal.jobs.expireStaleClaims, {});
    const staleJob = await ctx.runQuery(internal.jobs.getJobInternal, { jobId: staleJobId });

    // Backup promotion flow
    const backupJobId = await ctx.runMutation(internal.testHarness.createTestJob, {
      studioId,
      title: "Backup Pilates Class",
      category: "pilates",
      latitude: 32.0859,
      longitude: 34.7821,
      address: "Tel Aviv",
      baseRate: 190,
    });
    const primaryClaimId = await ctx.runMutation(internal.testHarness.claimJobAs, {
      jobId: backupJobId,
      instructorId,
    });
    const backupClaimId = await ctx.runMutation(internal.testHarness.claimJobAs, {
      jobId: backupJobId,
      instructorId: backupInstructorId,
    });
    await ctx.runMutation(internal.jobs.respondToClaimInternal, {
      claimId: primaryClaimId,
      accept: false,
    });
    const backupJob = await ctx.runQuery(internal.jobs.getJobInternal, { jobId: backupJobId });

    // Re-dispatch after rejection (no backup)
    const redispatchJobId = await ctx.runMutation(internal.testHarness.createTestJob, {
      studioId,
      title: "Redispatch Pilates",
      category: "pilates",
      latitude: 32.0857,
      longitude: 34.7822,
      address: "Tel Aviv",
      baseRate: 175,
    });
    await ctx.runAction(internal.notifications.dispatchJobNotifications, { jobId: redispatchJobId });
    const redispatchClaimId = await ctx.runMutation(internal.testHarness.claimJobAs, {
      jobId: redispatchJobId,
      instructorId,
    });
    await ctx.runMutation(internal.jobs.respondToClaimInternal, {
      claimId: redispatchClaimId,
      accept: false,
    });
    await ctx.runAction(internal.notifications.dispatchJobNotifications, { jobId: redispatchJobId });
    const redispatchJob = await ctx.runQuery(internal.jobs.getJobInternal, { jobId: redispatchJobId });

    const result = {
      studioId,
      instructorId,
      backupInstructorId,
      jobId,
      claimId,
      matchCount: matches.length,
      mismatchCount: mismatched.length,
      jobStatus: job?.status,
      notificationsSent: job?.notificationsSent,
      staleJobStatus: staleJob?.status,
      backupJobStatus: backupJob?.status,
      backupPromoted: backupJob?.claimedBy === backupInstructorId && backupJob?.status === "claimed",
      redispatchStatus: redispatchJob?.status,
      redispatchNotificationsSent: redispatchJob?.notificationsSent,
    };

    if (cleanup) {
      await ctx.runMutation(internal.testHarness.cleanupTestJob, {
        jobId: staleJobId,
        claimIds: [staleClaimId],
      });
      await ctx.runMutation(internal.testHarness.cleanupTestJob, {
        jobId: backupJobId,
        claimIds: [primaryClaimId, backupClaimId],
      });
      await ctx.runMutation(internal.testHarness.cleanupTestJob, {
        jobId: redispatchJobId,
        claimIds: [redispatchClaimId],
      });
      await ctx.runMutation(internal.testHarness.cleanupTestData, {
        jobId,
        claimId,
        instructorId,
        studioId,
      });
      await ctx.runMutation(internal.testHarness.cleanupTestUser, {
        userId: backupInstructorId,
      });
    }

    return result;
  },
});
