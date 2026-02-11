# Product Roadmap

This is the execution system for product delivery.

How to use:
1. Every roadmap item has an owner, status, and exit criteria.
2. PRs must reference the roadmap item ID.
3. Move status only when exit criteria are met.

Status values:
- `planned`
- `in_progress`
- `done`
- `blocked`

## Phase 0: Stabilize Core Payment Rails

### RM-001 Payment Webhook Reliability
- Status: `in_progress`
- Owner: Backend
- Goal: Never lose payment state due to out-of-order or duplicate webhooks.
- Exit criteria:
  - Replay-safe dedupe in place.
  - Unmatched webhook reprocessing path in place.
  - Tests covering duplicate + late-arrival events.

### RM-002 Payout Lifecycle Completeness
- Status: `in_progress`
- Owner: Backend
- Goal: Payouts move from queued to terminal states reliably.
- Exit criteria:
  - Payout orchestration + retries live.
  - Payout webhook updates live.
  - Refund transition flags payout `needs_attention`.

### RM-003 Secrets Hardening Migration
- Status: `in_progress`
- Owner: Backend/Ops
- Goal: Remove plaintext provider credentials from active usage.
- Exit criteria:
  - `billing:migrateLegacyPlaintextSecrets` executed.
  - Sealed fields verified populated.
  - Legacy plaintext fields nulled.

## Phase 1: Operational Readiness

### RM-004 Payments/Payouts Ops Console
- Status: `planned`
- Owner: Backend + Mobile/Web Admin
- Goal: Operators can resolve stuck payouts and failed invoices quickly.
- Exit criteria:
  - Query surfaces for `needs_attention` payouts and failed invoices.
  - Action endpoints for retry/resolve notes.
  - UI with filters + details.

### RM-005 Alerting and Observability
- Status: `planned`
- Owner: Backend/Ops
- Goal: detect payment/payout issues before users report them.
- Exit criteria:
  - Structured error events for webhook failure, payout terminal failure.
  - Alert thresholds configured.
  - On-call runbook checked in.

## Phase 2: Product Completeness

### RM-006 Invoice Integrations v1 (Morning/iCount)
- Status: `planned`
- Owner: Backend
- Goal: robust invoice issuance with retries and stable links/refs.
- Exit criteria:
  - Provider adapters validated in sandbox.
  - Deterministic retries and terminal states.
  - Mobile detail screen shows consistent invoice reference/link.

### RM-007 Instructor Earnings UX
- Status: `planned`
- Owner: Mobile
- Goal: transparent payout timeline for instructors.
- Exit criteria:
  - Payment -> payout timeline states explained in UI.
  - Better empty/error/retry UX across payment screens.
  - Deep links to related job and invoice details.

## Phase 3: Ship Gate

### RM-008 Production Go-Live Checklist
- Status: `planned`
- Owner: Product + Engineering
- Goal: hard go/no-go decision with evidence.
- Exit criteria:
  - Full staging E2E run (checkout -> capture -> payout -> invoice -> UI).
  - Production webhook callbacks verified.
  - Rollback strategy documented.
  - Post-launch monitoring confirmed.

## Current Priority Order
1. RM-001
2. RM-002
3. RM-003
4. RM-004
5. RM-008
