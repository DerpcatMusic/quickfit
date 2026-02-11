# Payments Execution Plan

## 1) Context and assumptions
- Product model: studio pays QuickFit; QuickFit takes a platform fee and pays the instructor.
- Stack: Convex backend, Flutter mobile, Firebase auth identity.
- Priorities: security, payout speed, and complete payment timeline visibility.
- Constraint: no studio-side deep payment integration required for core flow.

## 2) Candidate architectures
1. Direct PSP split payouts (Rapyd Connect-style)
- Pros: fewer internal payout steps.
- Cons: account/KYC complexity for instructors and provider coupling.

2. QuickFit-ledger + provider checkout + provider payout (recommended)
- Pros: strongest control, auditability, pluggable invoicing, fastest iteration.
- Cons: requires robust internal payout orchestration.

3. Dual-rail PSP + off-platform bank transfer fallback
- Pros: resiliency if one rail is down.
- Cons: higher ops overhead and reconciliation complexity.

## 3) Recommended architecture
- Use QuickFit-ledger as source of truth:
  - `payments` = charge lifecycle.
  - `paymentEvents` = webhook/audit trail.
  - `payoutDestinations` = instructor payout targets.
  - `invoices` = invoicing lifecycle.
- Webhooks update `payments` idempotently, then schedule invoice/payout steps only on state transitions.

## 4) Data model and consistency strategy
- Strong consistency for writes within each mutation.
- Idempotency keys:
  - Checkout creation: stable key per `(provider, studioId, jobId)` unless explicit key is supplied.
  - Webhooks: dedupe by provider event id.
- Ownership checks on every read/write: user must be studio or instructor bound to payment.

## 5) Reliability and failure handling
- Retries:
  - Provider webhook retries are safe due to event dedupe.
  - Internal scheduling only on `captured` transition.
- Degradation:
  - Payments can proceed even if invoicing is temporarily failing; invoice stays `failed` with retry path.

## 6) Security posture
- Identity source: `ctx.auth.getUserIdentity()` only.
- Webhook hardening:
  - signature verification,
  - strict timestamp skew window,
  - reject events without provider event id.
- Secrets:
  - payment rails are platform-managed via deployment env/sealed platform secrets.

## 7) Scalability and cost model
- Hot paths use indexes:
  - provider refs, user payment history, job payment lookup.
- Expected scale envelope:
  - 100k payments/month with webhook-driven updates is feasible on current indexed schema.
- Biggest cost drivers:
  - provider API calls and invoice provider API calls.

## 8) Delivery phases and migration plan
1. Phase A (done in current branch)
- Add missing payment detail/job/payout-destination APIs.
- Add payout destination schema/indexes.
- Harden webhooks and capture transition behavior.

2. Phase B
- Implement payout orchestration action and `payouts` ledger table.
- Add payout webhook/event ingestion.
- Add retry/backoff policies and dead-letter tracking.
 - Remove runtime dependency on per-studio payment provider configuration.

3. Phase C
- Add reconciliation job (provider balance vs local ledger).
- Add admin operations dashboard for failed payouts/invoices.

## 9) Risks and decision log
- Risk: webhook providers may vary event id semantics.
  - Mitigation: enforce provider event id and document provider-specific parser behavior.
- Risk: invoice URL may not be available for all providers.
  - Mitigation: keep `externalInvoiceId` canonical; URL optional.
- Decision: prefer backend-owned ledger over direct pass-through integration.
