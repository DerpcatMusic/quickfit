# Bun Guide (QuickFit)

This repo should use Bun as the default JS/TS toolchain for backend work.

## Version

- Bun: `1.3.6`
- Backend package manager/runtime source of truth: `backend/package.json` (`packageManager`)

## Daily Development (Backend)

Run inside `backend/`:

- Install deps: `bun install`
- Start Convex dev: `bun run dev`
- Typecheck: `bun run typecheck`
- Run tests: `bun run test`
- Watch tests: `bun run test:watch`
- Run harness script: `bun run harness:run`
- Run dispatch stress tests: `bun run dispatch:test`

## CI/Pre-PR Baseline

Use these Bun-native checks:

- Lockfile integrity: `bun run deps:lock:check`
- Typecheck + tests: `bun run ci:verify`
- Security scan: `bun run deps:scan`
- Vulnerability check: `bun run deps:audit`

Recommended minimum pipeline sequence:

1. `bun install --frozen-lockfile`
2. `bun run typecheck`
3. `bun run test`
4. `bun run deps:scan`

## Dependency Utilities to Use Regularly

- Show outdated dependencies: `bun run deps:outdated`
- Scan vulnerabilities from lockfile: `bun run deps:scan`
- Audit installed dependency vulnerabilities: `bun run deps:audit`
- Inspect untrusted install scripts: `bun run deps:untrusted`
- Trust vetted install scripts: `bun run deps:trust:all`
- Print lock hash (cache keying/reproducibility): `bun run deps:lock:hash`

## Test Utilities

- Coverage output (text + lcov): `bun run test:coverage`

## Deployment Utilities

Use Bun wrappers around Convex CLI:

- Deploy: `bun run deploy`
- Verified deploy: `bun run deploy:checked`
- Logs: `bun run logs`

For deployment automation:

1. Run `bun install --frozen-lockfile`
2. Run `bun run ci:verify`
3. Run `bun run deps:scan`
4. Run `bun run deploy`

## Scanner Configuration (Enabled)

`bun pm scan` is enabled through `backend/bunfig.toml`:

```toml
[install.security]
scanner = "bun-osv-scanner"
```

Scanner package is installed as a backend devDependency.

## Packaging Utility

- Dry-run package tarball generation: `bun run package:dry-run`
- Print Bun cache directory: `bun run cache:dir`
- Clear Bun cache: `bun run cache:clear`

This is useful for release sanity checks and validating what files are included.
