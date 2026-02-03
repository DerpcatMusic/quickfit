// convex/verifications.ts
// Certificate verification queries and mutations

import { query, mutation, internalQuery, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";

// ==========================================
// QUERIES
// ==========================================

export const getById = internalQuery({
  args: { verificationId: v.id("verifications") },
  handler: async (ctx, { verificationId }) => {
    return await ctx.db.get(verificationId);
  },
});

export const getMyVerifications = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user) return [];
    
    return await ctx.db
      .query("verifications")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .order("desc")
      .collect();
  },
});

export const getPendingReview = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];
    
    // TODO: Add admin check
    
    return await ctx.db
      .query("verifications")
      .withIndex("by_status", (q) => q.eq("status", "manual_review"))
      .order("desc")
      .take(50);
  },
});

// ==========================================
// MUTATIONS
// ==========================================

export const uploadCertificate = mutation({
  args: {
    docUrl: v.string(),
    docType: v.string(),
    originalFilename: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user) throw new Error("User not found");
    if (user.role !== "instructor") throw new Error("Only instructors can upload certificates");
    
    const verificationId = await ctx.db.insert("verifications", {
      userId: user._id,
      docUrl: args.docUrl,
      docType: args.docType,
      originalFilename: args.originalFilename,
      status: "pending",
      createdAt: Date.now(),
    });
    
    // Schedule AI verification
    await ctx.scheduler.runAfter(0, internal.actions.geminiVerify.verifyCertificate, {
      verificationId,
    });
    
    return verificationId;
  },
});

export const updateWithAnalysis = internalMutation({
  args: {
    verificationId: v.id("verifications"),
    aiAnalysis: v.object({
      extractedName: v.string(),
      extractedNameHebrew: v.optional(v.string()),
      nameMatchScore: v.float64(),
      issuingAuthority: v.optional(v.string()),
      certificateNumber: v.optional(v.string()),
      issueDate: v.optional(v.string()),
      expiryDate: v.optional(v.string()),
      isExpired: v.boolean(),
      certificationType: v.optional(v.string()),
      confidence: v.float64(),
      flags: v.array(v.string()),
      recommendation: v.union(
        v.literal("approve"),
        v.literal("review"),
        v.literal("reject")
      ),
    }),
    status: v.union(
      v.literal("verified"),
      v.literal("rejected"),
      v.literal("manual_review")
    ),
  },
  handler: async (ctx, { verificationId, aiAnalysis, status }) => {
    const now = Date.now();
    
    await ctx.db.patch(verificationId, {
      aiAnalysis,
      status,
      processedAt: now,
      verifiedAt: status === "verified" ? now : undefined,
    });
  },
});

export const manualReview = mutation({
  args: {
    verificationId: v.id("verifications"),
    approve: v.boolean(),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    // TODO: Add admin check
    const reviewer = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!reviewer) throw new Error("Reviewer not found");
    
    const verification = await ctx.db.get(args.verificationId);
    if (!verification) throw new Error("Verification not found");
    
    const now = Date.now();
    const status = args.approve ? "verified" : "rejected";
    
    await ctx.db.patch(args.verificationId, {
      status,
      reviewedBy: reviewer._id,
      reviewNotes: args.notes,
      verifiedAt: args.approve ? now : undefined,
    });
    
    // Update user verified status
    if (args.approve) {
      await ctx.db.patch(verification.userId, {
        isVerified: true,
        verifiedAt: now,
        updatedAt: now,
      });
    }
  },
});
