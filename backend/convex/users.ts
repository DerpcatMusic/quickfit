// convex/users.ts
// User queries and mutations

import {
  query,
  mutation,
  internalQuery,
  internalMutation,
} from "./_generated/server";
import { v } from "convex/values";
import { syncInstructorLocation, removeInstructorLocation } from "./geo";
import { internal } from "./_generated/api";
import {
  getCurrentUserByIdentity,
  requireCurrentUserByIdentity,
  requireIdentitySubject,
  requireStudioUserByIdentity,
} from "./lib/auth";
import { normalizeLeadTimeSurgeRules } from "./pricing";

const MIN_RADIUS_KM = 0.1;
const MAX_RADIUS_KM = 15;

// ==========================================
// QUERIES
// ==========================================

export const getCurrentUser = query({
  handler: async (ctx) => {
    return await getCurrentUserByIdentity(ctx);
  },
});

// Sync Firebase user to Convex (called from Flutter after login)
export const syncUser = mutation({
  args: {
    firebaseUid: v.string(),
    email: v.string(),
    name: v.string(),
    photoUrl: v.string(),
  },
  handler: async (ctx, args) => {
    const uid = await requireIdentitySubject(ctx);

    const existing = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", uid))
      .unique();

    const now = Date.now();

    if (existing) {
      // Update existing user
      await ctx.db.patch(existing._id, {
        name: args.name || existing.name,
        email: args.email || existing.email,
        avatarUrl: args.photoUrl || existing.avatarUrl,
        updatedAt: now,
      });
      return existing._id;
    }

    // Create new user (will need to complete onboarding)
    return await ctx.db.insert("users", {
      firebaseUid: uid,
      name: args.name,
      email: args.email,
      avatarUrl: args.photoUrl,
      role: "instructor", // Default role, will be set during onboarding
      hasCompletedOnboarding: false,
      isVerified: false,
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const completeOnboarding = mutation({
  args: {
    role: v.union(v.literal("studio"), v.literal("instructor")),
    name: v.string(),
    categories: v.string(), // comma separated list
    // Dispatch mode for instructors
    dispatchMode: v.optional(v.union(v.literal("radius"), v.literal("zone"))),
    // For radius mode
    radiusKm: v.optional(v.union(v.float64(), v.string())),
    latitude: v.optional(v.union(v.float64(), v.string())),
    longitude: v.optional(v.union(v.float64(), v.string())),
    address: v.optional(v.string()),
    // For zone mode
    zoneIds: v.optional(v.array(v.id("zones"))),
  },
  handler: async (ctx, args) => {
    console.log("[completeOnboarding] Called with args:", JSON.stringify(args));
    const user = await requireCurrentUserByIdentity(ctx);

    const now = Date.now();

    const categoriesArray = args.categories
      .split(",")
      .map((c) => c.trim())
      .filter((c) => c.length > 0);
    const primaryCategory =
      categoriesArray.length > 0 ? categoriesArray[0] : "general";

    // Helper to parse numbers (handles Flutter's string serialization)
    const parseNum = (val: number | string | undefined): number | undefined => {
      if (val === undefined) return undefined;
      const parsed = typeof val === "string" ? parseFloat(val) : val;
      return isNaN(parsed) ? undefined : parsed;
    };

    const lat = parseNum(args.latitude);
    const lng = parseNum(args.longitude);
    const rad = parseNum(args.radiusKm);
    const clampedRadiusKm = Math.min(
      Math.max(rad ?? user.radiusKm ?? 5, MIN_RADIUS_KM),
      MAX_RADIUS_KM,
    );

    // Default dispatch mode based on what data is provided
    const dispatchMode =
      args.dispatchMode ??
      (args.zoneIds && args.zoneIds.length > 0 ? "zone" : "radius");

    await ctx.db.patch(user._id, {
      role: args.role,
      name: args.name,
      categories: categoriesArray,
      primaryCategory,
      dispatchMode: args.role === "instructor" ? dispatchMode : undefined,
      radiusKm: clampedRadiusKm,
      latitude: lat ?? user.latitude,
      longitude: lng ?? user.longitude,
      homeAddress: args.address ?? user.homeAddress ?? user.address,
      address: args.address ?? user.address ?? user.homeAddress,
      zoneIds: args.zoneIds,
      hasCompletedOnboarding: true,
      updatedAt: now,
    });

    console.log(
      "[completeOnboarding] Updated user:",
      user._id,
      "dispatchMode:",
      dispatchMode,
    );

    // DISPATCH SYSTEM SYNC
    const finalLat = lat ?? user.latitude;
    const finalLng = lng ?? user.longitude;
    const finalRadiusKm = clampedRadiusKm;

    if (args.role === "instructor") {
      if (finalLat && finalLng) {
        // Sync to geospatial index (only adds if radius mode)
        await syncInstructorLocation(
          ctx,
          user._id,
          { latitude: finalLat, longitude: finalLng },
          dispatchMode,
          categoriesArray,
          user.isVerified,
          user.notificationsEnabled ?? true,
          finalRadiusKm,
        );
      }

      // Sync zone subscriptions (creates if zone mode, deletes if radius mode)
      await ctx.scheduler.runAfter(
        0,
        internal.zoneSubscriptions.syncZoneSubscriptions,
        {
          instructorId: user._id,
        },
      );
    }

    return { success: true, userId: user._id };
  },
});

export const resetOnboarding = mutation({
  args: {},
  handler: async (ctx) => {
    const user = await requireCurrentUserByIdentity(ctx);

    await ctx.db.patch(user._id, {
      hasCompletedOnboarding: false,
      updatedAt: Date.now(),
    });
  },
});

export const getUserById = internalQuery({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    return await ctx.db.get(userId);
  },
});

export const getVerifiedInstructors = internalQuery({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("users")
      .withIndex("by_verified", (q) =>
        q.eq("isVerified", true).eq("role", "instructor"),
      )
      .collect();
  },
});

export const getUserProfile = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const user = await ctx.db.get(userId);
    if (!user) return null;

    // Don't expose sensitive fields
    return {
      _id: user._id,
      name: user.name,
      avatarUrl: user.avatarUrl,
      role: user.role,
      isVerified: user.isVerified,
      rating: user.rating,
      ratingCount: user.ratingCount,
      categories: user.categories,
      businessName: user.businessName,
    };
  },
});

