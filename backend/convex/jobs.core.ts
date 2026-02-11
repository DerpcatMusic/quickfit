// convex/jobs.ts
// Job queries and mutations

import {
  query,
  mutation,
  internalQuery,
  internalMutation,
} from "./_generated/server";
import type { QueryCtx } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import { computeLeadTimeBoostPercent } from "./pricing";
import {
  haversineDistanceMeters,
  haversineDistanceKm,
  isWithinRadius,
  findJobsForInstructor,
  syncJobLocation,
  removeJobLocation,
} from "./geo";
import { syncJobReadModels } from "./jobReadModels";

// Categories for Israeli market
const CATEGORIES = [
  "yoga",
  "pilates",
  "reformer_pilates",
  "mat_pilates",
  "functional",
  "spinning",
  "hiit",
  "dance",
  "strength",
  "mobility",
  "barre",
  "personal_training",
] as const;

const IDEMPOTENCY_KEY_MAX_LENGTH = 128;

function normalizeIdempotencyKey(key: string | undefined) {
  if (!key) return undefined;
  const normalized = key.trim();
  if (!normalized) return undefined;
  if (normalized.length > IDEMPOTENCY_KEY_MAX_LENGTH) {
    throw new Error(
      `idempotencyKey must be <= ${IDEMPOTENCY_KEY_MAX_LENGTH} chars`,
    );
  }
  return normalized;
}

function buildMutationIdempotencyKey(
  operation: "claimJob" | "withdrawClaim",
  userId: Id<"users">,
  jobId: Id<"jobs">,
  idempotencyKey: string,
) {
  return `${operation}:${userId}:${jobId}:${idempotencyKey}`;
}

// ==========================================
// QUERIES
// ==========================================

const getJobInternal = internalQuery({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    return await ctx.db.get(jobId);
  },
});

const getJobById = query({
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
    const user = identity
      ? await ctx.db
          .query("users")
          .withIndex("by_firebaseUid", (q) =>
            q.eq("firebaseUid", identity.subject),
          )
          .first()
      : null;

    const isOwner = user?._id === job.studioId;
    const isPrimary = user?._id === job.claimedBy;
    const isBackup = user?._id === job.backupClaimedBy;

    // Get the active claim ID (most recent accepted or pending claim)
    let activeClaim = null;
    if (job.claimedBy) {
      activeClaim = await ctx.db
        .query("claims")
        .withIndex("by_job_status_instructor", (q) =>
          q
            .eq("jobId", jobId)
            .eq("status", "pending")
            .eq("instructorId", job.claimedBy!),
        )
        .first();
      if (!activeClaim) {
        activeClaim = await ctx.db
          .query("claims")
          .withIndex("by_job_status_instructor", (q) =>
            q
              .eq("jobId", jobId)
              .eq("status", "accepted")
              .eq("instructorId", job.claimedBy!),
          )
          .first();
      }
    }

    return {
      ...job,
      studioName: studio?.businessName || studio?.name || "Studio",
      claimedInstructor,
      claimId: activeClaim?._id,
      canClaimAsPrimary: job.status === "open",
      canClaimAsBackup:
        job.status === "claimed" &&
        !job.backupClaimedBy &&
        !isPrimary &&
        !isOwner,
      userRole: isOwner
        ? "owner"
        : isPrimary
          ? "primary"
          : isBackup
            ? "backup"
            : "viewer",
    };
  },
});

/**
 * Get jobs within instructor's configured radius.
 * Uses Haversine formula for meter-level precision.
 * A 2.95km job WILL match a 3.00km radius.
 */
const getNearbyJobs = query({
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
        : [...CATEGORIES];

    let jobResults: Array<{
      _id: Id<"jobs">;
      studioId: Id<"users">;
      studioName: string;
      title: string;
      category: string;
      startTime: number;
      endTime: number;
      baseRate: number;
      address: string;
      status: string;
      latitude: number;
      longitude: number;
      sosBoostApplied: boolean;
      currentRate: number;
      distanceMeters: number;
      createdAt: number;
    }> = [];

    if (user.dispatchMode === "zone") {
      jobResults = await findJobsForInstructorByZones(
        ctx,
        user,
        user.zoneIds ?? [],
        categories,
      );
    } else {
      if (!user.latitude || !user.longitude || !user.radiusKm) return [];
      jobResults = await findJobsForInstructor(
        ctx,
        { latitude: user.latitude, longitude: user.longitude },
        user.radiusKm,
        categories,
        user.isVerified,
      );
    }

    // Sort by SOS first (manually sorting the enriched results later if needed)
    // For now, these results are already distance-sorted.
    const parsedLimit =
      typeof args.limit === "string" ? parseInt(args.limit, 10) : args.limit;
    const safeLimit = Number.isFinite(parsedLimit ?? NaN)
      ? (parsedLimit as number)
      : 50;
    const limitedResults = jobResults.slice(0, safeLimit ?? 50);

    return limitedResults.map((match) => ({
      ...match,
      distanceKm: match.distanceMeters / 1000,
      studioAvatarUrl: undefined,
      _creationTime: match.createdAt,
    }));
  },
});

/**
 * Get jobs within a specific radius for map display.
 * Returns all open jobs with precise distance.
 */
