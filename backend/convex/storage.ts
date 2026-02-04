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
  args: { storageId: v.string() },
  handler: async (ctx, { storageId }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    // Get signed URL for viewing
    return await ctx.storage.getUrl(storageId);
  },
});

/**
 * Delete a stored file.
 */
export const deleteFile = mutation({
  args: { storageId: v.string() },
  handler: async (ctx, { storageId }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    // Verify ownership before deletion
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();

    if (!user) throw new Error("User not found");

    // Delete the file
    await ctx.storage.delete(storageId);
    return true;
  },
});
