# Product Roadmap

This roadmap now tracks the migration to a SaaS-grade, event-driven architecture.

Status values:
- `planned`
- `partial`
- `live`
- `blocked`

## Phase 0: UX and Auth Stabilization (Start Now)

### RM-100 Remove Studio Payment Provider Setup (Platform-Managed Payments)
- Status: `live`
- Owner: Mobile + Backend
- Goal: Studios should never configure Rapyd/BitPay.
- Exit criteria:
  - Studio billing UI shows payment rails as platform-managed only.
  - `Connect Rapyd` / `Connect BitPay` removed from studio UI.
  - Any remaining studio-payment integration API paths are marked deprecated.

### RM-101 Auth Session Hardening (Web + Mobile)
- Status: `partial`
- Owner: Mobile
- Goal: eliminate silent auth/session drift causing empty job lists or failed posting.
- Exit criteria:
  - Studio job/post screens fail fast with explicit auth-required state.
  - Studio-only radius controls are not exposed in studio profile flows.
  - Studio auth-required surfaces are localized (no hardcoded fallback strings).
  - Studio jobs list query avoids timeout-prone N+1 claim lookups on hot path.
  - Instructor `jobs:getMyJobs` claim hydration is bounded on indexed reads to prevent timeout under long history.
  - Studio post action reports success even if follow-up list refresh times out.
  - Studio `My Jobs` screen cannot remain in indefinite loading state (watchdog + query bootstrap).
  - Studio `My Jobs` provider must tolerate dynamic subscription payloads and still terminate loading/error state deterministically.
  - Studio and instructor "my jobs" clients can consume a role-aware shared query endpoint.
  - Studio jobs bootstrap should not downgrade to legacy query path on transient timeout.
  - Post-job recovers zone assignment asynchronously when inline zone detection times out.
  - Profile billing bootstrap does not retry timeouting queries on every rebuild.
  - Profile settings can apply provider account photo (Google/Apple) into backend avatar URL.
  - Foreground offline sync binds Convex auth before replay.
  - Sign-out clears/quarantines pending mutations by user scope.

### RM-102 Offline Queue Correctness
- Status: `partial`
- Owner: Mobile
- Goal: no cross-user replay, no dead failed queue entries.
- Exit criteria:
  - Queue is user-scoped (`pending_mutations_<uid>`).
  - Failed mutations can be retried deterministically.
  - Pending job actions disable duplicate gesture-triggered mutations.

### RM-103 Job Completion + Ratings Lifecycle
- Status: `partial`
- Owner: Backend + Mobile
- Goal: close the loop from confirmed job to completed job and two-way feedback.
- Exit criteria:
  - Studio can mark confirmed jobs as completed from app surfaces.
  - Studio can control verified-only vs open-instructor eligibility when posting jobs.
  - Studio can configure default base rate and lead-time surge rules for new jobs.
  - Post-job rate field initializes from studio defaults unless manually overridden.
  - Post-job lesson free-text auto-tagging recognizes English/Hebrew category synonyms.
  - Ratings can be submitted exactly once per side per completed job.
  - Rating UX is localized and available to both studio and instructor.

### RM-104 Studio Discovery and Public Profile
- Status: `partial`
- Owner: Backend + Mobile
- Goal: make studio availability discoverable from map and profile surfaces.
- Exit criteria:
  - Instructor can tap studio pin and open public studio profile.
  - Public studio profile shows currently available jobs.
  - Instructor map markers include studio name and recency (posted-time) context.
  - Instructor map radius mode has fallback fetch path if geospatial stream errors.
  - Studio profile includes direct access to own available jobs view.

## Phase 1: Event Backbone (Domain Outbox)

### RM-110 Domain Event Log Introduction
- Status: `partial`
- Owner: Backend
- Goal: every critical lifecycle write emits immutable domain events.
- Exit criteria:
  - `domainEvents` table added with indexes and replay metadata.
  - Jobs/claims/payments/payouts mutations emit canonical events.
  - Event emission covered by tests.

### RM-111 Consumer Checkpoints + Idempotent Processors
- Status: `partial`
- Owner: Backend
- Goal: deterministic event consumption under retries/duplicates.
- Exit criteria:
  - `eventConsumers` checkpoint table live.
  - Worker processors are idempotent with lock/version guards.
  - Replay command can safely reprocess a bounded range.

## Phase 2: Read Models and Caching

