# Features Status

This document is the single source of truth for what exists now vs what we still need.

Legend:
- `live`: usable in app now
- `partial`: implemented but missing reliability/ops/completeness
- `planned`: accepted but not implemented
- `blocked`: blocked by dependency/legal/provider

## Marketplace Core
- Auth + user sync: `live`
- Onboarding (studio/instructor): `live`
- Job posting/claiming/responding/canceling: `live`
- Studio job completion mutation + UI action: `live`
- Post-job rating submission API: `partial`
- Public studio profile with visible available jobs: `live`
- Backup claim/promotion lifecycle: `partial`
- Zone + radius dispatch: `partial`
- Offline mutation replay for claims: `partial`
- User-scoped offline queue semantics: `partial`

## Verification
- Upload via Convex storage + ownership checks: `live`
- AI verification action integration: `partial`
- Admin/manual review UX completeness: `planned`

## Payments (Platform-Managed)
- Rapyd checkout creation (`rapyd:createCheckoutForJob`): `live`
- BitPay checkout action path: `blocked` (disabled pending payout rail parity)
- Payment ledger + webhook audit (`payments`, `paymentEvents`): `live`
- Webhook dedupe + replay hardening: `partial` (signature-validated dedupe + uncapped reprocess)
- Studio-configurable payment provider setup UI: `live` (removed from studio flow)
- Event-driven webhook inbox processing: `planned`

## Payouts (Instructor disbursement)
- Payout destination CRUD (`payoutDestinations`): `live`
- Payout orchestration + retries (`payouts.ts`): `live`
- Rapyd payout webhook lifecycle update: `live`
- Refund -> payout attention flagging: `live`
- Payout reconciliation dashboard/admin tools: `planned`

## Invoicing
- Invoicing integration model + issue pipeline: `partial`
- Morning/iCount production-grade adapters: `planned`
- Invoice URL/deep integration consistency: `partial`
- Studio billing settings timeout retry loop guarded in mobile profile: `live`

## Mobile Instructor Payments UX
- Payment history list: `live`
- Payment detail timeline: `live`
- Invoice open from detail: `live`
- Payout destination management screen: `live`
- Advanced payout status/explanations: `planned`

## Mobile Marketplace UX
- Instructor map studio-pin tap -> studio public profile: `live`
- Studio profile quick access to own available jobs: `live`
- Profile header can apply Google/Apple account photo into backend avatar field: `live`
- Free-text lesson type auto-tagging to existing categories: `partial`
- Free-text lesson type auto-tagging now scores English + Hebrew synonyms before selecting category: `partial`
- Category chips without emoji/icon clutter: `live`
- Post-job category chips are l10n-backed (no hardcoded category labels): `live`
- Studio radius controls hidden outside instructor role: `live`
- Studio-facing auth/error/action copy localization coverage: `partial`
- Hebrew localization coverage expanded for studio jobs, post-job, public profile, and job detail flows: `partial`
- Studio billing/invoicing sheet extracted to feature module and localized (no hardcoded UI copy): `live`
- Studio post-job sticky bottom submit CTA: `live`
- Job detail completion and rating dialog flows are localized (no hardcoded action copy): `live`
- Studio jobs list query hot-path optimized to reduce timeout risk: `partial`
- Studio jobs list read now uses canonical `jobs` index fallback even when projections are missing: `live`
- Projection-backed studio jobs and instructor availability feed (with lifecycle sync + fallback): `partial`
- Role-aware `jobs:getMyJobs` endpoint shared by studio/instructor "my jobs" flows: `partial`
- Instructor `jobs:getMyJobs` claim hydration bounded, window-gated, and batched by job/studio IDs to avoid timeout-prone N+1 reads: `partial`
- Studio `My Jobs` loading watchdog + bootstrap fallback (prevents infinite spinner): `live`
- Studio jobs bootstrap now falls back to legacy query only when `jobs:getMyJobs` is missing (not on transient timeout): `live`
- Studio post-job mutation timeout guard with explicit failure surface: `live`
- Post-job mutation success no longer blocked by studio jobs refresh timeout: `live`
- Studio post-job zoneId backfill after detection timeout (restores zone dispatch/map after best-effort post): `partial`
- Zone backfill now triggers deduped redispatch for newly eligible instructors without re-notifying prior recipients: `partial`
- Instructor map studio markers show studio + posted-time context for open jobs: `live`
- Instructor map radius mode falls back to canonical `jobs:getJobsForMap` if geo feed fails: `live`
- Studio post-job verification requirement is explicitly configurable (defaults open): `live`
- Studio default base rate + lead-time surge settings (profile) wired to backend: `partial`
- Post-job form now applies studio default base rate unless user manually overrides rate: `live`

## Architecture Modernization
- Domain event outbox (`domainEvents`): `partial`
- Event consumer checkpoints: `partial`
- Studio/instructor projection read models: `partial`
- Payment/payout timeline projection: `planned`
- Backend domain modularization (wrapper exports + extracted internals): `partial`
- Shared backend auth guard/error standardization utilities (adopted in `users.ts`/`billing.ts`): `partial`
- Legacy per-studio payment integration runtime dependency removal: `partial`

## Security and Operations
- Sealed secrets infra: `live`
- Legacy plaintext secret migration mutation: `live`
- Monitoring + alerting for webhooks/payout failures: `planned`
- Runbooks and incident procedures: `planned`

## Release Readiness (Production)
- End-to-end payment/payout sandbox test flow: `partial`
- Backend test harness runtime now deterministic across local push-config variance: `live`
- Webhook delivery verification in production env: `partial`
- Ops visibility for `needs_attention` payouts: `planned`
