import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

// Expire stale claims quickly to keep last-minute jobs moving.
crons.interval("expire stale claims", { minutes: 1 }, internal.jobs.expireStaleClaims);

export default crons;
