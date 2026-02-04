import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

// ============================================
// QUICKFIT SCHEMA - Israeli Fitness Marketplace
// ============================================

export default defineSchema({
  // ==========================================
  // USERS - Studios and Instructors
  // ==========================================
  users: defineTable({
    // Auth
    firebaseUid: v.string(),
    email: v.string(),
    phone: v.optional(v.string()),
    
    // Profile
    name: v.string(),
    nameHebrew: v.optional(v.string()),
    avatarUrl: v.optional(v.string()),
    
    // Role: "studio" posts jobs, "instructor" claims them
    role: v.union(v.literal("studio"), v.literal("instructor")),

    // Onboarding status
    hasCompletedOnboarding: v.boolean(),
    
    // Verification status (instructors only)
    isVerified: v.boolean(),
    verifiedAt: v.optional(v.number()),
    
    // Rating (0-5 scale)
    rating: v.optional(v.float64()),
    ratingCount: v.optional(v.number()),
    
    // HOME LOCATION (set during onboarding, used as fallback)
    homeLatitude: v.optional(v.float64()),
    homeLongitude: v.optional(v.float64()),
    homeAddress: v.optional(v.string()),
    
    // CURRENT LOCATION (updated via GPS when app active)
    currentLatitude: v.optional(v.float64()),
    currentLongitude: v.optional(v.float64()),
    locationUpdatedAt: v.optional(v.number()),
    
    // Effective location (for queries - updated when either home or current changes)
    latitude: v.optional(v.float64()),
    longitude: v.optional(v.float64()),
    
    // INSTRUCTOR-SPECIFIC: How far they're willing to travel (in km)
    radiusKm: v.optional(v.float64()),
    
    // INSTRUCTOR-SPECIFIC: Selected Pikud HaOref zones (preferred dispatch areas)
    // Stored as string IDs for flexibility (validated server-side)
    selectedZones: v.optional(v.array(v.string())),
    
    // STUDIO-SPECIFIC: Auto-detected zone based on address
    zoneId: v.optional(v.id("zones")),
    
    // INSTRUCTOR-SPECIFIC: What they teach (primary category for geospatial filtering)
    categories: v.optional(v.array(v.string())),
    primaryCategory: v.optional(v.string()), // Main skill for geo index
    
    // STUDIO-SPECIFIC: Business details
    businessName: v.optional(v.string()),
    
    // FCM token for push notifications
    fcmToken: v.optional(v.string()),
    
    // Notification preferences (opt-in by default)
    notificationsEnabled: v.optional(v.boolean()), // defaults to true
    
    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_firebaseUid", ["firebaseUid"])
    .index("by_role", ["role"])
    .index("by_verified", ["isVerified", "role"])
    .index("by_category", ["primaryCategory", "role"]),

  // ==========================================
  // JOBS - Substitute requests from studios
  // ==========================================
  jobs: defineTable({
    // Who posted
    studioId: v.id("users"),
    
    // Job details
    title: v.string(),
    description: v.optional(v.string()),
    category: v.string(),
    
    // Timing
    startTime: v.number(),
    endTime: v.number(),
    durationMinutes: v.number(),
    
    // Payment
    baseRate: v.float64(),
    currentRate: v.float64(),
    sosBoostApplied: v.boolean(),
    sosBoostPercentage: v.optional(v.float64()),
    
    // Location (studio's location)
    latitude: v.float64(),
    longitude: v.float64(),
    address: v.string(),
    
    // Status flow
    status: v.union(
      v.literal("open"),
      v.literal("claimed"),
      v.literal("confirmed"),
      v.literal("completed"),
      v.literal("cancelled"),
      v.literal("expired")
    ),
    
    // Who claimed (if any)
    claimedBy: v.optional(v.id("users")),
    claimedAt: v.optional(v.number()),
    confirmedAt: v.optional(v.number()),
    
    // Requirements
    requiresVerification: v.boolean(),
    requiredCerts: v.optional(v.array(v.string())),
    
    // Notifications sent
    notificationsSent: v.boolean(),
    notifiedInstructors: v.optional(v.array(v.id("users"))),
    
    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_studio", ["studioId"])
    .index("by_status", ["status", "startTime"])
    .index("by_category_status", ["category", "status"])
    .index("by_claimedBy", ["claimedBy"])
    .index("by_startTime", ["startTime"]),

  // ==========================================
  // CLAIMS - Instructor claims on jobs
  // ==========================================
  claims: defineTable({
    jobId: v.id("jobs"),
    instructorId: v.id("users"),
    
    status: v.union(
      v.literal("pending"),
      v.literal("accepted"),
      v.literal("rejected"),
      v.literal("withdrawn")
    ),
    
    distanceKm: v.float64(),
    message: v.optional(v.string()),
    
    createdAt: v.number(),
    respondedAt: v.optional(v.number()),
  })
    .index("by_job", ["jobId"])
    .index("by_instructor", ["instructorId"])
    .index("by_job_status", ["jobId", "status"]),

  // ==========================================
  // VERIFICATIONS - Certificate verification
  // ==========================================
  verifications: defineTable({
    userId: v.id("users"),
    
    docUrl: v.string(),
    docType: v.string(),
    originalFilename: v.optional(v.string()),
    
    aiAnalysis: v.optional(v.object({
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
    })),
    
    status: v.union(
      v.literal("pending"),
      v.literal("processing"),
      v.literal("verified"),
      v.literal("rejected"),
      v.literal("manual_review"),
      v.literal("expired")
    ),
    
    reviewedBy: v.optional(v.id("users")),
    reviewNotes: v.optional(v.string()),
    
    createdAt: v.number(),
    processedAt: v.optional(v.number()),
    verifiedAt: v.optional(v.number()),
  })
    .index("by_user", ["userId"])
    .index("by_status", ["status"])
    .index("by_user_status", ["userId", "status"]),

  // ==========================================
  // SOS PRIORITY QUEUE
  // ==========================================
  sosPriorityQueue: defineTable({
    jobId: v.id("jobs"),
    startTime: v.number(),
    hoursUntilStart: v.float64(),
    boostPercentage: v.float64(),
    processed: v.boolean(),
    processedAt: v.optional(v.number()),
    createdAt: v.number(),
  })
    .index("by_processed", ["processed", "startTime"])
    .index("by_job", ["jobId"]),

  // ==========================================
  // RATINGS - Post-job feedback
  // ==========================================
  ratings: defineTable({
    jobId: v.id("jobs"),
    fromUserId: v.id("users"),
    toUserId: v.id("users"),
    rating: v.float64(),
    comment: v.optional(v.string()),
    createdAt: v.number(),
  })
    .index("by_toUser", ["toUserId"])
    .index("by_job", ["jobId"]),

  // ==========================================
  // NOTIFICATIONS LOG
  // ==========================================
  notificationLogs: defineTable({
    userId: v.id("users"),
    jobId: v.optional(v.id("jobs")),
    
    type: v.union(
      v.literal("new_job"),
      v.literal("job_claimed"),
      v.literal("claim_accepted"),
      v.literal("claim_rejected"),
      v.literal("job_cancelled"),
      v.literal("verification_complete"),
      v.literal("reminder")
    ),
    
    title: v.string(),
    body: v.string(),
    
    sent: v.boolean(),
    sentAt: v.optional(v.number()),
    error: v.optional(v.string()),
    
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_job", ["jobId"]),

  // ==========================================
  // ZONES - Pikud HaOref Geographic Zones
  // Pre-defined geographic boundaries (like Tzofar alert zones)
  // ==========================================
  zones: defineTable({
    // Official Pikud HaOref zone identifier
    orefId: v.string(),
    
    // Zone names (bilingual)
    name: v.string(),        // e.g., "Rishon LeZion West"
    nameHebrew: v.string(),  // e.g., "ראשון לציון מערב"
    
    // Parent city/area (for grouping in UI)
    city: v.optional(v.string()),
    
    // Geographic boundary - array of lat/lng points forming the polygon
    // These are REAL geographic boundaries, not approximations
    polygon: v.array(v.object({
      lat: v.float64(),
      lng: v.float64(),
    })),
    
    // Center point of the zone (for map display)
    centroid: v.object({
      lat: v.float64(),
      lng: v.float64(),
    }),
    
    // Shelter time in seconds (from Pikud HaOref data)
    shelterTime: v.optional(v.number()),
  })
    .index("by_oref_id", ["orefId"])
    .index("by_city", ["city"]),

  // ==========================================
  // SUBSCRIPTIONS - Pre-computed Instructor-Studio Relationships
  // Created when instructor/studio updates profile
  // Enables O(1) dispatch queries
  // ==========================================
  subscriptions: defineTable({
    // The instructor who is subscribed
    instructorId: v.id("users"),
    
    // The studio they can receive jobs from
    studioId: v.id("users"),
    
    // The category this subscription is for
    category: v.string(),
    
    // The zone this relationship is based on
    zoneId: v.id("zones"),
    
    // Timestamps
    createdAt: v.number(),
  })
    // Primary query: "Find all instructors subscribed to this studio for this category"
    .index("by_studio_category", ["studioId", "category"])
    // Secondary: "Find all subscriptions for a zone"
    .index("by_zone_category", ["zoneId", "category"])
    // For cleanup: "Find all subscriptions for an instructor"
    .index("by_instructor", ["instructorId"]),
});
