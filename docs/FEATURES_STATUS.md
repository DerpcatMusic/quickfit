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
- Backup claim/promotion lifecycle: `partial`
- Zone + radius dispatch: `partial`
- Offline mutation replay for claims: `partial`

## Verification
- Upload via Convex storage + ownership checks: `live`
- AI verification action integration: `partial`
- Admin/manual review UX completeness: `planned`

## Payments (Studio charge)
- Rapyd checkout creation (`rapyd:createCheckoutForJob`): `live`
- BitPay checkout action path: `partial`
- Payment ledger + webhook audit (`payments`, `paymentEvents`): `live`
- Webhook dedupe + replay hardening: `partial`

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

## Mobile Instructor Payments UX
- Payment history list: `live`
- Payment detail timeline: `live`
- Invoice open from detail: `live`
- Payout destination management screen: `live`
- Advanced payout status/explanations: `planned`

## Security and Operations
- Sealed secrets infra: `live`
- Legacy plaintext secret migration mutation: `live`
- Monitoring + alerting for webhooks/payout failures: `planned`
- Runbooks and incident procedures: `planned`

## Release Readiness (Production)
- End-to-end payment/payout sandbox test flow: `partial`
- Webhook delivery verification in production env: `partial`
- Ops visibility for `needs_attention` payouts: `planned`
