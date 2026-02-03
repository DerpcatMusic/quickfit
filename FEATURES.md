# QuickFit - Feature Audit 2026

This document compares the **current implementation** against the **ideal feature set** and defines priorities.

---

## Legend
- ✅ **Implemented** - Working in production
- 🟡 **Partial** - Scaffolded but not fully functional
- ❌ **Missing** - Not yet built
- 🔴 **Critical** - Must be functional for MVP

---

## 1. Trust & Verification Engine

| Feature | Status | Current State | Priority |
|---------|--------|---------------|----------|
| AI Cert-Scanner (Gemini 2.0) | 🟡 | Schema exists with `aiAnalysis` field; action scaffolded | 🔴 |
| Insurance Expiry Guard | ❌ | No insurance fields in schema | Medium |
| Biometric ID Match (Passkey) | ❌ | Using Firebase Auth, no Passkey | Low |
| Studio Geo-Fence Check | ❌ | No physical presence verification | Medium |
| Double-Blind Rating System | 🟡 | `ratings` table exists; UI missing | Medium |

---

## 2. Instructor-Side Features

| Feature | Status | Current State | Priority |
|---------|--------|---------------|----------|
| Real-time Job Feed | ✅ | `getNearbyJobs` query with Convex reactivity | - |
| H3 Neighborhood Search | 🟡 | H3 index stored; hex-neighbor filtering incomplete | 🔴 |
| SOS Priority Mode (+20% bonus) | 🟡 | `sosBoostApplied` field; cron job scaffolded | 🔴 |
| Smart Portfolio | ❌ | No auto-generated portfolio from certs | Low |
| Calendar Auto-Sync | ❌ | No calendar integration | Medium |
| One-Tap Claiming | ✅ | `claimJob` mutation with optimistic UI | - |
| **Map Homepage with Radius** | 🟡 | `instructor_map_screen.dart` exists but placeholder | 🔴 |
| Job Stats Dashboard | ❌ | No "jobs taken" counter on homepage | 🔴 |

---

## 3. Studio-Side Features

| Feature | Status | Current State | Priority |
|---------|--------|---------------|----------|
| Instant-Post Templates | ❌ | No template system | Medium |
| Dynamic Pay Suggestions | ❌ | No market rate algorithm | Low |
| Instructor Deep-Dive | 🟡 | Profile query exists; no cert viewing | Medium |
| Waitlist Logic | ❌ | No standby queue system | Low |
| Auto-Invoicing | ❌ | No invoice generation | Low |
| Post Job UI | ✅ | `post_job_screen.dart` implemented | - |
| View My Jobs | 🟡 | `getStudioJobs` query exists; UI incomplete | Medium |

---

## 4. Advanced Features (2026 Secret Sauce)

| Feature | Status | Current State | Priority |
|---------|--------|---------------|----------|
| Wearable Sync (Oura/Watch) | ❌ | Not started | Low |
| H3 Demand Heatmaps | ❌ | No heatmap visualization | Medium |
| Escrow Payment System | ❌ | No payment infrastructure | Low |
| Fraud Detection (Ghost Claiming) | ❌ | No GPS telemetry monitoring | Low |
| Push Notifications | 🟡 | FCM setup; `sendNotification` action incomplete | 🔴 |
| Skill-Based Job Matching | 🟡 | Categories stored; filtering by skill incomplete | 🔴 |

---

## 5. Technical Infrastructure

| Component | Status | Current State | Priority |
|-----------|--------|---------------|----------|
| **Flutter Features Structure** | ✅ | `lib/features/` with proper separation | - |
| **Convex Backend** | ✅ | Schema + functions deployed | - |
| **H3 Spatial Indexing** | 🟡 | lib/h3.ts exists; neighbor search missing | 🔴 |
| **Firebase Auth** | 🟡 | Working on mobile; web OAuth issues | 🔴 |
| **Type-Safe Contracts** | 🟡 | TypeScript types; Flutter codegen missing | Medium |
| **RTL/Hebrew Support** | 🟡 | Localization added; not all screens RTL-safe | Medium |

