// convex/testHarness.ts
// Test harness for end-to-end job flow (post -> notify -> claim -> accept)

import { action, internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { api, internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import {
  syncInstructorLocation,
  syncJobLocation,
  removeInstructorLocation,
  removeJobLocation,
  haversineDistanceKm,
} from "./geo";
import { syncJobReadModels } from "./jobReadModels";

const DEFAULT_RADIUS_KM = 5;

function nowPlusMinutes(mins: number) {
  return Date.now() + mins * 60 * 1000;
}

function sleep(ms: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
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
    isVerified: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const dispatchMode = args.dispatchMode ?? "radius";
    const userId = await ctx.db.insert("users", {
      firebaseUid: `test_${args.role}_${Date.now()}_${Math.random().toString(36).slice(2)}`,
      email: args.email,
      name: args.name,
      role: args.role,
      hasCompletedOnboarding: true,
      isVerified: args.isVerified ?? true,
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
      args.isVerified ?? true,
      true,
      args.radiusKm ?? DEFAULT_RADIUS_KM,
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
    startTimeMs: v.optional(v.number()),
    endTimeMs: v.optional(v.number()),
    status: v.optional(
      v.union(
        v.literal("open"),
        v.literal("claimed"),
        v.literal("backup_claimed"),
        v.literal("confirmed"),
        v.literal("completed"),
        v.literal("cancelled"),
      ),
    ),
    requiresVerification: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const startTime = args.startTimeMs ?? nowPlusMinutes(60);
    const endTime = args.endTimeMs ?? startTime + 60 * 60 * 1000;
    const durationMinutes = Math.max(
      1,
      Math.round((endTime - startTime) / (60 * 1000)),
    );
    const status = args.status ?? "open";
    const now = Date.now();

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
      status,
      requiresVerification: args.requiresVerification ?? false,
      notificationsSent: false,
      createdAt: now,
      updatedAt: now,
    });

    if (status === "open") {
      await syncJobLocation(
        ctx,
        jobId,
        { latitude: args.latitude, longitude: args.longitude },
        args.category,
        "open",
        args.requiresVerification ?? false,
        args.baseRate,
      );
    }
    await syncJobReadModels(ctx as any, jobId);

    return jobId;
  },
});

export const getJobProjectionState = internalQuery({
  args: {
    jobId: v.id("jobs"),
  },
  handler: async (ctx, { jobId }) => {
    const studioProjection = await ctx.db
      .query("readModel_studioJobs")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .first();
    const instructorProjection = await ctx.db
      .query("readModel_instructorFeed")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .first();

    return {
      studioProjectionExists: Boolean(studioProjection),
      studioStatus: studioProjection?.status,
      studioClaimId: studioProjection?.claimId,
      instructorProjectionExists: Boolean(instructorProjection),
      instructorStatus: instructorProjection?.status,
    };
  },
});

