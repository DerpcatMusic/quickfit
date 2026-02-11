// convex/notifications.ts
// Push notification handling
// Dual-mode dispatch: radius (geospatial) + zone (indexed table)

import { internalAction, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";

// ==========================================
// NOTIFICATION DISPATCH
// ==========================================

/**
 * Unified dispatch for dual-mode instructor matching.
 * 
 * Queries two systems in parallel:
 * 1. RADIUS MODE: Geospatial index for instructors within job radius
 * 2. ZONE MODE: Indexed table for instructors subscribed to job's zone
 * 
 * Results are merged, deduped, and batch-notified via FCM.
 */
const dispatchJobNotifications = internalAction({
  args: { jobId: v.id("jobs"), dispatchVersion: v.optional(v.number()) },
  handler: async (ctx, { jobId, dispatchVersion }) => {
    const job = await ctx.runQuery(internal.jobs.getJobInternal, { jobId });
    if (!job || job.status !== "open") return;
    if (dispatchVersion !== undefined && job.dispatchVersion !== dispatchVersion) return;
    if (job.notificationsSent) return;

    // ========================================
    // 1. RADIUS MODE: Geospatial query
    // ========================================
    const radiusMatches = await ctx.runQuery(internal.geo.findInstructorsForJobQuery, {
      jobPoint: { latitude: job.latitude, longitude: job.longitude },
      jobCategory: job.category,
      requiresVerification: job.requiresVerification,
      isSos: job.sosBoostApplied,
    });
    console.log(`[dispatch] Radius mode: ${radiusMatches.length} instructors`);

    // ========================================
    // 2. ZONE MODE: Indexed table query
    // ========================================
    let zoneMatches: Array<{ instructorId: Id<"users"> }> = [];
    if (job.zoneId) {
      zoneMatches = await ctx.runQuery(internal.zoneSubscriptions.findZoneInstructors, {
        zoneId: job.zoneId,
        category: job.category,
        requiresVerification: job.requiresVerification,
        isSos: job.sosBoostApplied,
      });
      console.log(`[dispatch] Zone mode: ${zoneMatches.length} instructors`);
    }

    // ========================================
    // 3. Merge & dedupe instructor IDs
    // ========================================
    const instructorIds = new Set<Id<"users">>([
      ...radiusMatches.map((m: { instructorId: Id<"users"> }) => m.instructorId),
      ...zoneMatches.map((m: { instructorId: Id<"users"> }) => m.instructorId),
    ]);
    
    if (instructorIds.size === 0) {
      console.log(`[dispatch] No instructors matched for job ${jobId}`);
      return;
    }
    console.log(`[dispatch] Total unique instructors: ${instructorIds.size}`);

    // ========================================
    // 4. Fetch instructor details for FCM tokens
    // ========================================
    const instructors = await Promise.all(
      Array.from(instructorIds).map((id) =>
        ctx.runQuery(internal.users.getUserById, { userId: id })
      )
    );

    const toNotify = instructors.filter((i: any): i is NonNullable<typeof i> => !!i && !!i.fcmToken);
    if (toNotify.length === 0) {
      console.log(`[dispatch] No instructors with FCM tokens for job ${jobId}`);
      return;
    }

    // ========================================
    // 5. Batch push notifications
    // ========================================
    const sosPrefix = job.sosBoostApplied ? "SOS " : "";
    const title = `${sosPrefix}New ${job.category} job nearby!`;
    const body = `NIS ${job.currentRate.toFixed(0)} - ${job.address}`;
    
    const BATCH_SIZE = 500;
    let dispatchFailed = false;
    let dispatchError: string | undefined;

    for (let i = 0; i < toNotify.length; i += BATCH_SIZE) {
      const batch = toNotify.slice(i, i + BATCH_SIZE);

      const result = await ctx.runAction(internal.actions.sendPush.sendBatch, {
        fcmTokens: batch.map((instructor: { fcmToken?: string }) => instructor.fcmToken!),
        title,
        body,
        data: {
          type: "new_job",
          jobId: job._id,
          isSos: job.sosBoostApplied ? "true" : "false",
          category: job.category,
        },
      });
      
      if (!result?.success) {
        dispatchFailed = true;
        dispatchError = result?.error ?? "dispatch_failed";
        break;
      }

      // Log each notification
      await Promise.all(
        batch.map((instructor: { _id: Id<"users"> }) =>
          ctx.runMutation(internal.notifications.logNotification, {
            userId: instructor._id,
            jobId: job._id,
            type: "new_job",
            title,
            body,
          })
        )
      );
    }

    if (dispatchFailed) {
      await ctx.runMutation(internal.jobs.scheduleDispatchRetry, {
        jobId,
        dispatchVersion: dispatchVersion ?? job.dispatchVersion ?? 0,
        error: dispatchError,
      });
      return;
    }

    await ctx.runMutation(internal.jobs.markNotified, {
      jobId,
      instructorIds: toNotify.map((m: { _id: Id<"users"> }) => m._id),
    });
  },
});



const notifyStudioOfClaim = internalAction({
  args: {
    jobId: v.id("jobs"),
    claimId: v.id("claims"),
  },
  handler: async (ctx, { jobId, claimId }) => {
    const job = await ctx.runQuery(internal.jobs.getJobInternal, { jobId });
    if (!job) return;
    
    const studio = await ctx.runQuery(internal.users.getUserById, { 
      userId: job.studioId 
    });
    if (!studio?.fcmToken) return;
    
    const claim = await ctx.runQuery(internal.claims.getClaimById, { claimId });
    if (!claim) return;
    
    const instructor = await ctx.runQuery(internal.users.getUserById, {
      userId: claim.instructorId,
    });
    
    const title = "New claim on your job!";
    const body = `${instructor?.name || "An instructor"} wants to cover "${job.title}"`;
    
    await ctx.runAction(internal.actions.sendPush.send, {
      fcmToken: studio.fcmToken,
      title,
      body,
      data: { type: "job_claimed", jobId, claimId },
    });
    
    await ctx.runMutation(internal.notifications.logNotification, {
      userId: studio._id,
      jobId,
      type: "job_claimed",
      title,
      body,
    });
  },
});

const notifyClaimAccepted = internalAction({
  args: { claimId: v.id("claims") },
  handler: async (ctx, { claimId }) => {
    const claim = await ctx.runQuery(internal.claims.getClaimById, { claimId });
    if (!claim) return;
    
    const instructor = await ctx.runQuery(internal.users.getUserById, {
      userId: claim.instructorId,
    });
    if (!instructor?.fcmToken) return;
    
    const job = await ctx.runQuery(internal.jobs.getJobInternal, { jobId: claim.jobId });
    if (!job) return;
    
    const title = "Claim accepted!";
    const body = `You're confirmed for "${job.title}"`;
    
    await ctx.runAction(internal.actions.sendPush.send, {
      fcmToken: instructor.fcmToken,
      title,
      body,
      data: { type: "claim_accepted", jobId: job._id, claimId },
    });
    
    await ctx.runMutation(internal.notifications.logNotification, {
      userId: instructor._id,
      jobId: job._id,
      type: "claim_accepted",
      title,
      body,
    });
  },
});

const notifyClaimRejected = internalAction({
  args: { claimId: v.id("claims") },
  handler: async (ctx, { claimId }) => {
    const claim = await ctx.runQuery(internal.claims.getClaimById, { claimId });
    if (!claim) return;
    
    const instructor = await ctx.runQuery(internal.users.getUserById, {
      userId: claim.instructorId,
    });
    if (!instructor?.fcmToken) return;
    
    const job = await ctx.runQuery(internal.jobs.getJobInternal, { jobId: claim.jobId });
    if (!job) return;
    
    const title = "Claim not accepted";
    const body = `Your claim for "${job.title}" was not accepted. Keep looking!`;
    
    await ctx.runAction(internal.actions.sendPush.send, {
      fcmToken: instructor.fcmToken,
      title,
      body,
      data: { type: "claim_rejected", jobId: job._id, claimId },
    });
    
    await ctx.runMutation(internal.notifications.logNotification, {
      userId: instructor._id,
      jobId: job._id,
      type: "claim_rejected",
      title,
      body,
    });
  },
});

const notifyJobCancelled = internalAction({
  args: {
    jobId: v.id("jobs"),
    instructorId: v.id("users"),
  },
  handler: async (ctx, { jobId, instructorId }) => {
    const instructor = await ctx.runQuery(internal.users.getUserById, {
      userId: instructorId,
    });
    if (!instructor?.fcmToken) return;
    
    const job = await ctx.runQuery(internal.jobs.getJobInternal, { jobId });
    if (!job) return;
    
    const title = "Job cancelled";
    const body = `"${job.title}" has been cancelled by the studio`;
    
    await ctx.runAction(internal.actions.sendPush.send, {
      fcmToken: instructor.fcmToken,
      title,
      body,
      data: { type: "job_cancelled", jobId },
    });
    
    await ctx.runMutation(internal.notifications.logNotification, {
      userId: instructorId,
      jobId,
      type: "job_cancelled",
      title,
      body,
    });
  },
});

// BACKUP QUEUE NOTIFICATIONS

const notifyStudioOfBackupClaim = internalAction({
  args: {
    jobId: v.id("jobs"),
    backupClaimId: v.id("claims"),
    primaryInstructorId: v.id("users"),
    backupInstructorId: v.id("users"),
  },
  handler: async (ctx, { jobId, backupClaimId, primaryInstructorId, backupInstructorId }) => {
    const job = await ctx.runQuery(internal.jobs.getJobInternal, { jobId });
    if (!job) return;
    
    const studio = await ctx.runQuery(internal.users.getUserById, { 
      userId: job.studioId 
    });
    if (!studio?.fcmToken) return;
    
    const primaryInstructor = await ctx.runQuery(internal.users.getUserById, {
      userId: primaryInstructorId,
    });
    
    const backupInstructor = await ctx.runQuery(internal.users.getUserById, {
      userId: backupInstructorId,
    });
    
    const title = "Backup instructor available!";
    const body = `${primaryInstructor?.name || "Primary"} claimed, ${backupInstructor?.name || "Backup"} as backup for "${job.title}"`;
    
    await ctx.runAction(internal.actions.sendPush.send, {
      fcmToken: studio.fcmToken,
      title,
      body,
      data: { 
        type: "backup_claimed", 
        jobId, 
        backupClaimId,
        primaryInstructorId,
        backupInstructorId,
      },
    });
    
    await ctx.runMutation(internal.notifications.logNotification, {
      userId: studio._id,
      jobId,
      type: "backup_claimed",
      title,
      body,
    });
  },
});

const notifyBackupPromoted = internalAction({
  args: {
    jobId: v.id("jobs"),
    newPrimaryInstructorId: v.id("users"),
  },
  handler: async (ctx, { jobId, newPrimaryInstructorId }) => {
    const job = await ctx.runQuery(internal.jobs.getJobInternal, { jobId });
    if (!job) return;
    
    const instructor = await ctx.runQuery(internal.users.getUserById, {
      userId: newPrimaryInstructorId,
    });
    if (!instructor?.fcmToken) return;
    
    const title = "You are now the primary instructor!";
    const body = `The original instructor withdrew. You're now confirmed for "${job.title}"`;
    
    await ctx.runAction(internal.actions.sendPush.send, {
      fcmToken: instructor.fcmToken,
      title,
      body,
      data: { 
        type: "backup_promoted", 
        jobId,
      },
    });
    
    await ctx.runMutation(internal.notifications.logNotification, {
      userId: newPrimaryInstructorId,
      jobId,
      type: "backup_promoted",
      title,
      body,
    });
    
    // Also notify studio
    const studio = await ctx.runQuery(internal.users.getUserById, { 
      userId: job.studioId 
    });
    
    if (studio?.fcmToken) {
      const studioTitle = "Backup instructor promoted";
      const studioBody = `${instructor.name} is now your primary instructor for "${job.title}"`;
      await ctx.runAction(internal.actions.sendPush.send, {
        fcmToken: studio.fcmToken,
        title: studioTitle,
        body: studioBody,
        data: { type: "backup_promoted_studio", jobId, newPrimaryInstructorId },
      });

      await ctx.runMutation(internal.notifications.logNotification, {
        userId: studio._id,
        jobId,
        type: "backup_promoted_studio",
        title: studioTitle,
        body: studioBody,
      });
    }
  },
});

// ==========================================
// LOGGING
// ==========================================

const logNotification = internalMutation({
  args: {
    userId: v.id("users"),
    jobId: v.optional(v.id("jobs")),
    type: v.union(
      v.literal("new_job"),
      v.literal("job_claimed"),
      v.literal("claim_accepted"),
      v.literal("claim_rejected"),
      v.literal("job_cancelled"),
      v.literal("backup_claimed"),
      v.literal("backup_promoted"),
      v.literal("backup_promoted_studio"),
      v.literal("verification_complete"),
      v.literal("reminder")
    ),
    title: v.string(),
    body: v.string(),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert("notificationLogs", {
      userId: args.userId,
      jobId: args.jobId,
      type: args.type,
      title: args.title,
      body: args.body,
      sent: true,
      sentAt: Date.now(),
      createdAt: Date.now(),
    });
  },
});

const notificationsCore = {
  dispatchJobNotifications,
  notifyStudioOfClaim,
  notifyClaimAccepted,
  notifyClaimRejected,
  notifyJobCancelled,
  notifyStudioOfBackupClaim,
  notifyBackupPromoted,
  logNotification,
};

export default notificationsCore;

