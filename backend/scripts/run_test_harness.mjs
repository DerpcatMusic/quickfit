import { ConvexHttpClient } from "convex/browser";

const convexUrl = process.env.CONVEX_URL;
const token = process.env.TEST_HARNESS_TOKEN;

if (!convexUrl) {
  console.error("CONVEX_URL is required");
  process.exit(1);
}

if (!token) {
  console.error("TEST_HARNESS_TOKEN is required");
  process.exit(1);
}

const client = new ConvexHttpClient(convexUrl);

const cleanup = process.env.TEST_HARNESS_CLEANUP === "true";

const result = await client.action("testHarness:runTestSuite", {
  token,
  cleanup,
});

console.log(JSON.stringify(result, null, 2));
