// convex/storage.ts
// File storage for certificate uploads

import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

/**
 * Generate a signed URL for uploading a file to Convex storage.
 * Returns a URL that the client can POST to.
 */
export const generateUploadUrl = mutation({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    // Generate signed URL for upload
    return await ctx.storage.generateUploadUrl();
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
    purpose: v.optional(v.string()),
  },
  handler: async (ctx, { storageId, purpose }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    if (!user) throw new Error("User not found");

    const existing = await ctx.db
      .query("userFiles")
      .withIndex("by_storage", (q) => q.eq("storageId", storageId))
      .first();

    if (existing) {
      if (existing.userId !== user._id) {
        throw new Error("Storage object already owned by another user");
      }
      return existing._id;
    }

    return await ctx.db.insert("userFiles", {
      userId: user._id,
      storageId,
      purpose,
      createdAt: Date.now(),
    });
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
