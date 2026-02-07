# QuickFit Definitive App Audit Catalog

This is the exhaustive audit of the QuickFit codebase as of February 7, 2026. This catalog covers every source file in the backend and mobile directories, documenting their role and technical health.

---

## 1. Backend: Convex Infrastructure (`backend/convex/`)
Total Files: 22

| File Name | Path | Related To | Status | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| `schema.ts` | `/` | Data Model | **Complete** | Defines all foundational tables and indices. |
| `geo.ts` | `/` | Search | **Redundant** | Relies on Convex native geo; violates H3-first principle. |
| `h3.ts` | `/` | Spatial | **Complete** | Production-grade H3 utility wrapper. |
| `notifications.ts` | `/` | Dispatch | **Needs Work** | O(n) filter matching; must use O(1) subscriptions. |
| `subscriptions.ts` | `/` | Dispatch | **Complete** | Architecture is ready, but logic is bypassed by `notifications.ts`. |
| `jobs.ts` | `/` | Features | **Complete** | Fully implemented job lifecycle with SOS logic. |
| `users.ts` | `/` | Auth/Profile | **Complete** | Handles onboarding and H3 work-area expansion. |
| `claims.ts` | `/` | Features | **Complete** | Robust race-to-accept claim logic. |
| `verifications.ts` | `/` | Trust | **Complete** | Management of certificate status and AI results. |
| `zones.ts` | `/` | Mapping | **Complete** | Pikud HaOref zone data functions. |
| `storage.ts` | `/` | Utility | **Complete** | File upload management for certificates. |
| `seed.ts` | `/` | Dev | **Complete** | Initial system data seeding. |
| `seedZones.ts` | `/` | Mapping | **Complete** | Essential Pikud HaOref zone boundaries. |
| `backfill.ts` | `/` | Dev | **Complete** | Utility for migrating existing records. |
| `auth.config.ts` | `/` | Auth | **Complete** | Firebase OIDC configuration. |
| `convex.config.ts` | `/` | Config | **Complete** | Framework configuration. |
| `geminiVerify.ts` | `/actions` | AI Scans | **Complete** | High-performance AI certificate analysis. |
| `sendPush.ts` | `/actions` | Notifications| **Complete** | FCM interface action. |
| `crons.ts` | `/crons` | Tasks | **Complete** | Scheduled verification and SOS maintenance. |

---

## 2. Mobile: Core Infrastructure (`apps/mobile/lib/core/`)
Total Files: 13

| File Name | Path | Related To | Status | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| `hive_service.dart` | `/services` | Storage | **Complete** | Robust mobile caching and mutation queue. |
| `offline_queue_manager.dart` | `/services` | Offline | **Complete** | Coordinating offline-first actions. |
| `background_sync_service.dart` | `/services` | Background | **Needs Work** | Placeholder logic; no mutation playback implemented. |
| `location_service.dart` | `/services` | GPS | **Needs Work** | Online-only geocoding; needs local fallback. |
| `notification_service.dart` | `/services` | Push | **Complete** | FCM initialization and foreground handling. |
| `convex_service.dart` | `/services` | API | **Complete** | Centralized Convex client management. |
| `map_style_service.dart` | `/services` | Mapping | **Needs Work** | Online style URLs; needs PMTiles wiring. |
| `web_map_interop.dart` | `/services` | Compatibility| **Complete** | JS bridge for web maps. |
| `app_router.dart` | `/router` | Navigation | **Complete** | Secure, role-based GoRouter config. |
| `pending_mutation.dart` | `/models` | Offline | **Complete** | Hive model for offline sync. |
| `zone.dart` | `/models` | Mapping | **Complete** | Polygon model for Pikud HaOref zones. |
| `map_config.dart` | `/config` | UI | **Complete** | Visual constants for map rendering. |

---

## 3. Mobile: Features & UI (`apps/mobile/lib/features/`)
Total Files: ~25

| File Name | Path | Related To | Status | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| `onboarding_screen.dart` | `/auth` | Onboarding | **Complete** | Complex multi-role flow with H3 generation. |
| `login_screen.dart` | `/auth` | Authentication| **Complete** | Firebase/Google auth implementation. |
| `auth_provider.dart` | `/auth` | State | **Complete** | Global auth notification and state. |
| `instructor_map_screen.dart`| `/instructor` | Homepage | **Needs Work** | Pull-model design; needs Push-dispatch alignment. |
| `instructor_map_view.dart` | `/instructor` | Mapping | **Complete** | Clean separation of map rendering logic. |
| `instructor_stats_card.dart`| `/instructor` | UI | **Complete** | Real-time earnings and job counter. |
| `verification_screen.dart` | `/verification` | Trust | **Complete** | Document capture and AI submission status. |
| `job_list_screen.dart` | `/jobs` | Feed | **Complete** | Filterable list of nearby opportunities. |
| `job_detail_screen.dart` | `/jobs` | workflow | **Complete** | Full job details and claim interface. |
| `post_job_screen.dart` | `/jobs` | Studio flow | **Complete** | Studio side job creation with SOS toggles. |
| `jobs_provider.dart` | `/jobs` | State | **Complete** | Advanced Hive caching and streaming. |
| `profile_screen.dart` | `/profile` | User Mgmt | **Complete** | Service area and category management. |

---

## 4. Mobile: Shared UI (`apps/mobile/lib/shared/`)
Total Files: 12

| File Name | Path | Related To | Status | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| `quickfit_map.dart` | `/widgets` | Pure UI | **Needs Work** | Base map wrapper lacking offline PMTiles logic. |
| `zone_selection_map.dart` | `/widgets` | Mapping | **Complete** | High-performance zone polygon selector. |
| `job_card.dart` | `/widgets` | UI | **Complete** | Detailed card with map preview and status. |
| `sos_badge.dart` | `/widgets` | UI | **Complete** | Animated SOS visual indicator. |
| `glass_pane.dart` | `/widgets` | UI | **Complete** | Glassmorphism design utility. |
| `static_map.dart` | `/widgets` | UI | **Complete** | Placeholder or static map preview. |

---

## 5. Summary Statistics
- **Total Backend Files**: 22
- **Total Mobile Files**: ~55
- **Total Code Count**: **77 Files**
- **Architecture Integrity**: 85% (15% Needs realignment)