export const getMyStudioPricingSettings = query({
  args: {},
  handler: async (ctx) => {
    const user = await requireStudioUserByIdentity(ctx);

    const settings = user.studioPricing;
    return {
      defaultBaseRate: settings?.defaultBaseRate ?? 120,
      leadTimeSurgeRules:
        settings?.leadTimeSurgeRules ?? [
          { maxHoursBeforeStart: 6, boostPercent: 10 },
          { maxHoursBeforeStart: 3, boostPercent: 15 },
        ],
    };
  },
});

export const getStudioPublicProfile = query({
  args: { studioId: v.id("users") },
  handler: async (ctx, { studioId }) => {
    const studio = await ctx.db.get(studioId);
    if (!studio || studio.role !== "studio") return null;
    const studioJobs: Array<{
      _id: string;
      title: string;
      category: string;
      status: string;
      createdAt?: number;
      _creationTime?: number;
      startTime: number;
      endTime: number;
      currentRate: number;
      address: string;
      sosBoostApplied?: boolean;
    }> = await ctx.runQuery(
      internal.jobs.getStudioJobsForStudioInternal,
      { studioId },
    );
    const openJobs = studioJobs.filter((job: (typeof studioJobs)[number]) => job.status === "open");
    const activeJobsCount = studioJobs.filter((job) =>
      job.status === "open" ||
      job.status === "claimed" ||
      job.status === "backup_claimed" ||
      job.status === "confirmed",
    ).length;

    return {
      studio: {
        _id: studio._id,
        name: studio.businessName ?? studio.name,
        avatarUrl: studio.avatarUrl,
        isVerified: studio.isVerified,
        rating: studio.rating,
        ratingCount: studio.ratingCount,
        categories: studio.categories ?? [],
        address: studio.address ?? studio.homeAddress,
      },
      counts: {
        openJobs: openJobs.length,
        activeJobs: activeJobsCount,
      },
      jobs: openJobs.map((job) => ({
        _id: job._id,
        title: job.title,
        category: job.category,
        status: job.status,
        createdAt: job.createdAt ?? job._creationTime ?? 0,
        startTime: job.startTime,
        endTime: job.endTime,
        currentRate: job.currentRate,
        address: job.address,
        sosBoostApplied: job.sosBoostApplied,
      })),
    };
  },
});

// ==========================================
// MUTATIONS
// ==========================================

