// convex/claims.ts
// Claims queries and mutations

import { query, mutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";

// ==========================================
// QUERIES
// ==========================================

export const getClaimById = internalQuery({
  args: { claimId: v.id("claims") },
  handler: async (ctx, { claimId }) => {
    return await ctx.db.get(claimId);
  },
});

export const getMyClaims = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user || user.role !== "instructor") return [];
    
    const claims = await ctx.db
      .query("claims")
      .withIndex("by_instructor", (q) => q.eq("instructorId", user._id))
      .order("desc")
      .take(50);
    
    // Add job details
    const claimsWithJobs = await Promise.all(
      claims.map(async (claim) => {
        const job = await ctx.db.get(claim.jobId);
        if (!job) return null;
        
        const studio = await ctx.db.get(job.studioId);
        
        return {
          ...claim,
          job: {
            ...job,
            studioName: studio?.businessName || studio?.name,
            studioAvatarUrl: studio?.avatarUrl,
          },
        };
      })
    );
    
    return claimsWithJobs.filter(Boolean);
  },
});

export const getJobClaims = query({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];
    
    const job = await ctx.db.get(jobId);
    if (!job) return [];
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user || user._id !== job.studioId) return [];
    
    const claims = await ctx.db
      .query("claims")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .collect();
    
    // Add instructor details
    const claimsWithInstructors = await Promise.all(
      claims.map(async (claim) => {
        const instructor = await ctx.db.get(claim.instructorId);
        
        return {
          ...claim,
          instructor: instructor ? {
            _id: instructor._id,
            name: instructor.name,
            avatarUrl: instructor.avatarUrl,
            rating: instructor.rating,
            ratingCount: instructor.ratingCount,
            isVerified: instructor.isVerified,
          } : null,
        };
      })
    );
    
    return claimsWithInstructors;
  },
});

// ==========================================
// MUTATIONS
// ==========================================

export const withdrawClaim = mutation({
  args: { claimId: v.id("claims") },
  handler: async (ctx, { claimId }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    const claim = await ctx.db.get(claimId);
    if (!claim) throw new Error("Claim not found");
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user || user._id !== claim.instructorId) {
      throw new Error("You can only withdraw your own claims");
    }
    
    if (claim.status !== "pending") {
      throw new Error("Can only withdraw pending claims");
    }
    
    await ctx.db.patch(claimId, {
      status: "withdrawn",
      respondedAt: Date.now(),
    });
    
    // Reopen the job
    const job = await ctx.db.get(claim.jobId);
    if (job && job.status === "claimed" && job.claimedBy === user._id) {
      await ctx.db.patch(claim.jobId, {
        status: "open",
        claimedBy: undefined,
        claimedAt: undefined,
        updatedAt: Date.now(),
      });
    }
  },
});
