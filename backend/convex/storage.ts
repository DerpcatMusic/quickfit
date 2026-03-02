// convex/storage.ts
// File storage for certificate uploads

import { mutation, query, internalQuery } from "./_generated/server";
import { v } from "convex/values";

const UPLOAD_SESSION_TTL_MS = 15 * 60 * 1000;

/**
 * Generate a signed URL for uploading a file to Convex storage.
 * Returns a URL that the client can POST to.
 */
export const generateUploadUrl = mutation({
  args: {
    purpose: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    if (!user) throw new Error("User not found");

    const uploadUrl = await ctx.storage.generateUploadUrl();
    const now = Date.now();
    const uploadToken = `${now}_${Math.random().toString(36).slice(2)}${Math.random()
      .toString(36)
      .slice(2)}`;

    await ctx.db.insert("uploadSessions", {
      token: uploadToken,
      userId: user._id,
      purpose: args.purpose,
      expiresAt: now + UPLOAD_SESSION_TTL_MS,
      createdAt: now,
    });

    return {
      uploadUrl,
      uploadToken,
    };
  },
});

/**
 * Get the URL for viewing a stored file.
 * Takes a storageId and returns a signed URL.
 */
export const getUrl = query({
  args: { storageId: v.id("_storage") },
  handler: async (ctx, { storageId }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    if (!user) throw new Error("User not found");

    const owner = await ctx.db
      .query("userFiles")
      .withIndex("by_storage", (q) => q.eq("storageId", storageId))
      .first();
    if (!owner || owner.userId !== user._id) {
      throw new Error("Unauthorized");
    }

    // Get signed URL for viewing
    return await ctx.storage.getUrl(storageId);
  },
});

/**
 * Register ownership of an uploaded storage object.
 * Must be called by the uploader after upload.
 */
export const registerUploadedFile = mutation({
  args: {
    storageId: v.id("_storage"),
    uploadToken: v.string(),
    purpose: v.optional(v.string()),
  },
  handler: async (ctx, { storageId, uploadToken, purpose }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    if (!user) throw new Error("User not found");

    const session = await ctx.db
      .query("uploadSessions")
      .withIndex("by_token", (q) => q.eq("token", uploadToken))
      .first();
    if (!session) throw new Error("Invalid upload token");
    if (session.userId !== user._id) throw new Error("Upload token owner mismatch");
    if (session.expiresAt <= Date.now()) throw new Error("Upload token expired");
    if (session.purpose && purpose && session.purpose !== purpose) {
      throw new Error("Upload purpose mismatch");
    }
    if (session.usedAt && session.storageId && session.storageId !== storageId) {
      throw new Error("Upload token already used");
    }

    const existing = await ctx.db
      .query("userFiles")
      .withIndex("by_storage", (q) => q.eq("storageId", storageId))
      .first();

    if (existing) {
      if (existing.userId !== user._id) {
        throw new Error("Storage object already owned by another user");
      }
      if (!session.usedAt) {
        await ctx.db.patch(session._id, {
          usedAt: Date.now(),
          storageId,
        });
      }
      return existing._id;
    }

    const recordId = await ctx.db.insert("userFiles", {
      userId: user._id,
      storageId,
      purpose,
      createdAt: Date.now(),
    });

    await ctx.db.patch(session._id, {
      usedAt: Date.now(),
      storageId,
    });

    return recordId;
  },
});

export const getFileOwnerByStorageIdInternal = internalQuery({
  args: {
    storageId: v.id("_storage"),
  },
  handler: async (ctx, { storageId }) => {
    return await ctx.db
      .query("userFiles")
      .withIndex("by_storage", (q) => q.eq("storageId", storageId))
      .first();
  },
});

/**
 * Delete a stored file.
 */
export const deleteFile = mutation({
  args: { storageId: v.id("_storage") },
  handler: async (ctx, { storageId }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    // Verify ownership before deletion
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();

    if (!user) throw new Error("User not found");

    const owner = await ctx.db
      .query("userFiles")
      .withIndex("by_storage", (q) => q.eq("storageId", storageId))
      .first();

    if (!owner || owner.userId !== user._id) {
      throw new Error("Unauthorized");
    }

    // Delete the file and ownership record
    await ctx.storage.delete(storageId);
    await ctx.db.delete(owner._id);
    return true;
  },
});
