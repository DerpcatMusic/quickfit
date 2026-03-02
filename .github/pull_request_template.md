## Summary

- Feature/fix:
- User impact:
- Technical approach:

## Roadmap Linkage (Required)

- Roadmap Item(s): `RM-___`
- Status impact: (`planned` -> `in_progress` -> `done`):
- Why this PR is the right slice for that item:

## Invariants Impacted

- [ ] Identity/auth (`ctx.auth.getUserIdentity()`)
- [ ] Idempotency/replay safety
- [ ] Index hot-path guarantees
- [ ] Secret handling / credential safety
- [ ] Jobs/claims lifecycle consistency
- [ ] Payments/payouts lifecycle consistency
- Notes:

## Change Type

- [ ] `feat`
- [ ] `fix`
- [ ] `refactor`
- [ ] `test`
- [ ] `docs`
- [ ] `chore`

## Linked Context

- Issue:
- Related PRs:
- Docs/architecture references:
- Roadmap doc reference: `docs/PRODUCT_ROADMAP.md`
- Features status doc reference: `docs/FEATURES_STATUS.md`

## Validation

Commands run:

- [ ] `flutter analyze` (if mobile changed)
- [ ] `flutter test` (if mobile changed)
- [ ] `flutter test integration_test` (if mobile flows changed)
- [ ] `dart run build_runner build --delete-conflicting-outputs` (if generated code changed)
- [ ] `bun run test` (if backend changed)
- [ ] `bun run typecheck` (if backend TS/API changed)
- [ ] `bun install --frozen-lockfile` (for backend dependency/lockfile changes)
- [ ] `bun pm scan` (for backend dependency changes)
- [ ] Other targeted checks:

Results:

## Risk Assessment

- Primary risks:
- Regression surface:
- Observability/logging notes:

## Rollback Plan

- Revert strategy:
- Data migration impact (if any):

## Checklist

- [ ] Branch follows naming convention (`feat/*`, `fix/*`, `chore/*`)
- [ ] Commits are small and meaningful (conventional prefixes)
- [ ] Tests/checks relevant to touched areas were executed
- [ ] Cross-cutting changes updated both backend and mobile where required
- [ ] `AGENTS.md` updated if workflow/standards changed
- [ ] Features status reviewed and updated if behavior changed (`docs/FEATURES_STATUS.md`)
- [ ] Roadmap item status updated if milestone changed (`docs/PRODUCT_ROADMAP.md`)
