import { describe, expect, it } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const jobsCorePath = join(import.meta.dir, "../convex/jobs.core.ts");
const usersPath = join(import.meta.dir, "../convex/users.ts");
const zonesPath = join(import.meta.dir, "../convex/zones.ts");
const notificationsCorePath = join(import.meta.dir, "../convex/notifications.core.ts");

describe("jobs reliability contracts", () => {
  it("bounds instructor my-jobs claim hydration on the indexed query path", () => {
    const source = readFileSync(jobsCorePath, "utf8");

    expect(source).toContain("MAX_MY_JOBS_CLAIMS = 250");
    expect(source).toContain(".withIndex(\"by_instructor\"");
    expect(source).toContain(".order(\"desc\")");
    expect(source).toContain(".take(MAX_MY_JOBS_CLAIMS)");
    expect(source).toContain("const uniqueJobIds = Array.from(new Set(");
    expect(source).toContain("const uniqueStudioIds = Array.from(");
  });

  it("accepts numeric-string baseRate at the mutation boundary with explicit invalid guard", () => {
    const source = readFileSync(jobsCorePath, "utf8");

    expect(source).toContain("baseRate: v.optional(v.union(v.float64(), v.string()))");
    expect(source).toContain("typeof args.baseRate === \"string\"");
    expect(source).toContain("throw new Error(\"BASE_RATE_INVALID\")");
  });

  it("schedules zone backfill when post-job zone detection times out", () => {
    const source = readFileSync(jobsCorePath, "utf8");

    expect(source).toContain("internal.zones.backfillJobZoneForPostedJob");
    expect(source).toContain("Failed to schedule zone backfill");
  });

  it("backfill triggers dispatch recovery for open jobs already marked notified", () => {
    const source = readFileSync(zonesPath, "utf8");

    expect(source).toContain("if (job.status === \"open\" && job.notificationsSent)");
    expect(source).toContain("notificationsSent: false");
    expect(source).toContain("internal.notifications.dispatchJobNotifications");
  });

  it("falls back to radius mode when onboarding receives zone mode without zones", () => {
    const source = readFileSync(usersPath, "utf8");

    expect(source).toContain("dispatchMode === \"zone\"");
    expect(source).toContain("(!args.zoneIds || args.zoneIds.length === 0)");
    expect(source).toContain("dispatchMode = \"radius\"");
  });

  it("notification dispatch dedupes against already notified instructors", () => {
    const source = readFileSync(notificationsCorePath, "utf8");

    expect(source).toContain("const alreadyNotified = new Set<Id<\"users\">>(job.notifiedInstructors ?? [])");
    expect(source).toContain("!alreadyNotified.has(id)");
    expect(source).toContain("No newly eligible instructors matched");
  });
});