### RM-120 Studio and Instructor Read Models
- Status: `partial`
- Owner: Backend + Mobile
- Goal: remove N+1 list queries and provide predictable low-latency reads.
- Exit criteria:
  - `readModel_studioJobs` and `readModel_instructorFeed` in place with lifecycle sync hooks. ✅
  - Mobile list/map feeds switched to projection-backed queries with legacy fallback during backfill. ✅
  - Studio dashboard reads remain correct when projections are partial by falling back to canonical `jobs` index during burn-in. ✅
  - Old hot-path query joins removed (remaining legacy fallback paths removed after backfill + burn-in).

### RM-121 Payment and Payout Timeline Projection
- Status: `planned`
- Owner: Backend + Mobile
- Goal: single source timeline from payment created to payout terminal state.
- Exit criteria:
  - `readModel_paymentTimeline` projection built from events.
  - Instructor payment detail uses projected timeline.
  - Invoice attachment references included in timeline nodes.

## Phase 3: Webhooks and Async Integration Processing

### RM-130 Webhook Inbox Pattern
- Status: `planned`
- Owner: Backend
- Goal: webhook ingestion is always durable and fast-ack.
- Exit criteria:
  - `webhookInbox` table added with dedupe keys.
  - HTTP handlers persist event then return quickly.
  - Async processors apply business transitions from inbox records.

### RM-131 Payment/Payout Reconciliation Worker
- Status: `partial`
- Owner: Backend
- Goal: out-of-order provider events converge automatically.
- Exit criteria:
  - Unmatched events reprocessed to completion (not capped single pass). ✅
  - Stuck payouts flagged with reason and retry tooling.
  - Alerting hooks for repeated terminal failures.

## Phase 4: Ops, Security, and Cost Efficiency

### RM-140 Studio Payment Integrations Deprecation
- Status: `partial`
- Owner: Backend/Ops
- Goal: fully remove old per-studio payment architecture.
- Exit criteria:
  - `studioPaymentIntegrations` no longer required by runtime logic.
  - Fallback to platform env/sealed secrets only for payment rails.
  - Data migration and cleanup script executed.

### RM-141 Observability and SLOs
- Status: `planned`
- Owner: Backend/Ops
- Goal: production-grade reliability controls.
- Exit criteria:
  - SLO dashboards for posting/claiming/payment/payout flows.
  - Alert policies for webhook lag, payout retry storms, failed projections.
  - Runbook and incident playbooks checked in.

## Phase 5: Ship Gate and Competitive Differentiation

### RM-150 Production Readiness Gate
- Status: `planned`
- Owner: Product + Engineering
- Goal: objective go/no-go on reliability and UX quality.
- Exit criteria:
  - Full E2E staging run (post -> claim -> pay -> payout -> invoice -> timeline).
  - Security and replay/idempotency checks signed off.
  - Rollback and forward-fix procedures verified.

### RM-151 Competitive UX: Marketplace Grade Studio Console
- Status: `planned`
- Owner: Mobile + Product
- Goal: studio UX parity/superiority vs category competitors.
- Exit criteria:
  - Unified design system across studio and instructor experiences.
  - Fast list filters/search and robust empty/error states.
  - Payment/invoice transparency embedded into job history UI.

## Phase 6: Modularization and Boundary Hardening

### RM-160 Backend Modular Monolith Decomposition
- Status: `partial`
- Owner: Backend
- Goal: reduce oversized Convex domain files while preserving API contracts.
- Exit criteria:
  - `jobs.ts`, `payments.ts`, `payouts.ts`, and `users.ts` delegate to extracted domain modules.
  - Existing function names remain stable for mobile clients.
  - Lifecycle and idempotency tests pass unchanged or stronger.

### RM-161 Shared Role-Aware Jobs Read Contract
- Status: `partial`
- Owner: Backend + Mobile
- Goal: one canonical "my jobs" contract for studios and instructors.
- Exit criteria:
  - `jobs:getMyJobs` powers both roles in mobile clients (with temporary compatibility fallback removed after burn-in).
  - Studio and instructor "my jobs" screens use consistent lifecycle semantics.
  - Studio loading UX has deterministic timeout/error behavior.

### RM-162 Flutter Feature Modularization + Localization Hardening
- Status: `partial`
- Owner: Mobile
- Goal: reduce monolithic UI surfaces and eliminate hardcoded strings in studio/payment-critical flows.
- Exit criteria:
  - Studio billing sheet lives under feature-owned module (`features/studio/billing/**`) with shared adapter only.
  - Hardcoded billing/payment copy removed from studio-facing widgets and covered by l10n regression tests.
  - Post-job category labels are sourced from l10n keys (no hardcoded category chip labels).
  - Top hotspot screens (`profile`, `onboarding`, `post_job`) begin section/widget extraction with clear ownership boundaries.

## Active Priority Order
1. RM-101
2. RM-102
3. RM-110
4. RM-111
5. RM-120
6. RM-140
7. RM-160
8. RM-161
