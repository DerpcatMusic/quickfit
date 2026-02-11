# Architecture Rethink (February 11, 2026)

## 1) Context And Assumptions
- Product goal: marketplace loop that is actually reliable: `studio posts job -> instructor claims -> studio accepts -> payment -> payout -> invoice`.
- Current deployment reality: backend is a single Convex codebase with several oversized domain files (`jobs.ts`, `payments.ts`, `payouts.ts`, `users.ts`).
- Immediate pain: studio posting/listing trust is low because failures/timeouts are perceived as silent.
- Team constraint: keep delivery speed high and avoid risky cross-service rewrites.

## 2) Candidate Architectures
### Option A: Keep current monolith and keep patching
- Upside: fastest short-term edits.
- Downside: reliability regressions continue; ownership and testing stay unclear.

### Option B: Modular monolith (recommended)
- Keep one Convex deployment.
- Split oversized files into strict domain modules with thin wrapper exports.
- Preserve existing function names and client contracts while reducing coupling.

### Option C: Full microservices split now
- Upside: isolated deploy units.
- Downside: too much complexity now (distributed consistency, auth propagation, webhook fan-out, ops overhead).

## 3) Recommended Architecture
- Use **modular monolith** now.
- Keep Convex entrypoint names stable (`jobs:*`, `claims:*`, `payments:*`, etc.).
- Extract logic into domain submodules:
  - `jobs/` (`posting`, `claims_flow`, `dispatch`, `read_models`, `queries`)
  - `payments/` (`checkout`, `webhooks`, `invoice_trigger`)
  - `payouts/` (`orchestration`, `execution`, `retries`)
  - `users/` (`auth_sync`, `profile`, `dispatch_preferences`, `studio_pricing`)
- Add one role-aware read endpoint for "my jobs" (`jobs:getMyJobs`) and keep role-specific wrappers only for compatibility.

## 4) Data Model And Consistency
- Source-of-truth tables remain:
  - `jobs`, `claims`, `payments`, `payouts`, `invoices`, `domainEvents`.
- Projection/read-model tables remain:
  - `readModel_studioJobs`, `readModel_instructorFeed`.
- Lifecycle invariants:
  - no `confirmed` job without accepted primary claim.
  - payment and payout transitions monotonic/idempotent.
  - webhook dedupe by provider event id and idempotency keys.

## 5) Reliability And Failure Handling
- UI must fail fast:
  - posting/listing gets timeout guard + visible error.
- Backend must never silently drift:
  - every job lifecycle write triggers projection sync.
- External integration handling:
  - webhook inbox/outbox patterns remain mandatory.
  - invoice creation remains async trigger from captured payment state.

## 6) Security And Compliance
- Authorization only from `ctx.auth.getUserIdentity()`.
- No trust in client-supplied user ids for ownership decisions.
- Keep sealed secrets for provider credentials.
- Keep auditable domain events for lifecycle changes.

## 7) Scalability And Cost Model
- Most expensive paths are:
  - studio/instructor list reads
  - geo/zone dispatch
  - webhook and payout retries
- Strategy:
  - projection-first reads for hot screens
  - minimize N+1 lookups on claims/studio joins
  - keep bounded retries with explicit dead-letter/attention states

## 8) Delivery Phases
1. **Stabilize posting and my-jobs UX**
   - posting timeout + explicit errors
   - shared `jobs:getMyJobs` endpoint for both roles
2. **Decompose jobs domain**
   - split `jobs.ts` into submodules with wrapper exports
   - keep API contracts unchanged
3. **Decompose payments/payouts domain**
   - isolate webhook processors and payout executor logic
4. **Finalize projection-only hot reads**
   - remove remaining legacy fallback reads after backfill + burn-in
5. **Production ship gate**
   - end-to-end staging flow: post -> claim -> accept -> pay -> payout -> invoice

## 9) Risks, Unknowns, Decisions (ADR Style)
- Decision: do **not** jump to microservices now.
- Risk: extraction introduces behavioral drift.
  - Mitigation: preserve wrapper exports and extend harness regression tests first.
- Risk: deployment mismatch causes "function not found" in clients.
  - Mitigation: every backend slice includes deploy + smoke run checklist.
- Unknown: provider-specific payout/invoice edge cases in production traffic.
  - Action: add explicit reconciliation dashboards before go-live.
