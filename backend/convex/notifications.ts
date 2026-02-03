// convex/notifications.ts
// Push notification handling
// Uses Haversine for meter-accurate radius matching

import { internalAction, internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { findInstructorsForJob, isWithinRadius } from "./geo";

// ==========================================
// NOTIFICATION DISPATCH
// ==========================================

/**
 * Dispatch notifications to all matching instructors.
 * Filters by:
 * 1. Precise Haversine distance (meter-level accuracy)
 * 2. Category match (skill-based)
 * 3. Verification requirements
 * 4. Notification preferences (opt-in by default)
 * 
 * Example: 2.95km job WILL notify an instructor with 3km radius!
 */
export const dispatchJobNotifications = internalAction({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const job = await ctx.runQuery(internal.jobs.getJobById, { jobId });
    if (!job || job.status !== "open") return;
    
    // 2026 GEOSPATIAL QUERY (REVERSE RADIUS)
    // Find instructors whose radius covers this job location
    const matchedResults = await ctx.runQuery(internal.geo.findInstructorsForJobQuery, {
      jobPoint: { latitude: job.latitude, longitude: job.longitude },
      jobCategory: job.category,
      requiresVerification: job.requiresVerification,
    });
    
    // Fetch full instructor docs for matched IDs (to get FCM tokens)
    const matchedInstructors: Array<{ instructor: any; distanceKm: number }> = [];
    
    for (const match of matchedResults) {
      const instructor = await ctx.runQuery(internal.users.getUserById, { userId: match.instructorId });
      if (instructor?.fcmToken) {
        matchedInstructors.push({ 
          instructor, 
          distanceKm: match.distanceMeters / 1000 
        });
      }
    }
    
    if (matchedInstructors.length === 0) return;
    
    // Sort by distance (closest first)
    matchedInstructors.sort((a, b) => a.distanceKm - b.distanceKm);
    
    const sosPrefix = job.sosBoostApplied ? "🚨 SOS " : "";
    const title = `${sosPrefix}New ${job.category} job nearby!`;
    const body = `₪${job.currentRate.toFixed(0)} • ${job.address}`;
    
    for (const { instructor, distanceKm } of matchedInstructors) {
      await ctx.runAction(internal.actions.sendPush.send, {
        fcmToken: instructor.fcmToken!,
        title,
        body,
        data: { 
          type: "new_job", 
          jobId: job._id,
          distanceKm: distanceKm.toString(),
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
      instructorIds: matchedInstructors.map(({ instructor }) => instructor._id),
    });
  },
});


export const notifyStudioOfClaim = internalAction({
  args: {
    jobId: v.id("jobs"),
    claimId: v.id("claims"),
  },
  handler: async (ctx, { jobId, claimId }) => {
    const job = await ctx.runQuery(internal.jobs.getJobById, { jobId });
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
    
    const job = await ctx.runQuery(internal.jobs.getJobById, { jobId: claim.jobId });
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
    
    const job = await ctx.runQuery(internal.jobs.getJobById, { jobId: claim.jobId });
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
    
    const job = await ctx.runQuery(internal.jobs.getJobById, { jobId });
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
