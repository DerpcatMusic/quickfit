// convex/notifications.ts
// Push notification handling
// Uses H3 hex-based matching (O(1) vs O(n) geospatial)

import { internalAction, internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";

// ==========================================
// NOTIFICATION DISPATCH
// ==========================================

/**
 * Dispatch notifications to all matching instructors.
 * Filters by:
 * 1. H3 hex intersection (O(1) lookup!)
 * 2. Category match (skill-based)
 * 3. Verification requirements
 * 4. Notification preferences (opt-in by default)
 * 
 * H3 Resolution 11 = ~50m precision
 */
export const dispatchJobNotifications = internalAction({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const job = await ctx.runQuery(internal.jobs.getJobInternal, { jobId });
    if (!job || job.status !== "open") return;
    
    // H3 HEX-BASED MATCHING (O(1) - FAST!)
    // Find instructors whose work area contains this job's hex
    if (!job.locationHex11) {
      console.log("[dispatchJobNotifications] Job has no H3 hex, skipping");
      return;
    }
    
    // Query instructors using H3 hex intersection
    const matchingInstructors = await ctx.db
      .query("users")
      .withIndex("by_role", q => q.eq("role", "instructor"))
      .filter(q => q.eq(q.field("isVerified"), true))
      .filter(q => q.eq(q.field("notificationsEnabled"), true))
      .filter(q => q.contains(q.field("workAreaHexes11"), job.locationHex11))
      .filter(q => q.contains(q.field("categories"), job.category))
      .collect();
    
    console.log(`[dispatchJobNotifications] Found ${matchingInstructors.length} matching instructors via H3`);
    
    if (matchingInstructors.length === 0) return;
    
    const sosPrefix = job.sosBoostApplied ? "🚨 SOS " : "";
    const title = `${sosPrefix}New ${job.category} job nearby!`;
    const body = `₪${job.currentRate.toFixed(0)} • ${job.address}`;
    
    for (const instructor of matchingInstructors) {
      if (!instructor.fcmToken) continue;
      
      await ctx.runAction(internal.actions.sendPush.send, {
        fcmToken: instructor.fcmToken,
        title,
        body,
        data: { 
          type: "new_job", 
          jobId: job._id,
        },
      });
      
      await ctx.runMutation(internal.notifications.logNotification, {
        userId: instructor._id,
        jobId: job._id,
        type: "new_job",
        title,
        body,
      });
    }
    
    await ctx.runMutation(internal.jobs.markNotified, {
      jobId,
      instructorIds: matchingInstructors.map(i => i._id),
    });
  },
});


export const notifyStudioOfClaim = internalAction({
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

export const notifyClaimAccepted = internalAction({
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
    
    const title = "Claim accepted! 🎉";
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

export const notifyClaimRejected = internalAction({
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

export const notifyJobCancelled = internalAction({
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

export const notifyStudioOfBackupClaim = internalAction({
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
    
    const title = "🛡️ Backup instructor available!";
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

export const notifyBackupPromoted = internalAction({
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
    
    const title = "🎉 You're now the primary instructor!";
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
      await ctx.runAction(internal.actions.sendPush.send, {
        fcmToken: studio.fcmToken,
        title: "🔄 Backup instructor promoted",
        body: `${instructor.name} is now your primary instructor for "${job.title}"`,
        data: { type: "backup_promoted_studio", jobId, newPrimaryInstructorId },
      });
    }
  },
});

// ==========================================
// LOGGING
// ==========================================

export const logNotification = internalMutation({
  args: {
    userId: v.id("users"),
    jobId: v.optional(v.id("jobs")),
    type: v.string(),
    title: v.string(),
    body: v.string(),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert("notificationLogs", {
      userId: args.userId,
      jobId: args.jobId,
      type: args.type as any,
      title: args.title,
      body: args.body,
      sent: true,
      sentAt: Date.now(),
      createdAt: Date.now(),
    });
  },
});
