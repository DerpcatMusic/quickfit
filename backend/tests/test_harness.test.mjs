import test from "node:test";
import assert from "node:assert/strict";
import { ConvexHttpClient } from "convex/browser";
import fs from "node:fs";
import path from "node:path";

const loadEnvLocal = () => {
  try {
    const envPath = path.resolve(process.cwd(), ".env.local");
    const raw = fs.readFileSync(envPath, "utf8");
    for (const line of raw.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("="))
        continue;
      const [key, ...rest] = trimmed.split("=");
      const value = rest.join("=").trim();
      if (key && !(key in process.env)) {
        process.env[key] = value.split(" #")[0].trim();
      }
    }
  } catch {
    // ignore if no .env.local
  }
};

loadEnvLocal();

const convexUrl = process.env.CONVEX_URL;
const token = process.env.TEST_HARNESS_TOKEN;

test("test harness happy path", async () => {
  if (!convexUrl || !token) return;

  const client = new ConvexHttpClient(convexUrl);
  const result = await client.action("testHarness:runTestSuite", {
    token,
    cleanup: true,
  });

  assert.equal(result.jobStatus, "confirmed");
  assert.equal(result.completedJobStatus, "completed");
  assert.ok(result.matchCount >= 1);
  assert.equal(result.mismatchCount, 0);
  assert.equal(result.notificationsSent, true);
  assert.equal(result.staleJobStatus, "open");
  assert.equal(result.backupPromoted, true);
  assert.equal(result.backupJobStatus, "claimed");
  assert.equal(result.backupClaimStatus, "accepted");
  assert.equal(result.rejectDoubleRespondBlocked, true);
  assert.equal(result.redispatchStatus, "open");
  assert.equal(result.redispatchNotificationsSent, true);
  assert.equal(result.cancelledJobStatus, "cancelled");
  assert.equal(result.cancelledAcceptedClaimReconciled, true);
  assert.equal(result.idempotentClaimDedupeWorked, true);
  assert.equal(result.idempotentWithdrawReplaySafe, true);
  assert.equal(result.claimsWindowFilterAndOrderCorrect, true);
  assert.equal(result.studioJobsPriorityOrderingCorrect, true);
  assert.equal(result.studioInstructorVisibilityRealtimeCorrect, true);
  assert.equal(result.postingVisibilityForUnverifiedCorrect, true);
  assert.equal(result.readModelProjectionConsistencyCorrect, true);
  assert.equal(result.centralizedMyJobsQueryConsistent, true);
});

test("test harness rejects invalid token", async () => {
  if (!convexUrl) return;

  const client = new ConvexHttpClient(convexUrl);
  await assert.rejects(
    client.action("testHarness:runTestSuite", {
      token: "invalid_token",
      cleanup: true,
    }),
    /Unauthorized/i,
  );
});

