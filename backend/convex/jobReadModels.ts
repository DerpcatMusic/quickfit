import type { Id } from "./_generated/dataModel";
import type { MutationCtx } from "./_generated/server";

type ReadModelCtx = {
  db: MutationCtx["db"];
};

type ClaimStatus = "pending" | "accepted";

async function findClaimIdForInstructor(
  ctx: ReadModelCtx,
  jobId: Id<"jobs">,
  instructorId: Id<"users">,
  statuses: ClaimStatus[],
) {
  for (const status of statuses) {
    const claim = await ctx.db
      .query("claims")
      .withIndex("by_job_status_instructor", (q) =>
        q
          .eq("jobId", jobId)
          .eq("status", status)
          .eq("instructorId", instructorId),
      )
      .first();
    if (claim) return claim._id;
  }
  return undefined;
}

async function upsertStudioProjection(
  ctx: ReadModelCtx,
  payload: Record<string, unknown>,
  jobId: Id<"jobs">,
) {
  const existing = await ctx.db
    .query("readModel_studioJobs")
    .withIndex("by_job", (q) => q.eq("jobId", jobId))
    .first();
  if (existing) {
    await ctx.db.patch(existing._id, payload);
    return;
  }
  await ctx.db.insert("readModel_studioJobs", payload as any);
}

async function upsertInstructorProjection(
  ctx: ReadModelCtx,
  payload: Record<string, unknown>,
  jobId: Id<"jobs">,
) {
  const existing = await ctx.db
    .query("readModel_instructorFeed")
    .withIndex("by_job", (q) => q.eq("jobId", jobId))
    .first();
  if (existing) {
    await ctx.db.patch(existing._id, payload);
    return;
  }
  await ctx.db.insert("readModel_instructorFeed", payload as any);
}

async function deleteProjectionByJob(
  ctx: ReadModelCtx,
  table: "readModel_studioJobs" | "readModel_instructorFeed",
  jobId: Id<"jobs">,
) {
  const existing = await ctx.db
    .query(table)
    .withIndex("by_job", (q) => q.eq("jobId", jobId))
    .first();
  if (existing) {
    await ctx.db.delete(existing._id);
  }
}

export async function syncJobReadModels(ctx: ReadModelCtx, jobId: Id<"jobs">) {
  const job = await ctx.db.get(jobId);
  if (!job) {
    await deleteProjectionByJob(ctx, "readModel_studioJobs", jobId);
    await deleteProjectionByJob(ctx, "readModel_instructorFeed", jobId);
    return;
  }

  const studio = await ctx.db.get(job.studioId);
  if (!studio) {
    await deleteProjectionByJob(ctx, "readModel_studioJobs", jobId);
    await deleteProjectionByJob(ctx, "readModel_instructorFeed", jobId);
    return;
  }

  const activeInstructorId = job.claimedBy ?? job.backupClaimedBy;
  const claimLookupOrder: ClaimStatus[] =
    job.status === "confirmed" || job.status === "completed"
      ? ["accepted", "pending"]
      : ["pending", "accepted"];
  const claimId = activeInstructorId
    ? await findClaimIdForInstructor(
        ctx,
        job._id,
        activeInstructorId,
        claimLookupOrder,
      )
    : undefined;

  let claimedInstructor: {
    _id: Id<"users">;
    name: string;
    photoUrl?: string;
    avatarUrl?: string;
    rating?: number;
    isVerified: boolean;
  } | null = null;
  if (activeInstructorId) {
    const instructor = await ctx.db.get(activeInstructorId);
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

  await upsertStudioProjection(
    ctx,
    {
      jobId: job._id,
      studioId: job.studioId,
      status: job.status,
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
      requiresVerification: job.requiresVerification,
      claimedBy: job.claimedBy,
      claimedAt: job.claimedAt,
      confirmedAt: job.confirmedAt,
      backupClaimedBy: job.backupClaimedBy,
      backupClaimedAt: job.backupClaimedAt,
      claimId,
      claimedInstructor: claimedInstructor ?? undefined,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
    },
    job._id,
  );

  if (job.status !== "open") {
    await deleteProjectionByJob(ctx, "readModel_instructorFeed", job._id);
    return;
  }

  await upsertInstructorProjection(
    ctx,
    {
      jobId: job._id,
      studioId: job.studioId,
      zoneId: job.zoneId,
      status: job.status,
      title: job.title,
      category: job.category,
      startTime: job.startTime,
      endTime: job.endTime,
      baseRate: job.baseRate,
      currentRate: job.currentRate,
      sosBoostApplied: job.sosBoostApplied,
      sosBoostPercentage: job.sosBoostPercentage,
      address: job.address,
      latitude: job.latitude,
      longitude: job.longitude,
      requiresVerification: job.requiresVerification,
      studioName: studio.businessName ?? studio.name ?? "Studio",
      studioAvatarUrl: studio.avatarUrl,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
    },
    job._id,
  );
}