---

## Current Backend Schema (Convex)

| Table | Fields | Indexes | Status |
|-------|--------|---------|--------|
| `users` | firebaseUid, role, h3Index, radiusKm, categories, fcmToken | by_firebaseUid, by_h3, by_verified | ✅ |
| `jobs` | studioId, category, h3Index, status, claimedBy, sosBoostApplied | by_status, by_h3_status, by_category_status | ✅ |
| `claims` | jobId, instructorId, distanceKm, status | by_job, by_instructor | ✅ |
| `verifications` | userId, docUrl, aiAnalysis, status | by_user, by_status | ✅ |
| `sosPriorityQueue` | jobId, hoursUntilStart, boostPercentage | by_processed | ✅ |
| `ratings` | jobId, fromUserId, toUserId, rating | by_toUser, by_job | ✅ |
| `notificationLogs` | userId, jobId, type, sent | by_user, by_job | ✅ |

---

## Current Flutter Screens

| Screen | Location | Status |
|--------|----------|--------|
| Login | `auth/presentation/login_screen.dart` | ✅ |
| Onboarding | `auth/presentation/onboarding_screen.dart` | ✅ |
| Job List | `jobs/presentation/job_list_screen.dart` | ✅ |
| Post Job | `jobs/presentation/post_job_screen.dart` | ✅ |
| Instructor Map | `instructor/screens/instructor_map_screen.dart` | 🟡 Placeholder |
| Profile | `profile/presentation/profile_screen.dart` | 🟡 |
| Verification | `verification/presentation/verification_screen.dart` | 🟡 |

---

## Priority Implementation Order

### Phase 1: Core MVP (Critical Path)
1. **Fix Web OAuth** - Run on port 5000 matching origins
2. **Instructor Map Homepage** - Full map with radius visualization
3. **H3 Neighbor Search** - True hex-distance filtering
4. **Job Stats Dashboard** - "X jobs taken" counter
5. **Push Notifications** - Notify based on skills + radius

### Phase 2: Verification Flow
1. **Gemini Cert Scanner** - OCR integration
2. **Verification UI** - Upload + review workflow
3. **Rating System** - Post-job feedback

### Phase 3: Advanced Features
1. **SOS Boost Cron** - Auto-apply 20% bonus
2. **Calendar Sync** - Google/Apple integration
3. **Payment System** - Stripe/escrow

---

## File Structure (Current)

```
quickfit/
├── apps/mobile/lib/
│   ├── core/
│   │   ├── router/app_router.dart
│   │   ├── theme/app_theme.dart, app_colors.dart
│   │   ├── services/location_service.dart, notification_service.dart
│   │   └── constants/app_constants.dart
│   ├── features/
│   │   ├── auth/         # Login, Onboarding, AuthProvider
│   │   ├── jobs/         # Job list, Post job, JobsProvider
│   │   ├── instructor/   # Map screen (placeholder)
│   │   ├── profile/      # Profile screen
│   │   └── verification/ # Verification screen
│   ├── shared/
│   │   ├── widgets/      # JobCard, SosBadge, GoogleSignInButton
│   │   └── layouts/      # AppScaffold
│   └── data/models/      # Job model
├── backend/convex/
│   ├── schema.ts         # 7 tables
│   ├── users.ts          # User CRUD, location
│   ├── jobs.ts           # Job CRUD, claiming
│   ├── claims.ts         # Claim logic
│   ├── verifications.ts  # Cert verification
│   ├── notifications.ts  # FCM push
│   └── lib/h3.ts         # H3 utilities
└── web/index.html        # OAuth client ID
```

---

## Next Steps

See [implementation_plan.md](./implementation_plan.md) for detailed plan.