export const upsertUser = mutation({
  args: {
    name: v.string(),
    email: v.string(),
    role: v.union(v.literal("studio"), v.literal("instructor")),
    phone: v.optional(v.string()),
    businessName: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const uid = await requireIdentitySubject(ctx);

    const existing = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", uid))
      .first();

    const now = Date.now();

    if (existing) {
      await ctx.db.patch(existing._id, {
        name: args.name,
        email: args.email,
        phone: args.phone,
        businessName: args.businessName,
        updatedAt: now,
      });
      return existing._id;
    }

    return await ctx.db.insert("users", {
      firebaseUid: uid,
      name: args.name,
      email: args.email,
      phone: args.phone,
      role: args.role,
      businessName: args.businessName,
      hasCompletedOnboarding: false,
      isVerified: false,
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const updateLocation = mutation({
  args: {
    latitude: v.float64(),
    longitude: v.float64(),
    address: v.optional(v.string()),
    radiusKm: v.optional(v.float64()),
    categories: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    const user = await requireCurrentUserByIdentity(ctx);

    const radiusKm = Math.min(
      Math.max(args.radiusKm ?? user.radiusKm ?? 5, MIN_RADIUS_KM),
      MAX_RADIUS_KM,
    );
    const primaryCategory =
      args.categories && args.categories.length > 0
        ? args.categories[0]
        : user.categories && user.categories.length > 0
          ? user.categories[0]
          : "general";

    const updates: Record<string, unknown> = {
      latitude: args.latitude,
      longitude: args.longitude,
      homeAddress: args.address ?? user.homeAddress ?? user.address,
      address: args.address ?? user.address ?? user.homeAddress,
      radiusKm,
      primaryCategory,
      updatedAt: Date.now(),
    };
    if (args.categories !== undefined) {
      updates.categories = args.categories;
    }

    await ctx.db.patch(user._id, updates);

    if (user.role === "instructor") {
      await syncInstructorLocation(
        ctx,
        user._id,
        { latitude: args.latitude, longitude: args.longitude },
        user.dispatchMode ?? "radius",
        args.categories && args.categories.length > 0
          ? args.categories
          : (user.categories ?? [primaryCategory]),
        user.isVerified,
        user.notificationsEnabled ?? true,
        radiusKm,
      );
    }
  },
});

export const updateFcmToken = mutation({
  args: { token: v.string() },
  handler: async (ctx, { token }) => {
    const user = await requireCurrentUserByIdentity(ctx);

    await ctx.db.patch(user._id, { fcmToken: token });
  },
});

export const updateProfile = mutation({
  args: {
    name: v.optional(v.string()),
    nameHebrew: v.optional(v.string()),
    phone: v.optional(v.string()),
    avatarUrl: v.optional(v.string()),
    businessName: v.optional(v.string()),
    homeAddress: v.optional(v.string()),
    latitude: v.optional(v.float64()),
    longitude: v.optional(v.float64()),
    radiusKm: v.optional(v.float64()),
    categories: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    const user = await requireCurrentUserByIdentity(ctx);

    const updates: Record<string, unknown> = { updatedAt: Date.now() };
    if (args.name !== undefined) updates.name = args.name;
    if (args.nameHebrew !== undefined) updates.nameHebrew = args.nameHebrew;
    if (args.phone !== undefined) updates.phone = args.phone;
    if (args.avatarUrl !== undefined) updates.avatarUrl = args.avatarUrl;
    if (args.businessName !== undefined)
      updates.businessName = args.businessName;
    if (args.homeAddress !== undefined) {
      updates.homeAddress = args.homeAddress;
      updates.address = args.homeAddress;
    }
    if (args.latitude !== undefined) {
      updates.latitude = args.latitude;
    }
    if (args.longitude !== undefined) {
      updates.longitude = args.longitude;
    }
    if (args.radiusKm !== undefined) {
      updates.radiusKm = Math.min(
        Math.max(args.radiusKm, MIN_RADIUS_KM),
        MAX_RADIUS_KM,
      );
    }
    if (args.categories !== undefined) {
      updates.categories = args.categories;
      if (args.categories.length > 0) {
        updates.primaryCategory = args.categories[0];
      }
    }

    await ctx.db.patch(user._id, updates);

    // Sync to geo index if instructor location changed
    if (user.role === "instructor") {
      const radiusKm = Math.min(
        Math.max(args.radiusKm ?? user.radiusKm ?? 5, MIN_RADIUS_KM),
        MAX_RADIUS_KM,
      );
      const primaryCategory =
        (updates.primaryCategory as string) ??
        user.primaryCategory ??
        "general";
      const categories =
        (updates.categories as string[] | undefined) ??
        user.categories ??
        (primaryCategory ? [primaryCategory] : ["general"]);
      const lat = args.latitude ?? user.latitude;
      const lng = args.longitude ?? user.longitude;

      if (lat && lng) {
        await syncInstructorLocation(
          ctx,
          user._id,
          { latitude: lat, longitude: lng },
          user.dispatchMode ?? "radius",
          categories,
          user.isVerified,
          user.notificationsEnabled ?? true,
          radiusKm,
        );
      }
    }
  },
});

export const setMyStudioPricingSettings = mutation({
  args: {
    defaultBaseRate: v.float64(),
    leadTimeSurgeRules: v.optional(
      v.array(
        v.object({
          maxHoursBeforeStart: v.float64(),
          boostPercent: v.float64(),
        }),
      ),
    ),
  },
  handler: async (ctx, args) => {
    const user = await requireStudioUserByIdentity(ctx);

    const defaultBaseRate = Math.min(Math.max(args.defaultBaseRate, 1), 10000);
    const leadTimeSurgeRules = normalizeLeadTimeSurgeRules(
      args.leadTimeSurgeRules,
    );

    await ctx.db.patch(user._id, {
      studioPricing: {
        defaultBaseRate,
        leadTimeSurgeRules,
      },
      updatedAt: Date.now(),
    });

    return {
      defaultBaseRate,
      leadTimeSurgeRules,
    };
  },
});

export const setVerified = internalMutation({
  args: {
    userId: v.id("users"),
    verified: v.boolean(),
  },
  handler: async (ctx, { userId, verified }) => {
    await ctx.db.patch(userId, {
      isVerified: verified,
      verifiedAt: verified ? Date.now() : undefined,
      updatedAt: Date.now(),
    });

    // Update geo index if instructor
    const user = await ctx.db.get(userId);
    if (user && user.role === "instructor" && user.latitude && user.longitude) {
      await syncInstructorLocation(
        ctx,
        userId,
        { latitude: user.latitude, longitude: user.longitude },
        user.dispatchMode ?? "radius",
        user.categories ??
          (user.primaryCategory ? [user.primaryCategory] : ["general"]),
        verified,
        user.notificationsEnabled ?? true,
        user.radiusKm ?? 5,
      );
    }
  },
});

/**
 * Update instructor's search radius.
 * Called from the map screen radius slider.
 */
export const updateRadius = mutation({
  args: { radiusKm: v.float64() },
  handler: async (ctx, { radiusKm }) => {
    if (radiusKm < MIN_RADIUS_KM || radiusKm > MAX_RADIUS_KM) {
      throw new Error(
        `Radius must be between ${MIN_RADIUS_KM} and ${MAX_RADIUS_KM} km`,
      );
    }
    const user = await requireCurrentUserByIdentity(ctx);

    await ctx.db.patch(user._id, {
      radiusKm,
      updatedAt: Date.now(),
    });

    if (user.role === "instructor" && user.latitude && user.longitude) {
      await syncInstructorLocation(
        ctx,
        user._id,
        { latitude: user.latitude, longitude: user.longitude },
        user.dispatchMode ?? "radius",
        user.categories ??
          (user.primaryCategory ? [user.primaryCategory] : ["general"]),
        user.isVerified,
        user.notificationsEnabled ?? true,
        radiusKm,
      );
    }
  },
});

/**
 * Toggle notification preferences.
 * Notifications are opt-in by default (true).
 */
export const updateNotificationPreferences = mutation({
  args: { enabled: v.boolean() },
  handler: async (ctx, { enabled }) => {
    const user = await requireCurrentUserByIdentity(ctx);

    await ctx.db.patch(user._id, {
      notificationsEnabled: enabled,
      updatedAt: Date.now(),
    });

    if (user.role === "instructor" && user.latitude && user.longitude) {
      await syncInstructorLocation(
        ctx,
        user._id,
        { latitude: user.latitude, longitude: user.longitude },
        user.dispatchMode ?? "radius",
        user.categories ??
          (user.primaryCategory ? [user.primaryCategory] : ["general"]),
        user.isVerified,
        enabled,
        user.radiusKm ?? 5,
      );
    }
  },
});

/**
 * Persist app settings that are also cached client-side.
 * This keeps preferences synchronized across devices/sessions.
 */
export const updateSettingsPreferences = mutation({
  args: {
    notificationsEnabled: v.optional(v.boolean()),
    regularJobAlerts: v.optional(v.boolean()),
    sosJobAlerts: v.optional(v.boolean()),
    languageCode: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const user = await requireCurrentUserByIdentity(ctx);

    const updates: Record<string, unknown> = { updatedAt: Date.now() };
    if (args.notificationsEnabled !== undefined) {
      updates.notificationsEnabled = args.notificationsEnabled;
    }
    if (args.regularJobAlerts !== undefined) {
      updates.regularJobAlerts = args.regularJobAlerts;
    }
    if (args.sosJobAlerts !== undefined) {
      updates.sosJobAlerts = args.sosJobAlerts;
    }
    if (args.languageCode !== undefined) {
      updates.languageCode = args.languageCode.trim();
    }

    await ctx.db.patch(user._id, updates);

    if (
      args.notificationsEnabled !== undefined &&
      user.role === "instructor" &&
      user.latitude &&
      user.longitude
    ) {
      await syncInstructorLocation(
        ctx,
        user._id,
        { latitude: user.latitude, longitude: user.longitude },
        user.dispatchMode ?? "radius",
        user.categories ??
          (user.primaryCategory ? [user.primaryCategory] : ["general"]),
        user.isVerified,
        args.notificationsEnabled,
        user.radiusKm ?? 5,
      );
    }
  },
});

/**
 * Update instructor's dispatch mode and associated settings.
 * This is the PRIMARY way for instructors to switch between radius and zone modes.
 */
export const updateDispatchMode = mutation({
  args: {
    mode: v.union(v.literal("radius"), v.literal("zone")),
    // For radius mode
    latitude: v.optional(v.float64()),
    longitude: v.optional(v.float64()),
    radiusKm: v.optional(v.float64()),
    // For zone mode
    zoneIds: v.optional(v.array(v.id("zones"))),
  },
  handler: async (ctx, args) => {
    const user = await requireCurrentUserByIdentity(ctx);
    if (user.role !== "instructor")
      throw new Error("Only instructors can set dispatch mode");

    // Validate mode-specific requirements
    if (args.mode === "radius") {
      const lat = args.latitude ?? user.latitude;
      const lng = args.longitude ?? user.longitude;
      const rad = args.radiusKm ?? user.radiusKm;
      if (!lat || !lng)
        throw new Error(
          "Radius mode requires a location. Please set your location first.",
        );
      if (!rad) throw new Error("Radius mode requires a radius.");
    } else {
      const zones = args.zoneIds ?? user.zoneIds;
      if (!zones || zones.length === 0)
        throw new Error("Zone mode requires at least one zone.");
    }

    const clampedRadius = args.radiusKm
      ? Math.min(Math.max(args.radiusKm, MIN_RADIUS_KM), MAX_RADIUS_KM)
      : undefined;

    await ctx.db.patch(user._id, {
      dispatchMode: args.mode,
      latitude: args.latitude ?? user.latitude,
      longitude: args.longitude ?? user.longitude,
      radiusKm: clampedRadius ?? user.radiusKm,
      zoneIds: args.zoneIds ?? user.zoneIds,
      updatedAt: Date.now(),
    });

    const finalLat = args.latitude ?? user.latitude;
    const finalLng = args.longitude ?? user.longitude;
    const finalRadiusKm = clampedRadius ?? user.radiusKm ?? 5;

    // Sync to appropriate dispatch system
    if (finalLat && finalLng) {
      await syncInstructorLocation(
        ctx,
        user._id,
        { latitude: finalLat, longitude: finalLng },
        args.mode,
        user.categories ??
          (user.primaryCategory ? [user.primaryCategory] : ["general"]),
        user.isVerified,
        user.notificationsEnabled ?? true,
        finalRadiusKm,
      );
    }

    // Update zone subscriptions (creates if zone mode, deletes if radius mode)
    await ctx.scheduler.runAfter(
      0,
      internal.zoneSubscriptions.syncZoneSubscriptions,
      {
        instructorId: user._id,
      },
    );

    return { success: true, mode: args.mode };
  },
});

/**
 * Update instructor's selected zones.
 * Called from the map screen zone selector.
 */
export const updateZones = mutation({
  args: { zoneIds: v.array(v.id("zones")) },
  handler: async (ctx, { zoneIds }) => {
    const user = await requireCurrentUserByIdentity(ctx);

    await ctx.db.patch(user._id, {
      zoneIds,
      updatedAt: Date.now(),
    });

    // If user is zone mode, resync subscriptions
    if (user.dispatchMode === "zone") {
      await ctx.scheduler.runAfter(
        0,
        internal.zoneSubscriptions.syncZoneSubscriptions,
        {
          instructorId: user._id,
        },
      );
    }
  },
});
