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
    regularJobAlerts: v.optional(v.boolean()),
    sosJobAlerts: v.optional(v.boolean()),
    languageCode: v.optional(v.string()),

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
      v.literal("open"), // No claims yet
      v.literal("claimed"), // Primary instructor claimed
      v.literal("backup_claimed"), // Primary + backup instructor claimed
      v.literal("confirmed"), // Studio confirmed primary
      v.literal("completed"),
      v.literal("cancelled"),
      v.literal("expired"),
    ),

    // PRIMARY CLAIM
    claimedBy: v.optional(v.id("users")),
    claimedAt: v.optional(v.number()),
    confirmedAt: v.optional(v.number()),

    // BACKUP CLAIM (second instructor)
    backupClaimedBy: v.optional(v.id("users")),
    backupClaimedAt: v.optional(v.number()),

    // BACKUP QUEUE (auto-promotion metadata)
    backupAutoPromoted: v.optional(v.boolean()), // True if backup was auto-promoted

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
    .index("by_status_claimedAt", ["status", "claimedAt"])
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
      v.literal("withdrawn"),
    ),

    distanceKm: v.float64(),
    message: v.optional(v.string()),

    createdAt: v.number(),
    respondedAt: v.optional(v.number()),
  })
    .index("by_job", ["jobId"])
    .index("by_instructor", ["instructorId"])
    .index("by_job_status", ["jobId", "status"])
    .index("by_job_instructor", ["jobId", "instructorId"])
    .index("by_job_status_instructor", ["jobId", "status", "instructorId"]),

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

    aiAnalysis: v.optional(
      v.object({
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
          v.literal("reject"),
        ),
      }),
    ),

    status: v.union(
      v.literal("pending"),
      v.literal("processing"),
      v.literal("verified"),
      v.literal("rejected"),
      v.literal("manual_review"),
      v.literal("expired"),
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
  // PAYMENTS - checkout, capture, payout ledger
  // ==========================================
  payments: defineTable({
    jobId: v.id("jobs"),
    studioId: v.id("users"),
    instructorId: v.optional(v.id("users")),

    provider: v.union(v.literal("rapyd"), v.literal("bitpay")),
    providerCheckoutId: v.optional(v.string()),
    providerPaymentId: v.optional(v.string()),

    status: v.union(
      v.literal("created"),
      v.literal("pending"),
      v.literal("authorized"),
      v.literal("captured"),
      v.literal("failed"),
      v.literal("cancelled"),
      v.literal("refunded"),
    ),

    currency: v.string(),
    grossAmountAgorot: v.number(),
    feeAmountAgorot: v.number(),
    netAmountAgorot: v.number(),
    feeBps: v.number(),

    idempotencyKey: v.string(),
    metadata: v.optional(v.any()),
    lastError: v.optional(v.string()),
    capturedAt: v.optional(v.number()),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_studio", ["studioId", "createdAt"])
    .index("by_instructor", ["instructorId", "createdAt"])
    .index("by_job", ["jobId", "createdAt"])
    .index("by_status", ["status", "createdAt"])
    .index("by_studio_idempotency", ["studioId", "idempotencyKey"])
    .index("by_provider_checkoutId", ["provider", "providerCheckoutId"])
    .index("by_provider_paymentId", ["provider", "providerPaymentId"]),

  // ==========================================
  // PAYMENT EVENTS - webhook idempotency and audit
  // ==========================================
  paymentEvents: defineTable({
    provider: v.union(v.literal("rapyd"), v.literal("bitpay")),
    providerEventId: v.string(),
    eventType: v.optional(v.string()),
    paymentId: v.optional(v.id("payments")),
    providerPaymentId: v.optional(v.string()),
    providerCheckoutId: v.optional(v.string()),
    statusRaw: v.optional(v.string()),
    signatureValid: v.boolean(),
    processed: v.boolean(),
    payloadHash: v.string(),
    payload: v.any(),
    processingError: v.optional(v.string()),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_provider_eventId", ["provider", "providerEventId"])
    .index("by_payment", ["paymentId", "createdAt"]),

  // ==========================================
  // PAYOUTS - provider payout orchestration state
  // ==========================================
  payouts: defineTable({
    paymentId: v.id("payments"),
    jobId: v.id("jobs"),
    studioId: v.id("users"),
    instructorId: v.id("users"),
    destinationId: v.optional(v.id("payoutDestinations")),
    provider: v.union(v.literal("rapyd"), v.literal("bitpay")),
    idempotencyKey: v.string(),

    amountAgorot: v.number(),
    currency: v.string(),

    status: v.union(
      v.literal("queued"),
      v.literal("processing"),
      v.literal("pending_provider"),
      v.literal("paid"),
      v.literal("failed"),
      v.literal("cancelled"),
      v.literal("needs_attention"),
    ),
    providerPayoutId: v.optional(v.string()),
    providerStatusRaw: v.optional(v.string()),

    attemptCount: v.number(),
    maxAttempts: v.number(),
    lastError: v.optional(v.string()),
    lastAttemptAt: v.optional(v.number()),
    nextRetryAt: v.optional(v.number()),
    terminalAt: v.optional(v.number()),

    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_payment", ["paymentId", "createdAt"])
    .index("by_instructor", ["instructorId", "createdAt"])
    .index("by_destination", ["destinationId", "createdAt"])
    .index("by_status_retryAt", ["status", "nextRetryAt"])
    .index("by_provider_payoutId", ["provider", "providerPayoutId"])
    .index("by_idempotency", ["idempotencyKey"]),

  // ==========================================
  // PAYOUT EVENTS - payout attempt/event audit log
  // ==========================================
  payoutEvents: defineTable({
    payoutId: v.id("payouts"),
    paymentId: v.id("payments"),
    provider: v.union(v.literal("rapyd"), v.literal("bitpay")),
    eventType: v.union(
      v.literal("attempt_started"),
      v.literal("provider_response"),
      v.literal("retry_scheduled"),
      v.literal("terminal_failure"),
      v.literal("status_update"),
    ),
    attempt: v.optional(v.number()),
    providerEventId: v.optional(v.string()),
    providerPayoutId: v.optional(v.string()),
    statusRaw: v.optional(v.string()),
    mappedStatus: v.optional(
      v.union(
        v.literal("queued"),
        v.literal("processing"),
        v.literal("pending_provider"),
        v.literal("paid"),
        v.literal("failed"),
        v.literal("cancelled"),
        v.literal("needs_attention"),
      ),
    ),
    retryable: v.optional(v.boolean()),
    httpStatus: v.optional(v.number()),
    errorCode: v.optional(v.string()),
    message: v.optional(v.string()),
    payload: v.optional(v.any()),
    createdAt: v.number(),
  })
    .index("by_payout", ["payoutId", "createdAt"])
    .index("by_payment", ["paymentId", "createdAt"])
    .index("by_provider_eventId", ["provider", "providerEventId"]),

  // ==========================================
  // PAYOUT DESTINATIONS - instructor payout rails
  // ==========================================
  payoutDestinations: defineTable({
    userId: v.id("users"),
    provider: v.union(v.literal("rapyd"), v.literal("bitpay")),
    type: v.string(),
    externalRecipientId: v.string(),
    label: v.optional(v.string()),
    country: v.optional(v.string()),
    currency: v.optional(v.string()),
    last4: v.optional(v.string()),
    isDefault: v.boolean(),
    status: v.string(),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_user", ["userId", "updatedAt"])
    .index("by_user_provider_external", [
      "userId",
      "provider",
      "externalRecipientId",
    ])
    .index("by_user_default", ["userId", "isDefault", "updatedAt"]),

  // ==========================================
  // INVOICES - provider-issued tax docs per payment
  // ==========================================
  invoices: defineTable({
    paymentId: v.id("payments"),
    provider: v.union(v.literal("morning"), v.literal("icount")),
    externalInvoiceId: v.optional(v.string()),
    status: v.union(
      v.literal("pending"),
      v.literal("issued"),
      v.literal("failed"),
      v.literal("voided"),
    ),
    currency: v.string(),
    amountAgorot: v.number(),
    vatRate: v.optional(v.number()),
    error: v.optional(v.string()),
    issuedAt: v.optional(v.number()),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_payment", ["paymentId", "createdAt"])
    .index("by_status", ["status", "createdAt"])
    .index("by_provider_external", ["provider", "externalInvoiceId"]),

  // ==========================================
  // STUDIO BILLING INTEGRATIONS - per-studio invoicing config
  // ==========================================
  studioBillingIntegrations: defineTable({
    studioId: v.id("users"),
    provider: v.union(v.literal("morning"), v.literal("icount")),
    isActive: v.boolean(),
    displayName: v.optional(v.string()),
    baseUrl: v.string(),
    // Provider-specific auth fields.
    // Legacy plaintext fields kept for backward compatibility.
    apiToken: v.optional(v.string()),
    apiKey: v.optional(v.string()),
    // Encrypted-at-rest credentials (preferred).
    sealedApiToken: v.optional(v.string()),
    sealedApiKey: v.optional(v.string()),
    accountId: v.optional(v.string()),
    defaultVatRate: v.optional(v.float64()),
    lastSyncError: v.optional(v.string()),
    lastVerifiedAt: v.optional(v.number()),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_studio", ["studioId", "updatedAt"])
    .index("by_studio_provider", ["studioId", "provider"])
    .index("by_studio_active", ["studioId", "isActive", "updatedAt"]),

  // ==========================================
  // STUDIO PAYMENT INTEGRATIONS - per-studio checkout config
  // ==========================================
  studioPaymentIntegrations: defineTable({
    studioId: v.id("users"),
    provider: v.union(v.literal("rapyd"), v.literal("bitpay")),
    isActive: v.boolean(),
    displayName: v.optional(v.string()),
    // Sandbox/production selector for provider API surface.
    mode: v.union(v.literal("sandbox"), v.literal("production")),
    // Provider-specific auth fields.
    // Legacy plaintext fields kept for backward compatibility.
    apiToken: v.optional(v.string()),
    apiKey: v.optional(v.string()),
    webhookSecret: v.optional(v.string()),
    // Encrypted-at-rest credentials (preferred).
    sealedApiToken: v.optional(v.string()),
    sealedApiKey: v.optional(v.string()),
    sealedWebhookSecret: v.optional(v.string()),
    accountId: v.optional(v.string()),
    merchantId: v.optional(v.string()),
    lastSyncError: v.optional(v.string()),
    lastVerifiedAt: v.optional(v.number()),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_studio", ["studioId", "updatedAt"])
    .index("by_studio_provider", ["studioId", "provider"])
    .index("by_studio_active", ["studioId", "isActive", "updatedAt"]),

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
      v.literal("reminder"),
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
    name: v.string(), // e.g., "Rishon LeZion West"
    nameHebrew: v.string(), // e.g., "ראשון לציון מערב"

    // Parent city/area (for grouping in UI)
    city: v.optional(v.string()),

    // Geographic boundary - array of lat/lng points forming the polygon
    // These are REAL geographic boundaries, not approximations
    polygon: v.array(
      v.object({
        lat: v.float64(),
        lng: v.float64(),
      }),
    ),

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

  // ==========================================
  // UPLOAD SESSIONS - bind register step to generated upload intent
  // ==========================================
  uploadSessions: defineTable({
    token: v.string(),
    userId: v.id("users"),
    purpose: v.optional(v.string()),
    expiresAt: v.number(),
    usedAt: v.optional(v.number()),
    storageId: v.optional(v.id("_storage")),
    createdAt: v.number(),
  })
    .index("by_token", ["token"])
    .index("by_user", ["userId"]),

  // ==========================================
  // MUTATION IDEMPOTENCY - dedupe retryed writes
  // ==========================================
  mutationIdempotency: defineTable({
    key: v.string(),
    operation: v.union(v.literal("claimJob"), v.literal("withdrawClaim")),
    idempotencyKey: v.string(),
    userId: v.id("users"),
    jobId: v.id("jobs"),
    resultClaimId: v.optional(v.id("claims")),
    resultRole: v.optional(v.union(v.literal("primary"), v.literal("backup"))),
    createdAt: v.number(),
    updatedAt: v.number(),
  }).index("by_key", ["key"]),
});
