// convex/users.ts
// User queries and mutations

import { query, mutation, internalQuery, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { syncInstructorLocation, removeInstructorLocation } from "./geo";

// ==========================================
// QUERIES
// ==========================================

export const getCurrentUser = query({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .unique();
    
    return user;
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
    const identity = await ctx.auth.getUserIdentity();
    
    // Use identity subject if available, otherwise use provided firebaseUid
    const uid = identity?.subject ?? args.firebaseUid;
    
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
    // Accept both number and string due to convex_flutter serialization quirk
    radiusKm: v.optional(v.union(v.float64(), v.string())),
    latitude: v.optional(v.union(v.float64(), v.string())),
    longitude: v.optional(v.union(v.float64(), v.string())),
    address: v.optional(v.string()),
    selectedZones: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    console.log("[completeOnboarding] Called with args:", JSON.stringify(args));
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .unique();
    
    if (!user) throw new Error("User not found");
    
    const now = Date.now();
    
    const categoriesArray = args.categories.split(',').map(c => c.trim()).filter(c => c.length > 0);
    const primaryCategory = categoriesArray.length > 0 ? categoriesArray[0] : "general";

    // Validate zone IDs if provided - they should be valid Convex IDs
    let validZoneIds: any[] | undefined = undefined;
    if (args.selectedZones && args.selectedZones.length > 0) {
      validZoneIds = [];
      for (const zoneId of args.selectedZones) {
        try {
          // Try to fetch the zone to validate it exists
          const zone = await ctx.db.get(zoneId as any);
          if (zone) {
            validZoneIds.push(zoneId);
          } else {
            console.warn(`[completeOnboarding] Zone not found: ${zoneId}`);
          }
        } catch (e) {
          console.warn(`[completeOnboarding] Invalid zone ID format: ${zoneId}`);
        }
      }
      console.log(`[completeOnboarding] Valid zones: ${validZoneIds.length}/${args.selectedZones.length}`);
    }

    // Helper to parse numbers
    const parseNum = (val: number | string | undefined): number | undefined => {
      if (val === undefined) return undefined;
      const parsed = typeof val === 'string' ? parseFloat(val) : val;
      return isNaN(parsed) ? undefined : parsed;
    };

    const lat = parseNum(args.latitude);
    const lng = parseNum(args.longitude);
    const rad = parseNum(args.radiusKm);

    await ctx.db.patch(user._id, {
      role: args.role,
      name: args.name,
      categories: categoriesArray,
      primaryCategory,
      radiusKm: rad ?? user.radiusKm ?? 5,
      latitude: lat ?? user.latitude,
      longitude: lng ?? user.longitude,
      homeLatitude: lat ?? user.homeLatitude,
      homeLongitude: lng ?? user.homeLongitude,
      homeAddress: args.address ?? user.homeAddress,
      selectedZones: validZoneIds ?? user.selectedZones,
      hasCompletedOnboarding: true,
      updatedAt: now,
    });

    console.log("[completeOnboarding] Successfully updated user:", user._id);

    // GEOSPATIAL SYNC
    const finalLat = lat ?? user.latitude;
    const finalLng = lng ?? user.longitude;
    const finalRadiusKm = rad ?? user.radiusKm ?? 5;

    if (args.role === "instructor" && finalLat && finalLng) {
      await syncInstructorLocation(
        ctx,
        user._id,
        { 
          latitude: finalLat, 
          longitude: finalLng 
        },
        primaryCategory,
        user.isVerified,
        user.notificationsEnabled ?? true,
        finalRadiusKm
      );
    }

    return { success: true, userId: user._id };
  },
});

export const resetOnboarding = mutation({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .unique();

    if (!user) throw new Error("User not found");

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
      .withIndex("by_verified", (q) => q.eq("isVerified", true).eq("role", "instructor"))
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
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    const existing = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
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
      firebaseUid: identity.subject,
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
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user) throw new Error("User not found");
    
    const radiusKm = args.radiusKm ?? user.radiusKm ?? 5;
    const primaryCategory = (args.categories && args.categories.length > 0) 
      ? args.categories[0] 
      : (user.categories && user.categories.length > 0) ? user.categories[0] : "general";

    await ctx.db.patch(user._id, {
      latitude: args.latitude,
      longitude: args.longitude,
      homeLatitude: user.homeLatitude ?? args.latitude,
      homeLongitude: user.homeLongitude ?? args.longitude,
      homeAddress: args.address ?? user.homeAddress,
      radiusKm,
      categories: args.categories,
      primaryCategory,
      updatedAt: Date.now(),
    });

    if (user.role === "instructor") {
      await syncInstructorLocation(
        ctx,
        user._id,
        { latitude: args.latitude, longitude: args.longitude },
        primaryCategory,
        user.isVerified,
        user.notificationsEnabled ?? true,
        radiusKm
      );
    }
  },
});

