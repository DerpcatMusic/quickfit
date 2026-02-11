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
- Free-text lesson type auto-tagging to existing categories: `partial`
- Category chips without emoji/icon clutter: `live`
- Studio radius controls hidden outside instructor role: `live`
- Studio-facing auth/error/action copy localization coverage: `partial`
- Studio post-job sticky bottom submit CTA: `live`
- Studio jobs list query hot-path optimized to reduce timeout risk: `partial`
- Projection-backed studio jobs and instructor availability feed (with lifecycle sync + fallback): `partial`
- Post-job mutation success no longer blocked by studio jobs refresh timeout: `live`
- Instructor map studio markers show studio + posted-time context for open jobs: `live`
- Studio post-job verification requirement is explicitly configurable (defaults open): `live`
- Studio default base rate + lead-time surge settings (profile) wired to backend: `partial`

## Architecture Modernization
- Domain event outbox (`domainEvents`): `partial`
- Event consumer checkpoints: `partial`
- Studio/instructor projection read models: `partial`
- Payment/payout timeline projection: `planned`
- Legacy per-studio payment integration runtime dependency removal: `partial`

## Security and Operations
- Sealed secrets infra: `live`
- Legacy plaintext secret migration mutation: `live`
- Monitoring + alerting for webhooks/payout failures: `planned`
- Runbooks and incident procedures: `planned`

## Release Readiness (Production)
- End-to-end payment/payout sandbox test flow: `partial`
- Webhook delivery verification in production env: `partial`
- Ops visibility for `needs_attention` payouts: `planned`