export const dropStudioProjectionForJob = internalMutation({
  args: {
    jobId: v.id("jobs"),
  },
  handler: async (ctx, { jobId }) => {
    const studioProjection = await ctx.db
      .query("readModel_studioJobs")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .first();
    if (studioProjection) {
      await ctx.db.delete(studioProjection._id);
    }
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
      job.longitude,
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
      await syncJobReadModels(ctx as any, jobId);

      return claimId;
    }

    if (
      job.status === "claimed" &&
      job.claimedBy !== instructorId &&
      !job.backupClaimedBy
    ) {
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
      await syncJobReadModels(ctx as any, jobId);

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
      await syncJobReadModels(ctx as any, job._id);
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
        job.currentRate,
      );
      await syncJobReadModels(ctx as any, job._id);
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

export const backdateJobWindow = internalMutation({
  args: {
    jobId: v.id("jobs"),
    startTimeMs: v.number(),
    endTimeMs: v.number(),
  },
  handler: async (ctx, { jobId, startTimeMs, endTimeMs }) => {
    const durationMinutes = Math.max(
      1,
      Math.round((endTimeMs - startTimeMs) / (60 * 1000)),
    );
    await ctx.db.patch(jobId, {
      startTime: startTimeMs,
      endTime: endTimeMs,
      durationMinutes,
      updatedAt: Date.now(),
    });
  },
});

export const runTestSuite = action({
  args: {
    token: v.string(),
    cleanup: v.optional(v.boolean()),
  },
  handler: async (
    ctx,
    { token, cleanup },
  ): Promise<{
    studioId: Id<"users">;
    instructorId: Id<"users">;
    backupInstructorId: Id<"users">;
    jobId: Id<"jobs">;
    claimId: Id<"claims">;
    matchCount: number;
    mismatchCount: number;
    jobStatus: string | undefined;
    completedJobStatus: string | undefined;
    notificationsSent: boolean | undefined;
    staleJobStatus: string | undefined;
    backupJobStatus: string | undefined;
    backupPromoted: boolean;
    backupClaimStatus: string | undefined;
    rejectDoubleRespondBlocked: boolean;
    redispatchStatus: string | undefined;
    redispatchNotificationsSent: boolean | undefined;
    cancelledJobStatus: string | undefined;
    cancelledAcceptedClaimReconciled: boolean;
    idempotentClaimDedupeWorked: boolean;
    idempotentWithdrawReplaySafe: boolean;
    claimsWindowFilterAndOrderCorrect: boolean;
    studioJobsPriorityOrderingCorrect: boolean;
    studioInstructorVisibilityRealtimeCorrect: boolean;
    postingVisibilityForUnverifiedCorrect: boolean;
    readModelProjectionConsistencyCorrect: boolean;
    centralizedMyJobsQueryConsistent: boolean;
    studioJobsCanonicalFallbackCorrect: boolean;
  }> => {
    const expected = process.env.TEST_HARNESS_TOKEN;
    if (!expected || token !== expected) {
      throw new Error("Unauthorized test harness call");
    }

    const studioId = await ctx.runMutation(
      internal.testHarness.createTestUser,
      {
        role: "studio",
        name: "Test Studio",
        email: "studio@test.local",
        categories: ["pilates"],
        latitude: 32.0853,
        longitude: 34.7818,
      },
    );

    const instructorId = await ctx.runMutation(
      internal.testHarness.createTestUser,
      {
        role: "instructor",
        name: "Test Instructor",
        email: "instructor@test.local",
        categories: ["pilates"],
        latitude: 32.0865,
        longitude: 34.7825,
        radiusKm: 5,
      },
    );
    const backupInstructorId = await ctx.runMutation(
      internal.testHarness.createTestUser,
      {
        role: "instructor",
        name: "Backup Instructor",
        email: "backup@test.local",
        categories: ["pilates"],
        latitude: 32.0866,
        longitude: 34.7826,
        radiusKm: 5,
      },
    );
    const unverifiedInstructorId = await ctx.runMutation(
      internal.testHarness.createTestUser,
      {
        role: "instructor",
        name: "Unverified Instructor",
        email: "unverified@test.local",
        categories: ["pilates"],
        latitude: 32.0867,
        longitude: 34.7827,
        radiusKm: 5,
        isVerified: false,
      },
    );

    const visibilityPublicJobId = await ctx.runMutation(
      internal.testHarness.createTestJob,
      {
        studioId,
        title: "Visibility Public Pilates",
        category: "pilates",
        latitude: 32.0859,
        longitude: 34.7821,
        address: "Tel Aviv",
        baseRate: 175,
        startTimeMs: Date.now() + 3 * 60 * 60 * 1000,
        endTimeMs: Date.now() + 4 * 60 * 60 * 1000,
        requiresVerification: false,
      },
    );
    const visibilityVerifiedOnlyJobId = await ctx.runMutation(
      internal.testHarness.createTestJob,
      {
        studioId,
        title: "Visibility Verified Pilates",
        category: "pilates",
        latitude: 32.086,
        longitude: 34.7822,
        address: "Tel Aviv",
        baseRate: 180,
        startTimeMs: Date.now() + 5 * 60 * 60 * 1000,
        endTimeMs: Date.now() + 6 * 60 * 60 * 1000,
        requiresVerification: true,
      },
    );

    const unverifiedNearbyJobs = await ctx.runQuery(
      api.geo.getNearbyJobsForInstructor,
      {
        latitude: "32.0867",
        longitude: "34.7827",
        radiusKm: "5",
        categories: "pilates",
        isVerified: "false",
      },
    );
    const unverifiedNearbyJobIds = new Set(
      (unverifiedNearbyJobs as Array<{ _id: Id<"jobs"> }>).map((job) => job._id),
    );
    const postingVisibilityForUnverifiedCorrect =
      unverifiedNearbyJobIds.has(visibilityPublicJobId) &&
      !unverifiedNearbyJobIds.has(visibilityVerifiedOnlyJobId);

    const publicProjection = await ctx.runQuery(
      internal.testHarness.getJobProjectionState,
      {
        jobId: visibilityPublicJobId,
      },
    );
    const verifiedOnlyProjection = await ctx.runQuery(
      internal.testHarness.getJobProjectionState,
      {
        jobId: visibilityVerifiedOnlyJobId,
      },
    );
    let readModelProjectionConsistencyCorrect =
      publicProjection.studioProjectionExists &&
      publicProjection.instructorProjectionExists &&
      verifiedOnlyProjection.studioProjectionExists &&
      verifiedOnlyProjection.instructorProjectionExists;

    const jobId = await ctx.runMutation(internal.testHarness.createTestJob, {
      studioId,
      title: "Test Pilates Class",
      category: "pilates",
      latitude: 32.0858,
      longitude: 34.782,
      address: "Tel Aviv",
      baseRate: 200,
    });

    const matches = await ctx.runQuery(
      internal.geo.findInstructorsForJobQuery,
      {
        jobPoint: { latitude: 32.0858, longitude: 34.782 },
        jobCategory: "pilates",
        requiresVerification: false,
      },
    );
    const mismatched = await ctx.runQuery(
      internal.geo.findInstructorsForJobQuery,
      {
        jobPoint: { latitude: 32.0858, longitude: 34.782 },
        jobCategory: "yoga",
        requiresVerification: false,
      },
    );

    await ctx.runAction(internal.notifications.dispatchJobNotifications, {
      jobId,
    });

    const claimId = await ctx.runMutation(internal.testHarness.claimJobAs, {
      jobId,
      instructorId,
    });

    await ctx.runMutation(internal.testHarness.respondToClaimAs, {
      claimId,
      accept: true,
    });

    await ctx.runMutation(internal.testHarness.backdateJobWindow, {
      jobId,
      startTimeMs: Date.now() - 2 * 60 * 60 * 1000,
      endTimeMs: Date.now() - 60 * 60 * 1000,
    });

    const job = await ctx.runQuery(internal.jobs.getJobInternal, { jobId });
    await ctx.runMutation(internal.jobs.completeJobInternalByStudio, {
      jobId,
      studioId,
    });
    const completedJob = await ctx.runQuery(internal.jobs.getJobInternal, {
      jobId,
    });

    // Expiry flow test (stale claim)
    const staleJobId = await ctx.runMutation(
      internal.testHarness.createTestJob,
      {
        studioId,
        title: "Stale Claim Pilates",
        category: "pilates",
        latitude: 32.0858,
        longitude: 34.782,
        address: "Tel Aviv",
        baseRate: 180,
      },
    );
    const staleClaimId = await ctx.runMutation(
      internal.testHarness.claimJobAs,
      {
        jobId: staleJobId,
        instructorId,
      },
    );
    await ctx.runMutation(internal.testHarness.backdateClaim, {
      jobId: staleJobId,
      minutesAgo: 5,
    });
    await ctx.runMutation(internal.jobs.expireStaleClaims, {});
    const staleJob = await ctx.runQuery(internal.jobs.getJobInternal, {
      jobId: staleJobId,
    });

    // Backup promotion flow
    const backupJobId = await ctx.runMutation(
      internal.testHarness.createTestJob,
      {
        studioId,
        title: "Backup Pilates Class",
        category: "pilates",
        latitude: 32.0859,
        longitude: 34.7821,
        address: "Tel Aviv",
        baseRate: 190,
      },
    );
    const primaryClaimId = await ctx.runMutation(
      internal.testHarness.claimJobAs,
      {
        jobId: backupJobId,
        instructorId,
      },
    );
    const backupClaimId = await ctx.runMutation(
      internal.testHarness.claimJobAs,
      {
        jobId: backupJobId,
        instructorId: backupInstructorId,
      },
    );
    await ctx.runMutation(internal.jobs.respondToClaimInternal, {
      claimId: primaryClaimId,
      accept: false,
    });
    const backupJob = await ctx.runQuery(internal.jobs.getJobInternal, {
      jobId: backupJobId,
    });
    const backupClaim = await ctx.runQuery(internal.claims.getClaimById, {
      claimId: backupClaimId,
    });
    let rejectDoubleRespondBlocked = false;
    try {
      await ctx.runMutation(internal.jobs.respondToClaimInternal, {
        claimId: primaryClaimId,
        accept: true,
      });
    } catch {
      rejectDoubleRespondBlocked = true;
    }

    // Re-dispatch after rejection (no backup)
    const redispatchJobId = await ctx.runMutation(
      internal.testHarness.createTestJob,
      {
        studioId,
        title: "Redispatch Pilates",
        category: "pilates",
        latitude: 32.0857,
        longitude: 34.7822,
        address: "Tel Aviv",
        baseRate: 175,
      },
    );
    await ctx.runAction(internal.notifications.dispatchJobNotifications, {
      jobId: redispatchJobId,
    });
    const redispatchClaimId = await ctx.runMutation(
      internal.testHarness.claimJobAs,
      {
        jobId: redispatchJobId,
        instructorId,
      },
    );
    await ctx.runMutation(internal.jobs.respondToClaimInternal, {
      claimId: redispatchClaimId,
      accept: false,
    });
    await ctx.runAction(internal.notifications.dispatchJobNotifications, {
      jobId: redispatchJobId,
    });
    const redispatchJob = await ctx.runQuery(internal.jobs.getJobInternal, {
      jobId: redispatchJobId,
    });

    // Cancel flow reconciliation (accepted claim should no longer remain accepted)
    const cancelledJobId = await ctx.runMutation(
      internal.testHarness.createTestJob,
      {
        studioId,
        title: "Cancelled Accepted Claim",
        category: "pilates",
        latitude: 32.086,
        longitude: 34.7823,
        address: "Tel Aviv",
        baseRate: 210,
      },
    );
    const cancelledAcceptedClaimId = await ctx.runMutation(
      internal.testHarness.claimJobAs,
      {
        jobId: cancelledJobId,
        instructorId,
      },
    );
    await ctx.runMutation(internal.jobs.respondToClaimInternal, {
      claimId: cancelledAcceptedClaimId,
      accept: true,
    });
    await ctx.runMutation(internal.jobs.cancelJobInternalByStudio, {
      jobId: cancelledJobId,
      studioId,
    });
    const cancelledJob = await ctx.runQuery(internal.jobs.getJobInternal, {
      jobId: cancelledJobId,
    });
    const cancelledAcceptedClaim = await ctx.runQuery(
      internal.claims.getClaimById,
      {
        claimId: cancelledAcceptedClaimId,
      },
    );

    // Idempotency replay flow (claim + withdraw)
    const idempotentJobId = await ctx.runMutation(
      internal.testHarness.createTestJob,
      {
        studioId,
        title: "Idempotent Claim Flow",
        category: "pilates",
        latitude: 32.0861,
        longitude: 34.7824,
        address: "Tel Aviv",
        baseRate: 215,
      },
    );
    const idemClaim1 = await ctx.runMutation(
      internal.jobs.claimJobInternalByInstructor,
      {
        jobId: idempotentJobId,
        instructorId,
        idempotencyKey: "idem-claim-key",
      },
    );
    const idemClaim2 = await ctx.runMutation(
      internal.jobs.claimJobInternalByInstructor,
      {
        jobId: idempotentJobId,
        instructorId,
        idempotencyKey: "idem-claim-key",
      },
    );

    await ctx.runMutation(
      internal.jobs.withdrawClaimInternalByJobAndInstructorIdempotent,
      {
        jobId: idempotentJobId,
        instructorId,
        idempotencyKey: "idem-withdraw-key",
      },
    );
    let idempotentWithdrawReplaySafe = true;
    try {
      await ctx.runMutation(
        internal.jobs.withdrawClaimInternalByJobAndInstructorIdempotent,
        {
          jobId: idempotentJobId,
          instructorId,
          idempotencyKey: "idem-withdraw-key",
        },
      );
    } catch {
      idempotentWithdrawReplaySafe = false;
    }
    const idemClaimAfterWithdraw = await ctx.runQuery(
      internal.claims.getClaimById,
      {
        claimId: idemClaim1.claimId,
      },
    );

    // Claims window filter/order coverage for claims:getMyClaims
    const claimsWindowFixtures: Array<{
      jobId: Id<"jobs">;
      claimId: Id<"claims">;
    }> = [];
    const claimWindowBase = Date.now() + 24 * 60 * 60 * 1000;
    const claimWindowStart = claimWindowBase + 30 * 60 * 1000;
    const claimWindowMiddle = claimWindowBase + 60 * 60 * 1000;
    const claimWindowEnd = claimWindowBase + 90 * 60 * 1000;

    const createClaimWindowFixture = async (
      title: string,
      startTimeMs: number,
    ) => {
      const fixtureJobId = await ctx.runMutation(
        internal.testHarness.createTestJob,
        {
          studioId,
          title,
          category: "pilates",
          latitude: 32.0858,
          longitude: 34.782,
          address: "Tel Aviv",
          baseRate: 205,
          startTimeMs,
          endTimeMs: startTimeMs + 60 * 60 * 1000,
        },
      );
      const fixtureClaimId = await ctx.runMutation(
        internal.testHarness.claimJobAs,
        {
          jobId: fixtureJobId,
          instructorId,
        },
      );
      claimsWindowFixtures.push({
        jobId: fixtureJobId,
        claimId: fixtureClaimId,
      });
      return { jobId: fixtureJobId, claimId: fixtureClaimId };
    };

    const beforeWindow = await createClaimWindowFixture(
      "Claims Window Before",
      claimWindowStart - 60 * 1000,
    );
    const atWindowStart = await createClaimWindowFixture(
      "Claims Window Start Boundary",
      claimWindowStart,
    );
    const middleOlder = await createClaimWindowFixture(
      "Claims Window Middle Older",
      claimWindowMiddle,
    );
    await sleep(5);
    const middleNewer = await createClaimWindowFixture(
      "Claims Window Middle Newer",
      claimWindowMiddle,
    );
    const atWindowEnd = await createClaimWindowFixture(
      "Claims Window End Boundary",
      claimWindowEnd,
    );
    const afterWindow = await createClaimWindowFixture(
      "Claims Window After",
      claimWindowEnd + 60 * 1000,
    );

    const claimsInWindow = await ctx.runQuery(
      internal.claims.getClaimsForInstructorInternal,
      {
        instructorId,
        windowStartMs: claimWindowStart,
        windowEndMs: claimWindowEnd,
      },
    );

    const actualWindowOrder = claimsInWindow.map(
      (claim: { _id: Id<"claims"> }) => claim._id,
    );
    const expectedWindowOrder = [
      atWindowStart.claimId,
      middleNewer.claimId,
      middleOlder.claimId,
      atWindowEnd.claimId,
    ];

    const claimsWindowOrderMatches =
      actualWindowOrder.length === expectedWindowOrder.length &&
      expectedWindowOrder.every(
        (claimId, index) => actualWindowOrder[index] === claimId,
      );

    const claimsWindowExcludesOutOfWindow =
      !actualWindowOrder.includes(beforeWindow.claimId) &&
      !actualWindowOrder.includes(afterWindow.claimId);

    const claimsWindowFilterAndOrderCorrect =
      claimsWindowOrderMatches && claimsWindowExcludesOutOfWindow;

    // Studio ordering priority coverage for jobs:getStudioJobs
    const studioOrderingJobIds: Id<"jobs">[] = [];
    const studioOrderBase = Date.now() + 48 * 60 * 60 * 1000;

    const createStudioOrderingJob = async (
      title: string,
      startTimeMs: number,
      status:
        | "open"
        | "claimed"
        | "backup_claimed"
        | "confirmed"
        | "completed"
        | "cancelled",
    ) => {
      const fixtureJobId = await ctx.runMutation(
        internal.testHarness.createTestJob,
        {
          studioId,
          title,
          category: "pilates",
          latitude: 32.0858,
          longitude: 34.782,
          address: "Tel Aviv",
          baseRate: 195,
          startTimeMs,
          endTimeMs: startTimeMs + 60 * 60 * 1000,
          status,
        },
      );
      studioOrderingJobIds.push(fixtureJobId);
      return fixtureJobId;
    };

    const backupClaimedOrderingJobId = await createStudioOrderingJob(
      "Studio Ordering Backup Claimed",
      studioOrderBase + 20 * 60 * 1000,
      "backup_claimed",
    );
    const claimedOrderingJobId = await createStudioOrderingJob(
      "Studio Ordering Claimed",
      studioOrderBase + 30 * 60 * 1000,
      "claimed",
    );
    const openOlderOrderingJobId = await createStudioOrderingJob(
      "Studio Ordering Open Older",
      studioOrderBase + 40 * 60 * 1000,
      "open",
    );
    await sleep(5);
    const openNewerOrderingJobId = await createStudioOrderingJob(
      "Studio Ordering Open Newer",
      studioOrderBase + 40 * 60 * 1000,
      "open",
    );
    const openLaterOrderingJobId = await createStudioOrderingJob(
      "Studio Ordering Open Later",
      studioOrderBase + 50 * 60 * 1000,
      "open",
    );
    const confirmedOrderingJobId = await createStudioOrderingJob(
      "Studio Ordering Confirmed",
      studioOrderBase + 10 * 60 * 1000,
      "confirmed",
    );
    const completedOrderingJobId = await createStudioOrderingJob(
      "Studio Ordering Completed",
      studioOrderBase + 5 * 60 * 1000,
      "completed",
    );
    const cancelledOrderingJobId = await createStudioOrderingJob(
      "Studio Ordering Cancelled",
      studioOrderBase + 1 * 60 * 1000,
      "cancelled",
    );

    const orderedStudioJobs = await ctx.runQuery(
      internal.jobs.getStudioJobsForStudioInternal,
      { studioId },
    );

    const expectedStudioOrder = [
      backupClaimedOrderingJobId,
      claimedOrderingJobId,
      openNewerOrderingJobId,
      openOlderOrderingJobId,
      openLaterOrderingJobId,
      confirmedOrderingJobId,
      completedOrderingJobId,
      cancelledOrderingJobId,
    ];
    const expectedStudioOrderSet = new Set(expectedStudioOrder);
    const actualStudioOrder = orderedStudioJobs
      .filter((job: { _id: Id<"jobs"> }) => expectedStudioOrderSet.has(job._id))
      .map((job: { _id: Id<"jobs"> }) => job._id);

    const studioJobsPriorityOrderingCorrect =
      actualStudioOrder.length === expectedStudioOrder.length &&
      expectedStudioOrder.every(
        (jobId, index) => actualStudioOrder[index] === jobId,
      );

    // Studio -> instructor visibility lifecycle (open -> claimed/pending -> confirmed/accepted)
    const visibilityJobId = await ctx.runMutation(
      internal.testHarness.createTestJob,
      {
        studioId,
        title: "Visibility Realtime Pilates",
        category: "pilates",
        latitude: 32.0856,
        longitude: 34.7819,
        address: "Tel Aviv",
        baseRate: 185,
        startTimeMs: Date.now() + 72 * 60 * 60 * 1000,
        endTimeMs: Date.now() + 73 * 60 * 60 * 1000,
      },
    );

    const openStudioJobsSnapshot = await ctx.runQuery(
      internal.jobs.getStudioJobsForStudioInternal,
      { studioId },
    );
    const openVisibilityJob = openStudioJobsSnapshot.find(
      (listedJob: {
        _id: Id<"jobs">;
        status: string;
        claimId?: Id<"claims">;
      }) => listedJob._id === visibilityJobId,
    );

    const visibilityClaimId = await ctx.runMutation(
      internal.testHarness.claimJobAs,
      {
        jobId: visibilityJobId,
        instructorId,
      },
    );

    const claimedStudioJobsSnapshot = await ctx.runQuery(
      internal.jobs.getStudioJobsForStudioInternal,
      { studioId },
    );
    const claimedVisibilityJob = claimedStudioJobsSnapshot.find(
      (listedJob: {
        _id: Id<"jobs">;
        status: string;
        claimId?: Id<"claims">;
      }) => listedJob._id === visibilityJobId,
    );
    const claimedVisibilityProjection = await ctx.runQuery(
      internal.testHarness.getJobProjectionState,
      { jobId: visibilityJobId },
    );

    const pendingInstructorClaimsSnapshot = await ctx.runQuery(
      internal.claims.getClaimsForInstructorInternal,
      { instructorId },
    );
    const pendingVisibilityClaim = pendingInstructorClaimsSnapshot.find(
      (claim: { jobId: Id<"jobs">; status: string }) =>
        claim.jobId === visibilityJobId,
    );

    await ctx.runMutation(internal.jobs.respondToClaimInternal, {
      claimId: visibilityClaimId,
      accept: true,
    });

    const confirmedStudioJobsSnapshot = await ctx.runQuery(
      internal.jobs.getStudioJobsForStudioInternal,
      { studioId },
    );
    const confirmedVisibilityJob = confirmedStudioJobsSnapshot.find(
      (listedJob: {
        _id: Id<"jobs">;
        status: string;
        claimId?: Id<"claims">;
      }) => listedJob._id === visibilityJobId,
    );
    const confirmedVisibilityProjection = await ctx.runQuery(
      internal.testHarness.getJobProjectionState,
      { jobId: visibilityJobId },
    );

    const acceptedInstructorClaimsSnapshot = await ctx.runQuery(
      internal.claims.getClaimsForInstructorInternal,
      { instructorId },
    );
    const acceptedVisibilityClaim = acceptedInstructorClaimsSnapshot.find(
      (claim: { jobId: Id<"jobs">; status: string }) =>
        claim.jobId === visibilityJobId,
    );

    const studioInstructorVisibilityRealtimeCorrect =
      openVisibilityJob?.status === "open" &&
      claimedVisibilityJob?.status === "claimed" &&
      claimedVisibilityJob?.claimId === visibilityClaimId &&
      confirmedVisibilityJob?.status === "confirmed" &&
      pendingVisibilityClaim?.status === "pending" &&
      acceptedVisibilityClaim?.status === "accepted";

    const canonicalFallbackJobId = await ctx.runMutation(
      internal.testHarness.createTestJob,
      {
        studioId,
        title: "Canonical Fallback Job",
        category: "pilates",
        latitude: 32.0856,
        longitude: 34.7818,
        address: "Tel Aviv",
        baseRate: 170,
        startTimeMs: Date.now() + 96 * 60 * 60 * 1000,
        endTimeMs: Date.now() + 97 * 60 * 60 * 1000,
        status: "open",
      },
    );
    await ctx.runMutation(internal.testHarness.dropStudioProjectionForJob, {
      jobId: canonicalFallbackJobId,
    });
    const canonicalFallbackStudioJobs = await ctx.runQuery(
      internal.jobs.getStudioJobsForStudioInternal,
      { studioId },
    );
    const studioJobsCanonicalFallbackCorrect = canonicalFallbackStudioJobs.some(
      (job: { _id: Id<"jobs"> }) => job._id === canonicalFallbackJobId,
    );

    const studioMyJobsSnapshot = await ctx.runQuery(
      internal.jobs.getMyJobsInternal,
      { userId: studioId },
    );
    const instructorMyJobsSnapshot = await ctx.runQuery(
      internal.jobs.getMyJobsInternal,
      { userId: instructorId },
    );
    const centralizedMyJobsQueryConsistent =
      studioMyJobsSnapshot.role === "studio" &&
      (studioMyJobsSnapshot.studioJobs as Array<{ _id: Id<"jobs"> }>).some(
        (job) => job._id === visibilityJobId,
      ) &&
      instructorMyJobsSnapshot.role === "instructor" &&
      (instructorMyJobsSnapshot.instructorClaims as Array<{
        jobId: Id<"jobs">;
        status: string;
      }>).some(
        (claim) =>
          claim.jobId === visibilityJobId && claim.status === "accepted",
      );
    readModelProjectionConsistencyCorrect =
      readModelProjectionConsistencyCorrect &&
      claimedVisibilityProjection.studioProjectionExists &&
      claimedVisibilityProjection.studioClaimId === visibilityClaimId &&
      !claimedVisibilityProjection.instructorProjectionExists &&
      confirmedVisibilityProjection.studioProjectionExists &&
      confirmedVisibilityProjection.studioStatus === "confirmed" &&
      !confirmedVisibilityProjection.instructorProjectionExists;

    const result = {
      studioId,
      instructorId,
      backupInstructorId,
      jobId,
      claimId,
      matchCount: matches.length,
      mismatchCount: mismatched.length,
      jobStatus: job?.status,
      completedJobStatus: completedJob?.status,
      notificationsSent: job?.notificationsSent,
      staleJobStatus: staleJob?.status,
      backupJobStatus: backupJob?.status,
      backupPromoted:
        backupJob?.claimedBy === backupInstructorId &&
        backupJob?.status === "claimed",
      backupClaimStatus: backupClaim?.status,
      rejectDoubleRespondBlocked,
      redispatchStatus: redispatchJob?.status,
      redispatchNotificationsSent: redispatchJob?.notificationsSent,
      cancelledJobStatus: cancelledJob?.status,
      cancelledAcceptedClaimReconciled:
        cancelledAcceptedClaim?.status === "rejected",
      idempotentClaimDedupeWorked: idemClaim1.claimId === idemClaim2.claimId,
      idempotentWithdrawReplaySafe:
        idempotentWithdrawReplaySafe &&
        idemClaimAfterWithdraw?.status === "withdrawn",
      claimsWindowFilterAndOrderCorrect,
      studioJobsPriorityOrderingCorrect,
      studioInstructorVisibilityRealtimeCorrect,
      postingVisibilityForUnverifiedCorrect,
      readModelProjectionConsistencyCorrect,
      centralizedMyJobsQueryConsistent,
      studioJobsCanonicalFallbackCorrect,
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
      await ctx.runMutation(internal.testHarness.cleanupTestJob, {
        jobId: cancelledJobId,
        claimIds: [cancelledAcceptedClaimId],
      });
      await ctx.runMutation(internal.testHarness.cleanupTestJob, {
        jobId: idempotentJobId,
        claimIds: [idemClaim1.claimId],
      });
      await ctx.runMutation(internal.testHarness.cleanupTestJob, {
        jobId: visibilityJobId,
        claimIds: [visibilityClaimId],
      });
      await ctx.runMutation(internal.testHarness.cleanupTestJob, {
        jobId: canonicalFallbackJobId,
        claimIds: [],
      });
      await ctx.runMutation(internal.testHarness.cleanupTestJob, {
        jobId: visibilityPublicJobId,
        claimIds: [],
      });
      await ctx.runMutation(internal.testHarness.cleanupTestJob, {
        jobId: visibilityVerifiedOnlyJobId,
        claimIds: [],
      });
      for (const fixture of claimsWindowFixtures) {
        await ctx.runMutation(internal.testHarness.cleanupTestJob, {
          jobId: fixture.jobId,
          claimIds: [fixture.claimId],
        });
      }
      for (const orderingJobId of studioOrderingJobIds) {
        await ctx.runMutation(internal.testHarness.cleanupTestJob, {
          jobId: orderingJobId,
          claimIds: [],
        });
      }
      await ctx.runMutation(internal.testHarness.cleanupTestData, {
        jobId,
        claimId,
        instructorId,
        studioId,
      });
      await ctx.runMutation(internal.testHarness.cleanupTestUser, {
        userId: backupInstructorId,
      });
      await ctx.runMutation(internal.testHarness.cleanupTestUser, {
        userId: unverifiedInstructorId,
      });
    }

    return result;
  },
});
