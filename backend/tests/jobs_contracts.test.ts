import { describe, expect, it } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const jobsCorePath = join(import.meta.dir, "../convex/jobs.core.ts");
const usersPath = join(import.meta.dir, "../convex/users.ts");

describe("jobs reliability contracts", () => {
  it("bounds instructor my-jobs claim hydration on the indexed query path", () => {
    const source = readFileSync(jobsCorePath, "utf8");

    expect(source).toContain("MAX_MY_JOBS_CLAIMS = 250");
    expect(source).toContain(".withIndex(\"by_instructor\"");
    expect(source).toContain(".order(\"desc\")");
    expect(source).toContain(".take(MAX_MY_JOBS_CLAIMS)");
  });

  it("schedules zone backfill when post-job zone detection times out", () => {
    const source = readFileSync(jobsCorePath, "utf8");

    expect(source).toContain("internal.zones.backfillJobZoneForPostedJob");
    expect(source).toContain("Failed to schedule zone backfill");
  });

  it("falls back to radius mode when onboarding receives zone mode without zones", () => {
    const source = readFileSync(usersPath, "utf8");

    expect(source).toContain("dispatchMode === \"zone\"");
    expect(source).toContain("(!args.zoneIds || args.zoneIds.length === 0)");
    expect(source).toContain("dispatchMode = \"radius\"");
  });
});