export const updateFcmToken = mutation({
  args: { token: v.string() },
  handler: async (ctx, { token }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .unique();
    
    if (!user) throw new Error("User not found");
    
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
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user) throw new Error("User not found");
    
    const updates: Record<string, unknown> = { updatedAt: Date.now() };
    if (args.name !== undefined) updates.name = args.name;
    if (args.nameHebrew !== undefined) updates.nameHebrew = args.nameHebrew;
    if (args.phone !== undefined) updates.phone = args.phone;
    if (args.avatarUrl !== undefined) updates.avatarUrl = args.avatarUrl;
    if (args.businessName !== undefined) updates.businessName = args.businessName;
    if (args.homeAddress !== undefined) updates.homeAddress = args.homeAddress;
    if (args.latitude !== undefined) {
      updates.latitude = args.latitude;
      updates.homeLatitude = args.latitude;
    }
    if (args.longitude !== undefined) {
      updates.longitude = args.longitude;
      updates.homeLongitude = args.longitude;
    }
    if (args.radiusKm !== undefined) updates.radiusKm = args.radiusKm;
    if (args.categories !== undefined) {
      updates.categories = args.categories;
      if (args.categories.length > 0) {
        updates.primaryCategory = args.categories[0];
      }
    }
    
    await ctx.db.patch(user._id, updates);

    // Sync to geo index if instructor location changed
    if (user.role === "instructor") {
      const radiusKm = args.radiusKm ?? user.radiusKm ?? 5;
      const primaryCategory = updates.primaryCategory as string ?? user.primaryCategory ?? "general";
      const lat = args.latitude ?? user.latitude;
      const lng = args.longitude ?? user.longitude;

      if (lat && lng) {
        await syncInstructorLocation(
          ctx,
          user._id,
          { latitude: lat, longitude: lng },
          primaryCategory,
          user.isVerified,
          user.notificationsEnabled ?? true,
          radiusKm
        );
      }
    }
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
        user.primaryCategory ?? "general",
        verified,
        user.notificationsEnabled ?? true,
        user.radiusKm ?? 5
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
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    if (radiusKm < 0.5 || radiusKm > 50) {
      throw new Error("Radius must be between 0.5 and 50 km");
    }
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user) throw new Error("User not found");
    
    await ctx.db.patch(user._id, {
      radiusKm,
      updatedAt: Date.now(),
    });

    if (user.role === "instructor" && user.latitude && user.longitude) {
      await syncInstructorLocation(
        ctx,
        user._id,
        { latitude: user.latitude, longitude: user.longitude },
        user.primaryCategory ?? "general",
        user.isVerified,
        user.notificationsEnabled ?? true,
        radiusKm
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
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user) throw new Error("User not found");
    
    await ctx.db.patch(user._id, {
      notificationsEnabled: enabled,
      updatedAt: Date.now(),
    });

    if (user.role === "instructor" && user.latitude && user.longitude) {
      await syncInstructorLocation(
        ctx,
        user._id,
        { latitude: user.latitude, longitude: user.longitude },
        user.primaryCategory ?? "general",
        user.isVerified,
        enabled,
        user.radiusKm ?? 5
      );
    }
  },
});


/**
 * Update instructor's selected zones.
 * Called from the map screen zone selector.
 */
export const updateZones = mutation({
  args: { zoneIds: v.array(v.string()) }, // Accept strings for flexibility
  handler: async (ctx, { zoneIds }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_firebaseUid", (q) => q.eq("firebaseUid", identity.subject))
      .first();
    
    if (!user) throw new Error("User not found");
    
    await ctx.db.patch(user._id, {
      selectedZones: zoneIds,
      updatedAt: Date.now(),
    });
  },
});
