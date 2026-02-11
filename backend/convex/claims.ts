// convex/claims.ts
// Claims queries and mutations

import { query, mutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import type { QueryCtx } from "./_generated/server";

type ClaimsWindowArgs = {
  windowStartMs?: number;
  windowEndMs?: number;
};

async function getClaimsForInstructorWithJobs(
  ctx: Pick<QueryCtx, "db">,
  instructorId: Id<"users">,
) {
  const claims = await ctx.db
    .query("claims")
    .withIndex("by_instructor", (q) => q.eq("instructorId", instructorId))
    .collect();

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
    }),
  );

  return claimsWithJobs.filter(
    (value): value is NonNullable<typeof value> => value !== null,
  );
}

function applyClaimsWindowAndSort<
  T extends { _creationTime?: number; job: { startTime?: number } },
>(claimsWithJobs: T[], args: ClaimsWindowArgs) {
  const filtered = claimsWithJobs.filter((value) => {
    const startTime = value.job.startTime;
    if (startTime === undefined) return true;
    if (args.windowStartMs !== undefined && startTime < args.windowStartMs) {
      return false;
    }
    if (args.windowEndMs !== undefined && startTime > args.windowEndMs) {
      return false;
    }
    return true;
  });

  filtered.sort((a, b) => {
    const aStart = a.job.startTime ?? 0;
    const bStart = b.job.startTime ?? 0;
    if (aStart !== bStart) return aStart - bStart;
    return (b._creationTime ?? 0) - (a._creationTime ?? 0);
  });

  return filtered;
}

async function getClaimsForInstructor(
  ctx: Pick<QueryCtx, "db">,
  instructorId: Id<"users">,
  args: ClaimsWindowArgs,
) {
  const claimsWithJobs = await getClaimsForInstructorWithJobs(ctx, instructorId);
  return applyClaimsWindowAndSort(claimsWithJobs, args);
}

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
  args: {
    windowStartMs: v.optional(v.number()),
    windowEndMs: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];

    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();

    if (!user || user.role !== "instructor") return [];

    return await getClaimsForInstructor(ctx, user._id, args);
  },
});

export const getClaimsForInstructorInternal = internalQuery({
  args: {
    instructorId: v.id("users"),
    windowStartMs: v.optional(v.number()),
    windowEndMs: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.instructorId);
    if (!user || user.role !== "instructor") return [];
    return await getClaimsForInstructor(ctx, args.instructorId, args);
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
          instructor: instructor
            ? {
                _id: instructor._id,
                name: instructor.name,
                avatarUrl: instructor.avatarUrl,
                rating: instructor.rating,
                ratingCount: instructor.ratingCount,
                isVerified: instructor.isVerified,
              }
            : null,
        };
      }),
    );

    return claimsWithInstructors;
  },
});

// ==========================================
// MUTATIONS
// ==========================================

export const withdrawClaim = mutation({
  args: {
    claimId: v.id("claims"),
    idempotencyKey: v.optional(v.string()),
  },
  handler: async (ctx, { claimId, idempotencyKey }) => {
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

    if (claim.status !== "pending" && !idempotencyKey) {
      throw new Error("Can only withdraw pending claims");
    }

    await ctx.runMutation(
      internal.jobs.withdrawClaimInternalByJobAndInstructorIdempotent,
      {
        jobId: claim.jobId,
        instructorId: user._id,
        idempotencyKey,
      },
    );
  },
});