const getJobsForMap = query({
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
        : [...CATEGORIES];

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
        categories,
      );
    } else {
      const radiusKm = user.radiusKm ?? 5;
      jobResults = await findJobsForInstructor(
        ctx,
        { latitude: user.latitude, longitude: user.longitude },
        radiusKm,
        categories,
        user.isVerified,
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
const getZoneJobsForInstructor = query({
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
      args.categories
        ?.split(",")
        .map((c) => c.trim())
        .filter(Boolean) ??
      (user.categories && user.categories.length > 0
        ? user.categories
        : [...CATEGORIES]);

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
  categories: string[],
): Promise<
  Array<{
    _id: Id<"jobs">;
    studioId: Id<"users">;
    studioName: string;
    title: string;
    category: string;
    startTime: number;
    endTime: number;
    baseRate: number;
    address: string;
    status: string;
    latitude: number;
    longitude: number;
    sosBoostApplied: boolean;
    currentRate: number;
    distanceMeters: number;
    createdAt: number;
  }>
> {
  const MAX_RESULTS = 200;
  const jobsMap = new Map<string, any>();
  const hasUserLocation = !!(user.latitude && user.longitude);
  const normalizedCategories = Array.from(new Set(categories.filter(Boolean)));

  for (const zoneId of zoneIds) {
    if (jobsMap.size >= MAX_RESULTS) break;

    if (normalizedCategories.length > 0) {
      for (const category of normalizedCategories) {
        const rows = await ctx.db
          .query("readModel_instructorFeed")
          .withIndex("by_zone_category_status_createdAt", (q: any) =>
            q
              .eq("zoneId", zoneId)
              .eq("category", category)
              .eq("status", "open"),
          )
          .order("desc")
          .take(80);

        for (const row of rows) {
          if (!user.isVerified && row.requiresVerification) continue;
          if (jobsMap.has(row.jobId)) continue;

          const distanceMeters = hasUserLocation
            ? Math.round(
                haversineDistanceMeters(
                  user.latitude,
                  user.longitude,
                  row.latitude,
                  row.longitude,
                ),
              )
            : 0;
          jobsMap.set(row.jobId, {
            _id: row.jobId,
            studioId: row.studioId,
            studioName: row.studioName || "Studio",
            title: row.title,
            category: row.category,
            startTime: row.startTime,
            endTime: row.endTime,
            baseRate: row.baseRate,
            address: row.address,
            status: row.status,
            latitude: row.latitude,
            longitude: row.longitude,
            sosBoostApplied: row.sosBoostApplied,
            currentRate: row.currentRate,
            distanceMeters,
            createdAt: row.createdAt,
          });
          if (jobsMap.size >= MAX_RESULTS) break;
        }
        if (jobsMap.size >= MAX_RESULTS) break;
      }
    } else {
      const rows = await ctx.db
        .query("readModel_instructorFeed")
        .withIndex("by_zone_status_createdAt", (q: any) =>
          q.eq("zoneId", zoneId).eq("status", "open"),
        )
        .order("desc")
        .take(120);
      for (const row of rows) {
        if (!user.isVerified && row.requiresVerification) continue;
        if (jobsMap.has(row.jobId)) continue;

        const distanceMeters = hasUserLocation
          ? Math.round(
              haversineDistanceMeters(
                user.latitude,
                user.longitude,
                row.latitude,
                row.longitude,
              ),
            )
          : 0;
        jobsMap.set(row.jobId, {
          _id: row.jobId,
          studioId: row.studioId,
          studioName: row.studioName || "Studio",
          title: row.title,
          category: row.category,
          startTime: row.startTime,
          endTime: row.endTime,
          baseRate: row.baseRate,
          address: row.address,
          status: row.status,
          latitude: row.latitude,
          longitude: row.longitude,
          sosBoostApplied: row.sosBoostApplied,
          currentRate: row.currentRate,
          distanceMeters,
          createdAt: row.createdAt,
        });
        if (jobsMap.size >= MAX_RESULTS) break;
      }
    }
  }

  const projectedResults = Array.from(jobsMap.values());
  if (projectedResults.length > 0) {
    if (hasUserLocation) {
      projectedResults.sort((a, b) => a.distanceMeters - b.distanceMeters);
    } else {
      projectedResults.sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0));
    }
    return projectedResults;
  }

  // Fallback keeps existing jobs visible until projections are fully backfilled.
  return await findJobsForInstructorByZonesLegacy(ctx, user, zoneIds, categories);
}

async function findJobsForInstructorByZonesLegacy(
  ctx: { db: any },
  user: any,
  zoneIds: Id<"zones">[],
  categories: string[],
): Promise<
  Array<{
    _id: Id<"jobs">;
    studioId: Id<"users">;
    studioName: string;
    title: string;
    category: string;
    startTime: number;
    endTime: number;
    baseRate: number;
    address: string;
    status: string;
    latitude: number;
    longitude: number;
    sosBoostApplied: boolean;
    currentRate: number;
    distanceMeters: number;
    createdAt: number;
  }>
> {
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
            q
              .eq("zoneId", zoneId)
              .eq("category", category)
              .eq("status", "open"),
          )
          .collect();

        for (const job of jobs) {
          if (!user.isVerified && job.requiresVerification) continue;
          if (!jobsMap.has(job._id)) {
            const studioDoc = await ctx.db.get(job.studioId);
            const distanceMeters = hasUserLocation
              ? Math.round(
                  haversineDistanceMeters(
                    user.latitude,
                    user.longitude,
                    job.latitude,
                    job.longitude,
                  ),
                )
              : 0;
            jobsMap.set(job._id, {
              _id: job._id,
              studioId: job.studioId,
              studioName:
                studioDoc?.businessName || studioDoc?.name || "Studio",
              title: job.title,
              category: job.category,
              startTime: job.startTime,
              endTime: job.endTime,
              baseRate: job.baseRate,
              address: job.address,
              status: job.status,
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
          q.eq("zoneId", zoneId).eq("status", "open"),
        )
        .collect();

      for (const job of jobs) {
        if (!user.isVerified && job.requiresVerification) continue;
        if (!jobsMap.has(job._id)) {
          const studioDoc = await ctx.db.get(job.studioId);
          const distanceMeters = hasUserLocation
            ? Math.round(
                haversineDistanceMeters(
                  user.latitude,
                  user.longitude,
                  job.latitude,
                  job.longitude,
                ),
              )
            : 0;
          jobsMap.set(job._id, {
            _id: job._id,
            studioId: job.studioId,
            studioName:
              studioDoc?.businessName || studioDoc?.name || "Studio",
            title: job.title,
            category: job.category,
            startTime: job.startTime,
            endTime: job.endTime,
            baseRate: job.baseRate,
            address: job.address,
            status: job.status,
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
const getInstructorStats = query({
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

    const thisMonthJobs = jobs.filter((j) => j && j.createdAt >= oneMonthAgo);

    const totalEarnings = jobs.reduce(
      (sum, j) => sum + (j?.currentRate || 0),
      0,
    );

    const thisMonthEarnings = thisMonthJobs.reduce(
      (sum, j) => sum + (j?.currentRate || 0),
      0,
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

function getStudioJobStatusPriority(status: string) {
  switch (status) {
    case "claimed":
    case "backup_claimed":
    case "open":
      return 0;
    case "confirmed":
      return 1;
    case "completed":
      return 2;
    case "cancelled":
      return 3;
    default:
      return 4;
  }
}

function sortStudioJobsByPriority<
  T extends { status: string; startTime?: number; createdAt?: number },
>(jobs: T[]) {
  jobs.sort((a, b) => {
    const priorityDelta =
      getStudioJobStatusPriority(a.status) - getStudioJobStatusPriority(b.status);
    if (priorityDelta !== 0) return priorityDelta;

    const aStart = a.startTime ?? Number.MAX_SAFE_INTEGER;
    const bStart = b.startTime ?? Number.MAX_SAFE_INTEGER;
    if (aStart !== bStart) return aStart - bStart;

    return (b.createdAt ?? 0) - (a.createdAt ?? 0);
  });

  return jobs;
}

type ClaimsWindowArgs = {
  windowStartMs?: number;
  windowEndMs?: number;
};

async function getClaimsForInstructorForMyJobs(
  ctx: { db: QueryCtx["db"] },
  instructorId: Id<"users">,
  args: ClaimsWindowArgs,
) {
  const claims = await ctx.db
    .query("claims")
    .withIndex("by_instructor", (q) => q.eq("instructorId", instructorId))
    .order("desc")
    .take(MAX_MY_JOBS_CLAIMS);

  const claimsWithJobs = await Promise.all(
    claims.map(async (claim) => {
      const job = await ctx.db.get(claim.jobId);
      if (!job) return null;
      if (args.windowStartMs !== undefined && job.startTime < args.windowStartMs) {
        return null;
      }
      if (args.windowEndMs !== undefined && job.startTime > args.windowEndMs) {
        return null;
      }
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

  const filtered = claimsWithJobs.filter(
    (entry): entry is NonNullable<typeof entry> => Boolean(entry),
  );
  filtered.sort((a, b) => {
    const aStart = a.job.startTime ?? 0;
    const bStart = b.job.startTime ?? 0;
    if (aStart !== bStart) return aStart - bStart;
    return (b._creationTime ?? 0) - (a._creationTime ?? 0);
  });

  return filtered;
}

async function getStudioJobsForStudioLegacy(
  ctx: { db: QueryCtx["db"] },
  studioId: Id<"users">,
) {
  const jobs = await ctx.db
    .query("jobs")
    .withIndex("by_studio", (q) => q.eq("studioId", studioId))
    .order("desc")
    .take(60);

  // Hydrate claimed/backup instructor data in one pass per unique instructor id.
  const instructorIds = Array.from(
    new Set(
      jobs
        .map((job) => job.claimedBy ?? job.backupClaimedBy)
        .filter((id): id is Id<"users"> => id !== undefined),
    ),
  );
  const instructors = await Promise.all(instructorIds.map((id) => ctx.db.get(id)));
  const instructorById = new Map(
    instructors
      .filter((instructor): instructor is NonNullable<typeof instructor> =>
        Boolean(instructor),
      )
      .map((instructor) => [instructor._id, instructor]),
  );

  // Keep claim actions functional with bounded lookups only for claimable rows.
  const claimableJobs = jobs
    .filter(
      (job) =>
        (job.status === "claimed" || job.status === "backup_claimed") &&
        Boolean(job.claimedBy ?? job.backupClaimedBy),
    )
    .slice(0, 20);
  const claimEntries = await Promise.all(
    claimableJobs.map(async (job) => {
      const instructorId = job.claimedBy ?? job.backupClaimedBy;
      if (!instructorId) return [job._id, undefined] as const;
      const pending = await ctx.db
        .query("claims")
        .withIndex("by_job_status_instructor", (q) =>
          q.eq("jobId", job._id).eq("status", "pending").eq("instructorId", instructorId),
        )
        .first();
      return [job._id, pending?._id] as const;
    }),
  );
  const claimIdByJobId = new Map(claimEntries);

  const jobsWithDetails = jobs.map((job) => {
    let claimedInstructor = null;
    const activeInstructorId = job.claimedBy ?? job.backupClaimedBy;
    if (activeInstructorId) {
      const instructor = instructorById.get(activeInstructorId);
      if (instructor) {
        claimedInstructor = {
          _id: instructor._id,
          name: instructor.name,
          photoUrl: instructor.avatarUrl,
          avatarUrl: instructor.avatarUrl,
          rating: instructor.rating,
          isVerified: instructor.isVerified,
        };
      }
    }

    return {
      _id: job._id,
      _creationTime: job._creationTime,
      studioId: job.studioId,
      title: job.title,
      description: job.description,
      category: job.category,
      startTime: job.startTime,
      endTime: job.endTime,
      durationMinutes: job.durationMinutes,
      baseRate: job.baseRate,
      currentRate: job.currentRate,
      sosBoostApplied: job.sosBoostApplied,
      sosBoostPercentage: job.sosBoostPercentage,
      latitude: job.latitude,
      longitude: job.longitude,
      address: job.address,
      status: job.status,
      claimedBy: job.claimedBy,
      claimedAt: job.claimedAt,
      confirmedAt: job.confirmedAt,
      backupClaimedBy: job.backupClaimedBy,
      backupClaimedAt: job.backupClaimedAt,
      requiresVerification: job.requiresVerification,
      claimedInstructor,
      claimId: claimIdByJobId.get(job._id),
    };
  });

  return sortStudioJobsByPriority(jobsWithDetails);
}

async function getStudioJobsForStudio(
  ctx: { db: QueryCtx["db"] },
  studioId: Id<"users">,
) {
  // Canonical studio dashboard path intentionally reads from jobs table index.
  // This keeps list/read reliability even if projections are stale or still
  // backfilling after deploy.
  return await getStudioJobsForStudioLegacy(ctx, studioId);
}

const getStudioJobs = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("AUTH_REQUIRED");

    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();

    if (!user || user.role !== "studio") throw new Error("STUDIO_ONLY");

    return await getStudioJobsForStudio(ctx, user._id);
  },
});

const getMyJobs = query({
  args: {
    windowStartMs: v.optional(v.number()),
    windowEndMs: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("AUTH_REQUIRED");

    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    if (!user) throw new Error("USER_NOT_FOUND");

    if (user.role === "studio") {
      return {
        role: "studio" as const,
        studioJobs: await getStudioJobsForStudio(ctx, user._id),
        instructorClaims: [],
      };
    }

    return {
      role: "instructor" as const,
      studioJobs: [],
      instructorClaims: await getClaimsForInstructorForMyJobs(
        ctx,
        user._id,
        args,
      ),
    };
  },
});

const getMyJobsInternal = internalQuery({
  args: {
    userId: v.id("users"),
    windowStartMs: v.optional(v.number()),
    windowEndMs: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) return { role: "unknown", studioJobs: [], instructorClaims: [] };
    if (user.role === "studio") {
      return {
        role: "studio" as const,
        studioJobs: await getStudioJobsForStudio(ctx, user._id),
        instructorClaims: [],
      };
    }
    return {
      role: "instructor" as const,
      studioJobs: [],
      instructorClaims: await getClaimsForInstructorForMyJobs(
        ctx,
        user._id,
        args,
      ),
    };
  },
});

const getStudioJobsForStudioInternal = internalQuery({
  args: {
    studioId: v.id("users"),
  },
  handler: async (ctx, { studioId }) => {
    const studio = await ctx.db.get(studioId);
    if (!studio || studio.role !== "studio") return [];
    return await getStudioJobsForStudio(ctx, studioId);
  },
});

// ==========================================
// MUTATIONS
// ==========================================

const postJob = mutation({
  args: {
    title: v.string(),
    description: v.optional(v.string()),
    category: v.string(),
    startTime: v.number(),
    endTime: v.number(),
    baseRate: v.optional(v.float64()),
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

    const baseRate =
      args.baseRate ??
      user.studioPricing?.defaultBaseRate ??
      DEFAULT_STUDIO_BASE_RATE;
    if (!baseRate || baseRate <= 0) {
      throw new Error("BASE_RATE_REQUIRED");
    }

    // SOS detection drives priority queue; pricing boost can be configured.
    const isSOS = hoursUntilStart < 3 && hoursUntilStart > 0;
    const configuredBoost = computeLeadTimeBoostPercent(
      hoursUntilStart,
      user.studioPricing?.leadTimeSurgeRules,
    );
    const fallbackSosBoost = isSOS ? 15 : 0;
    const sosBoostPercentage = configuredBoost || fallbackSosBoost;
    const currentRate = baseRate * (1 + sosBoostPercentage / 100);

    const durationMinutes = Math.round(
      (args.endTime - args.startTime) / (1000 * 60),
    );
    let zoneId: Id<"zones"> | undefined;
    try {
      // Bound zone detection latency so posting never blocks on polygon scans.
      const detectedOrTimeout = await Promise.race<
        Id<"zones"> | null | "__timeout__"
      >([
        ctx.runQuery(internal.zones.detectZoneForLocation, {
          lat: args.latitude,
          lng: args.longitude,
        }),
        new Promise<"__timeout__">((resolve) => {
          setTimeout(() => resolve("__timeout__"), 1200);
        }),
      ]);
      zoneId =
        detectedOrTimeout && detectedOrTimeout !== "__timeout__"
          ? detectedOrTimeout
          : undefined;
    } catch (error) {
      // Do not block posting on zone detection latency; geospatial dispatch still
      // works from the job coordinates and we can backfill zone assignments later.
      console.warn(
        `[postJob] Zone detection failed for studio ${user._id}, continuing without zoneId`,
        error,
      );
    }

    const jobId = await ctx.db.insert("jobs", {
      studioId: user._id,
      title: args.title,
      description: args.description,
      category: args.category,
      startTime: args.startTime,
      endTime: args.endTime,
      durationMinutes,
      baseRate,
      currentRate,
      sosBoostApplied: sosBoostPercentage > 0,
      sosBoostPercentage: sosBoostPercentage > 0 ? sosBoostPercentage : undefined,
      latitude: args.latitude,
      longitude: args.longitude,
      address: args.address,
      zoneId,
      status: "open",
      requiresVerification: args.requiresVerification ?? false,
      notificationsSent: false,
      createdAt: now,
      updatedAt: now,
    });

    // 2026 GEOSPATIAL SYNC
    // ==========================================
    try {
      await syncJobLocation(
        ctx,
        jobId,
        { latitude: args.latitude, longitude: args.longitude },
        args.category,
        "open",
        args.requiresVerification ?? false,
        currentRate,
      );
    } catch (error) {
      // Geospatial indexing is best-effort. A transient geo failure should not
      // block posting or hide the job from studio dashboards.
      console.warn(
        `[postJob] Geospatial sync failed for job ${jobId}, continuing`,
        error,
      );
    }
    try {
      await syncJobReadModels(ctx as any, jobId);
    } catch (error) {
      // Read-model sync is best-effort. Canonical studio reads use jobs table.
      console.warn(
        `[postJob] Read-model sync failed for job ${jobId}, continuing`,
        error,
      );
    }

    if (!zoneId) {
      try {
        await ctx.scheduler.runAfter(0, internal.zones.backfillJobZoneForPostedJob, {
          jobId,
        });
      } catch (error) {
        console.warn(
          `[postJob] Failed to schedule zone backfill for job ${jobId}`,
          error,
        );
      }
    }

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
    try {
      await scheduleJobDispatch(ctx, jobId);
    } catch (error) {
      console.warn(
        `[postJob] Failed to schedule dispatch for job ${jobId}`,
        error,
      );
    }

    try {
      await ctx.runMutation(internal.events.emitDomainEvent, {
        aggregateType: "job",
        aggregateId: jobId,
        eventType: "job.posted",
        source: "mutation",
        actorUserId: user._id,
        payload: {
          studioId: user._id,
          category: args.category,
          startTime: args.startTime,
          endTime: args.endTime,
          currentRate,
          isSOS,
        },
        occurredAt: now,
      });
    } catch (error) {
      console.warn(`[postJob] Failed to emit domain event for job ${jobId}`, error);
    }

    return jobId;
  },
});

// ==========================================
// CONFIGURATION
// ==========================================
const MVP_SKIP_CERTIFICATION = process.env.MVP_SKIP_CERTIFICATION === "true";
const MAX_RADIUS_KM = 15;
const CLAIM_RESPONSE_TIMEOUT_MS = 2 * 60 * 1000;
const DISPATCH_MAX_RETRIES = 4;
const DISPATCH_BASE_DELAY_MS = 2 * 1000;
const DISPATCH_MAX_DELAY_MS = 60 * 1000;
const DEFAULT_STUDIO_BASE_RATE = 120;
const MAX_MY_JOBS_CLAIMS = 250;

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

  await ctx.scheduler.runAfter(
    0,
    internal.notifications.dispatchJobNotifications,
    {
      jobId,
      dispatchVersion: nextVersion,
    },
  );
}

async function recordIdempotentMutationIfMissing(
  ctx: { db: any },
  record: {
    key: string;
    operation: "claimJob" | "withdrawClaim";
    idempotencyKey: string;
    userId: Id<"users">;
    jobId: Id<"jobs">;
    resultClaimId?: Id<"claims">;
    resultRole?: "primary" | "backup";
  },
) {
  const existing = await ctx.db
    .query("mutationIdempotency")
    .withIndex("by_key", (q: any) => q.eq("key", record.key))
    .first();
  if (existing) return;

  await ctx.db.insert("mutationIdempotency", {
    ...record,
    createdAt: Date.now(),
    updatedAt: Date.now(),
  });
}

async function applyClaimJobByInstructor(
  ctx: { db: any; scheduler: any },
  args: {
    jobId: Id<"jobs">;
    instructor: any;
    message?: string;
    idempotencyKey?: string;
  },
) {
  const user = args.instructor;
  const normalizedIdempotencyKey = normalizeIdempotencyKey(args.idempotencyKey);
  const mutationKey = normalizedIdempotencyKey
    ? buildMutationIdempotencyKey(
        "claimJob",
        user._id,
        args.jobId,
        normalizedIdempotencyKey,
      )
    : undefined;
  if (mutationKey) {
    const existing = await ctx.db
      .query("mutationIdempotency")
      .withIndex("by_key", (q: any) => q.eq("key", mutationKey))
      .first();
    if (existing?.resultClaimId && existing?.resultRole) {
      return {
        claimId: existing.resultClaimId,
        role: existing.resultRole as "primary" | "backup",
      };
    }
  }

  const job = await ctx.db.get(args.jobId);
  if (!job) throw new Error("Job not found");

  const isZoneMode = user.dispatchMode === "zone";
  if (!isZoneMode && (!user.latitude || !user.longitude || !user.radiusKm)) {
    throw new Error(
      "Complete your profile location and radius before claiming jobs",
    );
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
    distanceKm =
      Math.round(
        haversineDistanceKm(
          user.latitude!,
          user.longitude!,
          job.latitude,
          job.longitude,
        ) * 100,
      ) / 100;

    if (distanceKm > radiusKm) {
      throw new Error("Job is outside your search radius");
    }
  }

  const now = Date.now();

  if (job.status === "open") {
    if (
      !MVP_SKIP_CERTIFICATION &&
      job.requiresVerification &&
      !user.isVerified
    ) {
      throw new Error("This job requires a verified instructor");
    }

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

    await removeJobLocation(ctx as any, args.jobId);
    await syncJobReadModels(ctx as any, args.jobId);

    await ctx.scheduler.runAfter(
      0,
      internal.notifications.notifyStudioOfClaim,
      {
        jobId: args.jobId,
        claimId,
      },
    );

    if (mutationKey && normalizedIdempotencyKey) {
      await recordIdempotentMutationIfMissing(ctx, {
        key: mutationKey,
        operation: "claimJob",
        idempotencyKey: normalizedIdempotencyKey,
        userId: user._id,
        jobId: args.jobId,
        resultClaimId: claimId,
        resultRole: "primary",
      });
    }

    return { claimId, role: "primary" as const };
  }

  if (job.status === "claimed" && job.claimedBy !== user._id) {
    if (job.backupClaimedBy) {
      throw new Error("Job already has a backup instructor");
    }

    if (
      !MVP_SKIP_CERTIFICATION &&
      job.requiresVerification &&
      !user.isVerified
    ) {
      throw new Error("This job requires a verified instructor");
    }

    const backupClaimId = await ctx.db.insert("claims", {
      jobId: args.jobId,
      instructorId: user._id,
      status: "pending",
      distanceKm,
      message: args.message,
      createdAt: now,
    });

    await ctx.db.patch(args.jobId, {
      status: "backup_claimed",
      backupClaimedBy: user._id,
      backupClaimedAt: now,
      updatedAt: now,
    });
    await syncJobReadModels(ctx as any, args.jobId);

    await ctx.scheduler.runAfter(
      0,
      internal.notifications.notifyStudioOfBackupClaim,
      {
        jobId: args.jobId,
        backupClaimId,
        primaryInstructorId: job.claimedBy!,
        backupInstructorId: user._id,
      },
    );

    if (mutationKey && normalizedIdempotencyKey) {
      await recordIdempotentMutationIfMissing(ctx, {
        key: mutationKey,
        operation: "claimJob",
        idempotencyKey: normalizedIdempotencyKey,
        userId: user._id,
        jobId: args.jobId,
        resultClaimId: backupClaimId,
        resultRole: "backup",
      });
    }

    return { claimId: backupClaimId, role: "backup" as const };
  }

  throw new Error("Job is no longer available");
}

async function applyWithdrawClaimByInstructorWithIdempotency(
  ctx: { db: any; scheduler: any },
  args: {
    jobId: Id<"jobs">;
    instructorId: Id<"users">;
    idempotencyKey?: string;
  },
) {
  const normalizedIdempotencyKey = normalizeIdempotencyKey(args.idempotencyKey);
  const mutationKey = normalizedIdempotencyKey
    ? buildMutationIdempotencyKey(
        "withdrawClaim",
        args.instructorId,
        args.jobId,
        normalizedIdempotencyKey,
      )
    : undefined;
  if (mutationKey) {
    const existing = await ctx.db
      .query("mutationIdempotency")
      .withIndex("by_key", (q: any) => q.eq("key", mutationKey))
      .first();
    if (existing) return;
  }

  await applyWithdrawClaimByJobAndInstructor(
    ctx,
    args.jobId,
    args.instructorId,
  );

  if (mutationKey && normalizedIdempotencyKey) {
    await recordIdempotentMutationIfMissing(ctx, {
      key: mutationKey,
      operation: "withdrawClaim",
      idempotencyKey: normalizedIdempotencyKey,
      userId: args.instructorId,
      jobId: args.jobId,
    });
  }
}

const claimJob = mutation({
  args: {
    jobId: v.id("jobs"),
    message: v.optional(v.string()),
    idempotencyKey: v.optional(v.string()),
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
    return await applyClaimJobByInstructor(ctx, {
      jobId: args.jobId,
      instructor: user,
      message: args.message,
      idempotencyKey: args.idempotencyKey,
    });
  },
});

const claimJobInternalByInstructor = internalMutation({
  args: {
    jobId: v.id("jobs"),
    instructorId: v.id("users"),
    message: v.optional(v.string()),
    idempotencyKey: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.instructorId);
    if (!user || user.role !== "instructor") {
      throw new Error("Only instructors can claim jobs");
    }

    return await applyClaimJobByInstructor(ctx, {
      jobId: args.jobId,
      instructor: user,
      message: args.message,
      idempotencyKey: args.idempotencyKey,
    });
  },
});

const withdrawClaim = mutation({
  args: {
    jobId: v.id("jobs"),
    idempotencyKey: v.optional(v.string()),
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
    await applyWithdrawClaimByInstructorWithIdempotency(ctx, {
      jobId: args.jobId,
      instructorId: user._id,
      idempotencyKey: args.idempotencyKey,
    });
  },
});

const withdrawClaimInternalByJobAndInstructor = internalMutation({
  args: {
    jobId: v.id("jobs"),
    instructorId: v.id("users"),
  },
  handler: async (ctx, args) => {
    await applyWithdrawClaimByJobAndInstructor(
      ctx,
      args.jobId,
      args.instructorId,
    );
  },
});

const withdrawClaimInternalByJobAndInstructorIdempotent =
  internalMutation({
    args: {
      jobId: v.id("jobs"),
      instructorId: v.id("users"),
      idempotencyKey: v.optional(v.string()),
    },
    handler: async (ctx, args) => {
      await applyWithdrawClaimByInstructorWithIdempotency(ctx, {
        jobId: args.jobId,
        instructorId: args.instructorId,
        idempotencyKey: args.idempotencyKey,
      });
    },
  });
const respondToClaim = mutation({
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

const respondToClaimInternal = internalMutation({
  args: {
    claimId: v.id("claims"),
    accept: v.boolean(),
  },
  handler: async (ctx, args) => {
    await applyRespondToClaim(ctx, args.claimId, args.accept);
  },
});

const cancelJob = mutation({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    if (!user) throw new Error("User not found");

    await applyCancelJobByStudio(ctx, jobId, user._id);
  },
});

const completeJob = mutation({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    if (!user) throw new Error("User not found");

    await applyCompleteJobByStudio(ctx, jobId, user._id);
    return { success: true };
  },
});

const completeJobInternalByStudio = internalMutation({
  args: {
    jobId: v.id("jobs"),
    studioId: v.id("users"),
  },
  handler: async (ctx, args) => {
    await applyCompleteJobByStudio(ctx, args.jobId, args.studioId);
    return { success: true };
  },
});

const submitRating = mutation({
  args: {
    jobId: v.id("jobs"),
    toUserId: v.id("users"),
    rating: v.float64(),
    comment: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    if (!Number.isFinite(args.rating) || args.rating < 1 || args.rating > 5) {
      throw new Error("rating must be between 1 and 5");
    }

    const fromUser = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    if (!fromUser) throw new Error("User not found");

    const job = await ctx.db.get(args.jobId);
    if (!job) throw new Error("Job not found");
    if (job.status !== "completed") {
      throw new Error("Can only rate completed jobs");
    }

    const isStudioRater = fromUser._id === job.studioId;
    const isInstructorRater = fromUser._id === job.claimedBy;
    if (!isStudioRater && !isInstructorRater) {
      throw new Error("Only the studio or confirmed instructor can rate this job");
    }

    const expectedToUserId = isStudioRater ? job.claimedBy : job.studioId;
    if (!expectedToUserId || expectedToUserId !== args.toUserId) {
      throw new Error("Invalid rating target for this job");
    }

    const existingForJob = await ctx.db
      .query("ratings")
      .withIndex("by_job", (q) => q.eq("jobId", args.jobId))
      .collect();
    const duplicate = existingForJob.find(
      (row) => row.fromUserId === fromUser._id && row.toUserId === args.toUserId,
    );
    if (duplicate) {
      throw new Error("Rating already submitted for this job");
    }

    const now = Date.now();
    const ratingId = await ctx.db.insert("ratings", {
      jobId: args.jobId,
      fromUserId: fromUser._id,
      toUserId: args.toUserId,
      rating: args.rating,
      comment: args.comment?.trim() ? args.comment.trim() : undefined,
      createdAt: now,
    });

    const targetUser = await ctx.db.get(args.toUserId);
    if (targetUser) {
      const prevCount = targetUser.ratingCount ?? 0;
      const prevAvg = targetUser.rating ?? 0;
      const nextCount = prevCount + 1;
      const nextAvg = (prevAvg * prevCount + args.rating) / nextCount;
      await ctx.db.patch(targetUser._id, {
        rating: Number(nextAvg.toFixed(2)),
        ratingCount: nextCount,
        updatedAt: now,
      });
    }

    await ctx.runMutation(internal.events.emitDomainEvent, {
      aggregateType: "job",
      aggregateId: args.jobId,
      eventType: "job.rating_submitted",
      source: "mutation",
      actorUserId: fromUser._id,
      payload: {
        toUserId: args.toUserId,
        rating: args.rating,
      },
      occurredAt: now,
    });

    return { ratingId };
  },
});

const cancelJobInternalByStudio = internalMutation({
  args: {
    jobId: v.id("jobs"),
    studioId: v.id("users"),
  },
  handler: async (ctx, args) => {
    await applyCancelJobByStudio(ctx, args.jobId, args.studioId);
  },
});

async function applyCompleteJobByStudio(
  ctx: { db: any; runMutation: any },
  jobId: Id<"jobs">,
  studioId: Id<"users">,
) {
  const job = await ctx.db.get(jobId);
  if (!job) throw new Error("Job not found");
  if (job.studioId !== studioId) {
    throw new Error("Only the studio owner can complete jobs");
  }
  if (job.status !== "confirmed") {
    throw new Error("Only confirmed jobs can be completed");
  }
  if (!job.claimedBy) {
    throw new Error("Cannot complete job without a confirmed instructor");
  }
  if (job.endTime > Date.now()) {
    throw new Error("Cannot complete job before end time");
  }

  const acceptedClaim = await ctx.db
    .query("claims")
    .withIndex("by_job_status_instructor", (q: any) =>
      q.eq("jobId", jobId).eq("status", "accepted").eq("instructorId", job.claimedBy),
    )
    .first();
  if (!acceptedClaim) {
    throw new Error("Cannot complete job without accepted claim");
  }

  const now = Date.now();
  await ctx.db.patch(jobId, {
    status: "completed",
    updatedAt: now,
  });
  await syncJobReadModels(ctx as any, jobId);

  await ctx.runMutation(internal.events.emitDomainEvent, {
    aggregateType: "job",
    aggregateId: jobId,
    eventType: "job.completed",
    source: "mutation",
    actorUserId: studioId,
    payload: {
      instructorId: job.claimedBy,
      confirmedAt: job.confirmedAt,
      endTime: job.endTime,
    },
    occurredAt: now,
  });
}

async function applyCancelJobByStudio(
  ctx: { db: any; scheduler: any },
  jobId: Id<"jobs">,
  studioId: Id<"users">,
) {
  const job = await ctx.db.get(jobId);
  if (!job) throw new Error("Job not found");
  if (job.studioId !== studioId) {
    throw new Error("Only the studio owner can cancel jobs");
  }

  const now = Date.now();

  await ctx.db.patch(jobId, {
    status: "cancelled",
    updatedAt: now,
  });

  const pendingClaims = await ctx.db
    .query("claims")
    .withIndex("by_job_status", (q: any) =>
      q.eq("jobId", jobId).eq("status", "pending"),
    )
    .collect();
  for (const pendingClaim of pendingClaims) {
    await ctx.db.patch(pendingClaim._id, {
      status: "rejected",
      respondedAt: now,
    });
  }

  const acceptedClaims = await ctx.db
    .query("claims")
    .withIndex("by_job_status", (q: any) =>
      q.eq("jobId", jobId).eq("status", "accepted"),
    )
    .collect();
  for (const acceptedClaim of acceptedClaims) {
    await ctx.db.patch(acceptedClaim._id, {
      status: "rejected",
      respondedAt: now,
    });
  }
  await syncJobReadModels(ctx as any, jobId);

  await removeJobLocation(ctx as any, jobId);

  if (job.claimedBy) {
    await ctx.scheduler.runAfter(0, internal.notifications.notifyJobCancelled, {
      jobId,
      instructorId: job.claimedBy,
    });
  }
  if (job.backupClaimedBy && job.backupClaimedBy !== job.claimedBy) {
    await ctx.scheduler.runAfter(0, internal.notifications.notifyJobCancelled, {
      jobId,
      instructorId: job.backupClaimedBy,
    });
  }
}

async function applyWithdrawClaimByJobAndInstructor(
  ctx: { db: any; scheduler: any },
  jobId: Id<"jobs">,
  instructorId: Id<"users">,
) {
  const job = await ctx.db.get(jobId);
  if (!job) throw new Error("Job not found");

  const claim = await ctx.db
    .query("claims")
    .withIndex("by_job_status_instructor", (q: any) =>
      q
        .eq("jobId", jobId)
        .eq("status", "pending")
        .eq("instructorId", instructorId),
    )
    .first();

  if (!claim) throw new Error("No pending claim found to withdraw");

  const now = Date.now();

  await ctx.db.patch(claim._id, {
    status: "withdrawn",
    respondedAt: now,
  });

  if (job.claimedBy === instructorId) {
    if (job.backupClaimedBy) {
      const promotedBackupClaim = await ctx.db
        .query("claims")
        .withIndex("by_job_status_instructor", (q: any) =>
          q
            .eq("jobId", jobId)
            .eq("status", "pending")
            .eq("instructorId", job.backupClaimedBy),
        )
        .first();

      if (!promotedBackupClaim) {
        await ctx.db.patch(jobId, {
          status: "open",
          claimedBy: undefined,
          claimedAt: undefined,
          backupClaimedBy: undefined,
          backupClaimedAt: undefined,
          backupAutoPromoted: undefined,
          updatedAt: now,
        });

        await syncJobLocation(
          ctx as any,
          jobId,
          { latitude: job.latitude, longitude: job.longitude },
          job.category,
          "open",
          job.requiresVerification,
          job.currentRate,
        );
        await syncJobReadModels(ctx as any, jobId);

        await scheduleJobDispatch(ctx, jobId);
        return;
      }

      await ctx.db.patch(promotedBackupClaim._id, {
        status: "accepted",
        respondedAt: now,
      });

      await ctx.db.patch(jobId, {
        status: "claimed",
        claimedBy: job.backupClaimedBy,
        claimedAt: job.backupClaimedAt,
        backupClaimedBy: undefined,
        backupClaimedAt: undefined,
        backupAutoPromoted: true,
        updatedAt: now,
      });
      await syncJobReadModels(ctx as any, jobId);

      await ctx.scheduler.runAfter(
        0,
        internal.notifications.notifyBackupPromoted,
        {
          jobId,
          newPrimaryInstructorId: job.backupClaimedBy,
        },
      );

      console.log(
        `[withdrawClaim] Backup ${job.backupClaimedBy} auto-promoted to primary for job ${jobId}`,
      );
      return;
    }

    await ctx.db.patch(jobId, {
      status: "open",
      claimedBy: undefined,
      claimedAt: undefined,
      updatedAt: now,
    });

    // 2026 GEOSPATIAL RE-ADD
    await syncJobLocation(
      ctx as any, // Cast to MutationCtx for geo component compatibility
      jobId,
      { latitude: job.latitude, longitude: job.longitude },
      job.category,
      "open",
      job.requiresVerification,
      job.currentRate,
    );
    await syncJobReadModels(ctx as any, jobId);

    await scheduleJobDispatch(ctx, jobId);
    return;
  }

  if (job.backupClaimedBy === instructorId) {
    await ctx.db.patch(jobId, {
      status: "claimed",
      backupClaimedBy: undefined,
      backupClaimedAt: undefined,
      updatedAt: now,
    });
    await syncJobReadModels(ctx as any, jobId);
  }
}

async function applyRespondToClaim(
  ctx: { db: any; scheduler: any },
  claimId: any,
  accept: boolean,
) {
  const claim = await ctx.db.get(claimId);
  if (!claim) throw new Error("Claim not found");

  const job = await ctx.db.get(claim.jobId);
  if (!job) throw new Error("Job not found");

  if (claim.status !== "pending") {
    throw new Error("Claim is no longer pending");
  }

  if (job.status !== "claimed" && job.status !== "backup_claimed") {
    throw new Error("Job is not in a claim-response state");
  }

  const isActiveClaimSlot =
    job.claimedBy === claim.instructorId ||
    job.backupClaimedBy === claim.instructorId;
  if (!isActiveClaimSlot) {
    throw new Error("Claim is not active for this job");
  }

  const now = Date.now();

  if (accept) {
    const acceptedClaimedAt =
      job.claimedBy === claim.instructorId
        ? (job.claimedAt ?? claim.createdAt ?? now)
        : job.backupClaimedBy === claim.instructorId
          ? (job.backupClaimedAt ?? claim.createdAt ?? now)
          : (claim.createdAt ?? now);

    await ctx.db.patch(claimId, {
      status: "accepted",
      respondedAt: now,
    });

    await ctx.db.patch(claim.jobId, {
      status: "confirmed",
      claimedBy: claim.instructorId,
      claimedAt: acceptedClaimedAt,
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
      await ctx.scheduler.runAfter(
        0,
        internal.notifications.notifyClaimRejected,
        {
          claimId: other._id,
        },
      );
    }
    await syncJobReadModels(ctx as any, claim.jobId);

    await ctx.scheduler.runAfter(
      0,
      internal.notifications.notifyClaimAccepted,
      {
        claimId,
      },
    );
    return;
  }

  await ctx.db.patch(claimId, {
    status: "rejected",
    respondedAt: now,
  });

  if (job.claimedBy === claim.instructorId && job.backupClaimedBy) {
    const promotedBackupClaim = await ctx.db
      .query("claims")
      .withIndex("by_job_status_instructor", (q: any) =>
        q
          .eq("jobId", claim.jobId)
          .eq("status", "pending")
          .eq("instructorId", job.backupClaimedBy),
      )
      .first();

    if (promotedBackupClaim) {
      await ctx.db.patch(promotedBackupClaim._id, {
        status: "accepted",
        respondedAt: now,
      });

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
      await syncJobReadModels(ctx as any, claim.jobId);

      await ctx.scheduler.runAfter(
        0,
        internal.notifications.notifyBackupPromoted,
        {
          jobId: claim.jobId,
          newPrimaryInstructorId: job.backupClaimedBy,
        },
      );
    } else {
      await ctx.db.patch(claim.jobId, {
        status: "open",
        claimedBy: undefined,
        claimedAt: undefined,
        backupClaimedBy: undefined,
        backupClaimedAt: undefined,
        backupAutoPromoted: undefined,
        updatedAt: now,
      });

      await syncJobLocation(
        ctx as any,
        claim.jobId,
        { latitude: job.latitude, longitude: job.longitude },
        job.category,
        "open",
        job.requiresVerification,
        job.currentRate,
      );
      await syncJobReadModels(ctx as any, claim.jobId);

      await scheduleJobDispatch(ctx, claim.jobId);
    }
  } else if (job.claimedBy === claim.instructorId) {
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
      job.currentRate,
    );
    await syncJobReadModels(ctx as any, claim.jobId);

    await scheduleJobDispatch(ctx, claim.jobId);
  } else if (job.backupClaimedBy === claim.instructorId) {
    await ctx.db.patch(claim.jobId, {
      status: "claimed",
      backupClaimedBy: undefined,
      backupClaimedAt: undefined,
      backupAutoPromoted: undefined,
      updatedAt: now,
    });
    await syncJobReadModels(ctx as any, claim.jobId);
  }

  await ctx.scheduler.runAfter(0, internal.notifications.notifyClaimRejected, {
    claimId,
  });
}

/**
 * Expire stale claims and reopen jobs.
 * Runs on a cron (see convex/crons.ts).
 */
const expireStaleClaims = internalMutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    const cutoff = now - CLAIM_RESPONSE_TIMEOUT_MS;

    let expiredCount = 0;
    const statuses: Array<"claimed" | "backup_claimed"> = [
      "claimed",
      "backup_claimed",
    ];

    for (const status of statuses) {
      const staleJobs = await ctx.db
        .query("jobs")
        .withIndex("by_status_claimedAt", (q) =>
          q.eq("status", status).lt("claimedAt", cutoff),
        )
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
          current.currentRate,
        );

        await scheduleJobDispatch(ctx, current._id);

        // Reject any pending claims for this job
        const pendingClaims = await ctx.db
          .query("claims")
          .withIndex("by_job_status", (q) =>
            q.eq("jobId", current._id).eq("status", "pending"),
          )
          .collect();
        for (const claim of pendingClaims) {
          await ctx.db.patch(claim._id, {
            status: "rejected",
            respondedAt: now,
          });
        }
        await syncJobReadModels(ctx as any, current._id);

        expiredCount++;
      }
    }

    return { expiredCount };
  },
});

const rebuildJobReadModels = internalMutation({
  args: {
    limit: v.optional(v.number()),
  },
  handler: async (ctx, { limit }) => {
    const safeLimit = Math.max(1, Math.min(limit ?? 300, 1000));
    const jobs = await ctx.db.query("jobs").order("desc").take(safeLimit);
    for (const job of jobs) {
      await syncJobReadModels(ctx as any, job._id);
    }
    return { synced: jobs.length };
  },
});

const scheduleDispatchRetry = internalMutation({
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
      DISPATCH_MAX_DELAY_MS,
    );
    const now = Date.now();

    await ctx.db.patch(jobId, {
      dispatchAttempt: attempt,
      dispatchLastError: error,
      dispatchScheduledAt: now + delay,
      updatedAt: now,
    });

    await ctx.scheduler.runAfter(
      delay,
      internal.notifications.dispatchJobNotifications,
      {
        jobId,
        dispatchVersion,
      },
    );

    return { scheduled: true, attempt, delay };
  },
});

const markNotified = internalMutation({
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

const jobsCore = {
  CATEGORIES,
  getJobInternal,
  getJobById,
  getNearbyJobs,
  getJobsForMap,
  getZoneJobsForInstructor,
  getInstructorStats,
  getStudioJobs,
  getMyJobs,
  getMyJobsInternal,
  getStudioJobsForStudioInternal,
  postJob,
  claimJob,
  claimJobInternalByInstructor,
  withdrawClaim,
  withdrawClaimInternalByJobAndInstructor,
  withdrawClaimInternalByJobAndInstructorIdempotent,
  respondToClaim,
  respondToClaimInternal,
  cancelJob,
  completeJob,
  completeJobInternalByStudio,
  submitRating,
  cancelJobInternalByStudio,
  expireStaleClaims,
  rebuildJobReadModels,
  scheduleDispatchRetry,
  markNotified,
};

export default jobsCore;

