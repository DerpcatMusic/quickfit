# AGENT.md - QuickFit AI Contributor Playbook

This file is the required operating guide for any AI agent working in this repository.
If you are a new agent session, read this file first.

## 1) Mission and Scope

QuickFit is a Flutter + Convex marketplace for studios and substitute fitness instructors.
Primary codebase targets:

- Mobile app: `apps/mobile`
- Backend (Convex): `backend/convex`

Legacy/root files (for example root `README.md`) may describe old PMTiles tooling and are not the primary product implementation path.

## 1.1) Tooling Policy (Bun-First)

Use Bun as the default JavaScript/TypeScript runtime and package manager.

- Use `bun install` instead of `npm install`
- Use `bun run <script>` instead of `npm run <script>`
- Use `bunx <cmd>` instead of `npx <cmd>`
- Do not introduce new npm/npx-based scripts unless Bun is incompatible

## 2) Mandatory Session Startup (Every New AI Session)

1. Recon the codebase in parallel before proposing implementation:
- Mobile structure and entrypoints under `apps/mobile/lib`
- Backend structure and domains under `backend/convex`
- Product/architecture docs: `FEATURES.md`, `architecture.md`, `docs/`
2. Ignore generated/artifact-heavy paths unless needed for debugging:
- `backend/node_modules`
- `apps/mobile/.dart_tool`
- `apps/mobile/build`
3. Post a short implementation plan before editing code:
- Problem statement
- Files likely to change
- Validation steps
- Risks/rollback approach

## 3) Canonical Project Layout

- `apps/mobile/lib/main.dart`: mobile bootstrap (Firebase/Convex/services startup)
- `apps/mobile/lib/app.dart`: app shell, theme, localization
- `apps/mobile/lib/core/router/app_router.dart`: routing and auth redirects
- `apps/mobile/lib/core/providers`: Riverpod global providers
- `apps/mobile/lib/features`: feature modules (auth, jobs, instructor, studio, claims, verification)
- `apps/mobile/test`: unit/widget tests
- `apps/mobile/integration_test`: end-to-end app flows
- `backend/convex/schema.ts`: data model and indexes
- `backend/convex/jobs.ts`: job lifecycle and dispatch orchestration
- `backend/convex/notifications.ts`: push + dispatch notifications
- `backend/convex/users.ts`: user profile, instructor mode/location behavior
- `backend/convex/verifications.ts`: verification lifecycle
- `backend/convex/actions/geminiVerify.ts`: AI verification action
- `backend/convex/actions/sendPush.ts`: push integration
- `backend/convex/testHarness.ts`: backend integration harness
- `backend/tests/test_harness.test.mjs`: backend test runner

## 4) Required Feature Workflow (Branch -> Commits -> PR)

### Branching

Use one branch per feature/fix from latest `main`:

- Feature: `feat/<area>-<short-slug>`
- Fix: `fix/<area>-<short-slug>`
- Chore: `chore/<area>-<short-slug>`

Examples:
- `feat/mobile-job-claim-flow`
- `fix/backend-dispatch-retry-window`

### Commit Rules

Commit in small, reviewable slices using conventional prefixes:

- `feat(mobile): add studio job filter chip`
- `fix(backend): prevent duplicate claim acceptance`
- `refactor(router): split instructor shell routes`
- `test(dispatch): cover retry backoff edge case`
- `docs(agent): update feature checklist`

### Pull Request Rules

Every feature PR must include:

1. What changed and why (user-visible + technical summary)
2. Risk assessment (behavioral regressions and impacted flows)
3. Validation evidence (commands run + results)
4. Rollback plan (how to revert safely)
5. Follow-ups (explicitly deferred work)

Preferred merge strategy: squash merge after approvals.

## 5) Validation Matrix (Run What Applies)

Mobile (`apps/mobile`):

- `flutter analyze`
- `flutter test`
- `flutter test integration_test` (when route/flow changes)
- `dart run build_runner build --delete-conflicting-outputs` (when Riverpod generated code changes)

Backend (`backend`):

- `bun run test`
- `bunx tsc --noEmit` (if TS/API surface changed)
- Targeted Convex harness runs when dispatch/notifications/verification logic changes

## 6) Cross-Cutting Change Rules

If a feature spans mobile + backend:

1. Update backend contract first (schema/function signatures)
2. Update mobile callers and routing/state usage
3. Add/adjust tests on both sides
4. Document any API or behavior changes in PR notes

For dispatch, geo, claims, notifications, or verification flows:

- Explicitly test failure paths and retries
- Avoid silent behavior changes without logs/telemetry updates

## 7) Definition of Done (AI Must Enforce)

A feature is done only when all are true:

1. Plan posted before edits
2. Code implemented with focused commits
3. Relevant validation commands run
4. PR description prepared with risk + rollback notes
5. Any workflow/process updates reflected in this `AGENT.md` if needed

## 8) Feature Plan Template (Use Every Time)

When starting a feature, post:

1. Goal and constraints
2. Files/modules to change
3. Step-by-step implementation plan
4. Test/validation plan
5. Risks and mitigation

Then execute and report results against this plan.
