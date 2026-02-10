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

    // DISPATCH MODE - Instructor's choice for job matching
    // "radius" = receive jobs within X km of location
    // "zone" = receive jobs from selected Pikud HaOref zones
    dispatchMode: v.optional(v.union(v.literal("radius"), v.literal("zone"))),

    // Onboarding status
    hasCompletedOnboarding: v.optional(v.boolean()),
    
    // Verification status (instructors only)
    isVerified: v.boolean(),
    verifiedAt: v.optional(v.number()),
    
    // Admin access
    isAdmin: v.optional(v.boolean()),
    
    // Rating (0-5 scale)
    rating: v.optional(v.float64()),
    ratingCount: v.optional(v.number()),
    
    // LOCATION (for radius mode OR studio zone assignment)
    latitude: v.optional(v.float64()),
    longitude: v.optional(v.float64()),
    homeLatitude: v.optional(v.float64()),
    homeLongitude: v.optional(v.float64()),
    homeAddress: v.optional(v.string()),
    address: v.optional(v.string()),
    
    // RADIUS MODE: How far instructor is willing to travel (km)
    radiusKm: v.optional(v.float64()),
    
    // ZONE MODE: Selected Pikud HaOref zones instructor covers
    zoneIds: v.optional(v.array(v.id("zones"))),
    
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
    .index("by_category", ["primaryCategory", "role"])
    .index("by_dispatchMode", ["dispatchMode", "role"]),

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
    
    // Zone assignment (for zone-based dispatch)
    zoneId: v.optional(v.id("zones")),
    
    // Status flow (with backup support)
    status: v.union(
      v.literal("open"),              // No claims yet
      v.literal("claimed"),           // Primary instructor claimed
      v.literal("backup_claimed"),    // Primary + backup instructor claimed
      v.literal("confirmed"),         // Studio confirmed primary
      v.literal("completed"),
      v.literal("cancelled"),
      v.literal("expired")
    ),
    
    // PRIMARY CLAIM
    claimedBy: v.optional(v.id("users")),
    claimedAt: v.optional(v.number()),
    confirmedAt: v.optional(v.number()),
    
    // BACKUP CLAIM (second instructor)
    backupClaimedBy: v.optional(v.id("users")),
    backupClaimedAt: v.optional(v.number()),
    
    // BACKUP QUEUE (auto-promotion metadata)
    backupAutoPromoted: v.optional(v.boolean()),    // True if backup was auto-promoted
    
    // Requirements
    requiresVerification: v.boolean(),
    requiredCerts: v.optional(v.array(v.string())),
    
    // Notifications sent
    notificationsSent: v.boolean(),
    notifiedInstructors: v.optional(v.array(v.id("users"))),
    dispatchVersion: v.optional(v.number()),
    dispatchAttempt: v.optional(v.number()),
    dispatchScheduledAt: v.optional(v.number()),
    dispatchLastError: v.optional(v.string()),
    
    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_studio", ["studioId"])
    .index("by_status", ["status", "startTime"])
    .index("by_category_status", ["category", "status"])
    .index("by_claimedBy", ["claimedBy"])
    .index("by_startTime", ["startTime"])
    .index("by_zone_status", ["zoneId", "status"])
    .index("by_zone_category_status", ["zoneId", "category", "status"]),

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

    // Preferred secure reference: storage object ID in Convex storage.
    storageId: v.id("_storage"),
    // Legacy field kept optional for backward compatibility with older records.
    docUrl: v.optional(v.string()),
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
      v.literal("backup_claimed"),
      v.literal("backup_promoted"),
      v.literal("backup_promoted_studio"),
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
  // ZONE SUBSCRIPTIONS - O(1) dispatch for zone-mode instructors
  // Synced when instructor updates zones or categories
  // ==========================================
  zoneSubscriptions: defineTable({
    // The instructor subscribed to this zone/category combo
    instructorId: v.id("users"),
    
    // The zone they're subscribed to
    zoneId: v.id("zones"),
    
    // The category they teach
    category: v.string(),
    
    // Timestamps
    createdAt: v.number(),
  })
    // PRIMARY DISPATCH QUERY: Find instructors for zone+category
    .index("by_zone_category", ["zoneId", "category"])
    // Cleanup: Find all subscriptions for an instructor
    .index("by_instructor", ["instructorId"]),

  // ==========================================
  // USER FILES - storage object ownership
  // ==========================================
  userFiles: defineTable({
    userId: v.id("users"),
    storageId: v.id("_storage"),
    purpose: v.optional(v.string()),
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_storage", ["storageId"]),
});
