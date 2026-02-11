# AGENTS.md

## Purpose
Operational guide for all coding agents working in `quickfit`.
This file defines architecture invariants, ownership boundaries, and required test gates.

## Current Architecture (Post-Refactor Baseline)

### Backend (Convex)
- Primary domain modules:
  - `backend/convex/jobs.ts`
  - `backend/convex/users.ts`
  - `backend/convex/verifications.ts`
  - `backend/convex/storage.ts`
  - `backend/convex/notifications.ts`
  - `backend/convex/geo.ts`
  - `backend/convex/zoneSubscriptions.ts`
- Schema source of truth:
  - `backend/convex/schema.ts`
  - Includes mutation replay dedupe table: `mutationIdempotency`
  - Includes upload registration session table: `uploadSessions`
- Actions:
  - `backend/convex/actions/geminiVerify.ts`
  - `backend/convex/actions/sendPush.ts`

### Mobile (Flutter)
- Auth/profile:
  - `apps/mobile/lib/features/auth/**`
- Jobs/claims:
  - `apps/mobile/lib/features/jobs/**`
  - `apps/mobile/lib/features/claims/**`
  - Canonical studio jobs provider: `apps/mobile/lib/features/jobs/providers/studio_jobs_provider.dart`
- Verification:
  - `apps/mobile/lib/features/verification/**`
- Shared services:
  - `apps/mobile/lib/core/services/**`
  - Offline replay canonical runner: `apps/mobile/lib/core/services/offline_mutation_runner.dart`
  - Offline queue coordination: `apps/mobile/lib/core/services/offline_queue_manager.dart`

## Non-Negotiable Invariants

1. Identity must come from `ctx.auth.getUserIdentity()`.
- Never trust client-provided identity values for authorization.

2. File access is ownership-based.
- Verification files must use `storageId` ownership checks via `userFiles`.
- Do not use arbitrary external URLs for trusted verification processing.
- `storage:registerUploadedFile` must validate a live `uploadToken` from `uploadSessions`.

3. Notification log types must remain schema-aligned.
- Any new notification type requires schema union update before use.

4. Job and claim lifecycle must stay consistent.
- A job cannot be `confirmed` without an accepted claim for the final primary instructor.
- Backup promotion must keep `jobs` and `claims` states aligned.

5. Domain writes should be centralized.
- Avoid duplicating lifecycle logic across multiple files.

6. Hot-path queries must be index-driven.
- Avoid DB `.filter(...)` on Convex hot paths when predicates can be expressed by indexes.
- Prefer `withIndex(... eq/lt/gt ...)` for predictable performance.

7. Write mutations that can be replayed must be idempotent.
- `jobs:claimJob` and `jobs:withdrawClaim` accept `idempotencyKey` and dedupe via `mutationIdempotency`.
- `claims:withdrawClaim` must forward idempotency to jobs internal idempotent withdrawal path.
- Offline replay must pass stable keys so network retries do not duplicate side effects.

8. Auth and routing state must be race-safe.
- Auth sync must not overwrite state for a user that has already logged out or switched accounts.
- Router redirects must wait for resolved role (`studio` or `instructor`) before role-protected navigation.

## API and Type-Safety Rules

1. Any backend API shape change must trigger:
- Convex codegen update.
- Flutter caller updates for payload and response handling.
- Tests updated for new contract.

2. Avoid `any` in domain paths.
- If unavoidable at integration boundaries, isolate and narrow immediately.

3. Prefer explicit typed errors over generic string errors.

## Testing Gate (Required Before Merge)

1. Backend:
- `backend/node_modules/.bin/tsc --noEmit -p backend/tsconfig.json`
- `npm --prefix backend test`

2. Mobile:
- `flutter analyze --no-pub apps/mobile`
- Relevant widget/integration tests for changed flows.

3. For lifecycle/security changes:
- Add or update tests in:
  - `backend/tests/test_harness.test.mjs`
  - `apps/mobile/integration_test/`
  - Include replay/idempotency coverage for offline queue retries on claim/withdraw flows.

4. For query/index refactors:
- Re-run backend typecheck and harness tests after schema index changes.
- Ensure call sites are switched to new compound indexes in the same change.

## High-Priority Ongoing Refactor Targets

1. Consolidate claim withdrawal and state transitions into one canonical path.
2. Make verification UI status backend-driven (not local-only state).
3. Unify offline replay logic between foreground and background sync.

## Agent Workflow Requirements

1. Before edits:
- Identify affected invariants from this file.

2. During edits:
- Update dependent schema/types/callers in same change set where possible.

3. After edits:
- Run required typecheck/analyze/tests.
- Report residual risks and follow-up items.
7. Offline replay must use one canonical execution path.
- Foreground queue and background sync must both route through `offline_mutation_runner.dart`.
- Use cooperative lock semantics to avoid duplicate processing.
