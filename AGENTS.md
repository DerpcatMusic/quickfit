# AGENTS.md

## Purpose
Operational guide for coding agents in `quickfit`.
This file defines architecture invariants, delivery gates, and roadmap workflow.

## Current Architecture (Live Baseline)

### Backend (Convex)
Primary domain modules:
- `backend/convex/users.ts`
- `backend/convex/jobs.ts`
- `backend/convex/claims.ts`
- `backend/convex/notifications.ts`
- `backend/convex/verifications.ts`
- `backend/convex/storage.ts`
- `backend/convex/geo.ts`
- `backend/convex/zoneSubscriptions.ts`
- `backend/convex/payments.ts`
- `backend/convex/payouts.ts`
- `backend/convex/billing.ts`
- `backend/convex/invoicing.ts`
- `backend/convex/rapyd.ts`
- `backend/convex/bitpay.ts`
- `backend/convex/webhooks.ts`
- `backend/convex/http.ts`

Schema source of truth:
- `backend/convex/schema.ts`

Key schema domains:
- Marketplace core: `users`, `jobs`, `claims`
- Verification and files: `verifications`, `userFiles`, `uploadSessions`
- Dispatch: `zones`, `zoneSubscriptions`
- Reliability: `mutationIdempotency`
- Payments: `payments`, `paymentEvents`, `payoutDestinations`, `payouts`, `payoutEvents`, `invoices`
- Integrations: `studioPaymentIntegrations`, `studioBillingIntegrations`

### Mobile (Flutter)
- Auth/profile: `apps/mobile/lib/features/auth/**`, `apps/mobile/lib/features/profile/**`
- Jobs/claims: `apps/mobile/lib/features/jobs/**`
- Verification: `apps/mobile/lib/features/verification/**`
- Instructor payments: `apps/mobile/lib/features/instructor/payments/**`
- Shared services: `apps/mobile/lib/core/services/**`
  - Canonical offline runner: `apps/mobile/lib/core/services/offline_mutation_runner.dart`
  - Queue coordination: `apps/mobile/lib/core/services/offline_queue_manager.dart`

## Non-Negotiable Invariants

1. Identity and auth
- Authorization must derive from `ctx.auth.getUserIdentity()`.
- Never trust client-supplied user IDs for authorization.

2. File ownership and verification safety
- Verification file access must validate ownership through `userFiles` and `storageId`.
- `storage:registerUploadedFile` must validate a live `uploadToken` from `uploadSessions`.

3. Domain lifecycle consistency
- Jobs/claims transitions must remain coherent (no confirmed job without accepted final primary claim).
- Payment lifecycle transitions must remain monotonic/idempotent.
- Payout lifecycle must be idempotent and auditable.

4. Index-driven hot paths
- Do not use DB `.filter(...)` on hot paths when index predicates are possible.
- Prefer `withIndex(... eq/lt/gt ...)`.

5. Idempotent replay-safe writes
- Offline/network-retried mutations must support idempotency keys.
- Webhook processing must dedupe by provider event id and protect against payload replay.

6. Secret handling
- Prefer sealed credentials (`sealedApiToken`, `sealedApiKey`, `sealedWebhookSecret`).
- Plaintext legacy fields must be migrated/cleared.

7. Mobile auth/routing race safety
- Auth sync cannot overwrite state after logout/account switch.
- Role-guarded routing must wait for resolved role.

## API and Type-Safety Rules

1. Backend API shape changes must include:
- Convex codegen update.
- Flutter caller updates.
- Test updates.

2. Keep domain paths strongly typed.
- Avoid `any` unless isolated at boundary and narrowed immediately.

3. Prefer typed/domain-specific error semantics over generic strings.

## Required Verification Gate (Before Merge)

Backend:
- `backend/node_modules/.bin/tsc --noEmit -p backend/tsconfig.json`
- `npm --prefix backend test` (or `bun --cwd backend test`)

Mobile:
- `flutter analyze --no-pub apps/mobile`
- Relevant widget/integration tests for changed flows.

For lifecycle/security/payment changes:
- Add or update backend tests in `backend/tests/`
- Include replay/idempotency coverage where applicable.

## Roadmap Workflow (Mandatory)

Source docs:
- `docs/FEATURES_STATUS.md`
- `docs/PRODUCT_ROADMAP.md`

Rules:
1. Every meaningful feature change must update `docs/FEATURES_STATUS.md`.
2. Every multi-step initiative must exist in `docs/PRODUCT_ROADMAP.md` with owner, phase, and exit criteria.
3. PRs must state:
- Which roadmap item(s) they advance.
- Which invariants are affected.
- What risks remain.

Statuses used in roadmap/docs:
- `live`
- `partial`
- `planned`
- `blocked`

## Agent Workflow Requirements

Before edits:
- Identify affected invariants and roadmap items.

During edits:
- Update dependent schema/types/callers in same change set when feasible.

After edits:
- Run required checks.
- Report residual risks and follow-up tasks.
