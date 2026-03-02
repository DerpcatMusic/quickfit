import type { MutationCtx, QueryCtx } from "../_generated/server";
import type { Doc } from "../_generated/dataModel";
import { ErrorCode, domainError } from "./errors";

type AuthDbCtx = Pick<QueryCtx, "auth" | "db"> | Pick<MutationCtx, "auth" | "db">;

export async function requireIdentitySubject(ctx: AuthDbCtx): Promise<string> {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) {
    throw domainError(ErrorCode.authRequired, "Not authenticated");
  }
  return identity.subject;
}

export async function getCurrentUserByIdentity(
  ctx: AuthDbCtx,
): Promise<Doc<"users"> | null> {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) return null;
  return await ctx.db
    .query("users")
    .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
    .unique();
}

export async function requireCurrentUserByIdentity(
  ctx: AuthDbCtx,
): Promise<Doc<"users">> {
  const user = await getCurrentUserByIdentity(ctx);
  if (!user) {
    throw domainError(ErrorCode.userNotFound, "User not found");
  }
  return user;
}

export async function requireStudioUserByIdentity(
  ctx: AuthDbCtx,
): Promise<Doc<"users">> {
  const user = await requireCurrentUserByIdentity(ctx);
  if (user.role !== "studio") {
    throw domainError(ErrorCode.studioOnly, "Only studios can perform this action");
  }
  return user;
}

