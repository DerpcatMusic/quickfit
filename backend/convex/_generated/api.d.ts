/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as actions_geminiVerify from "../actions/geminiVerify.js";
import type * as actions_sendPush from "../actions/sendPush.js";
import type * as backfill from "../backfill.js";
import type * as billing from "../billing.js";
import type * as bitpay from "../bitpay.js";
import type * as claims from "../claims.js";
import type * as crons from "../crons.js";
import type * as domains_claims_internalQueries_getClaimById from "../domains/claims/internalQueries/getClaimById.js";
import type * as domains_claims_internalQueries_getClaimsForInstructorInternal from "../domains/claims/internalQueries/getClaimsForInstructorInternal.js";
import type * as domains_claims_mutations_withdrawClaim from "../domains/claims/mutations/withdrawClaim.js";
import type * as domains_claims_queries_getJobClaims from "../domains/claims/queries/getJobClaims.js";
import type * as domains_claims_queries_getMyClaims from "../domains/claims/queries/getMyClaims.js";
import type * as domains_geo_indexes_instructorGeo from "../domains/geo/indexes/instructorGeo.js";
import type * as domains_geo_indexes_jobGeo from "../domains/geo/indexes/jobGeo.js";
import type * as domains_geo_internalQueries_findInstructorsForJobQuery from "../domains/geo/internalQueries/findInstructorsForJobQuery.js";
import type * as domains_geo_queries_getNearbyJobsForInstructor from "../domains/geo/queries/getNearbyJobsForInstructor.js";
import type * as domains_geo_services_findInstructorsForJob from "../domains/geo/services/findInstructorsForJob.js";
import type * as domains_geo_services_findJobsForInstructor from "../domains/geo/services/findJobsForInstructor.js";
import type * as domains_geo_services_removeInstructorLocation from "../domains/geo/services/removeInstructorLocation.js";
import type * as domains_geo_services_removeJobLocation from "../domains/geo/services/removeJobLocation.js";
import type * as domains_geo_services_syncInstructorLocation from "../domains/geo/services/syncInstructorLocation.js";
import type * as domains_geo_services_syncJobLocation from "../domains/geo/services/syncJobLocation.js";
import type * as domains_geo_utils_haversineDistanceKm from "../domains/geo/utils/haversineDistanceKm.js";
import type * as domains_geo_utils_haversineDistanceMeters from "../domains/geo/utils/haversineDistanceMeters.js";
import type * as domains_geo_utils_isWithinRadius from "../domains/geo/utils/isWithinRadius.js";
import type * as domains_jobReadModels_operations_syncJobReadModels from "../domains/jobReadModels/operations/syncJobReadModels.js";
import type * as domains_jobs_constants_CATEGORIES from "../domains/jobs/constants/CATEGORIES.js";
import type * as domains_jobs_internalMutations_cancelJobInternalByStudio from "../domains/jobs/internalMutations/cancelJobInternalByStudio.js";
import type * as domains_jobs_internalMutations_claimJobInternalByInstructor from "../domains/jobs/internalMutations/claimJobInternalByInstructor.js";
import type * as domains_jobs_internalMutations_completeJobInternalByStudio from "../domains/jobs/internalMutations/completeJobInternalByStudio.js";
import type * as domains_jobs_internalMutations_expireStaleClaims from "../domains/jobs/internalMutations/expireStaleClaims.js";
import type * as domains_jobs_internalMutations_markNotified from "../domains/jobs/internalMutations/markNotified.js";
import type * as domains_jobs_internalMutations_rebuildJobReadModels from "../domains/jobs/internalMutations/rebuildJobReadModels.js";
import type * as domains_jobs_internalMutations_respondToClaimInternal from "../domains/jobs/internalMutations/respondToClaimInternal.js";
import type * as domains_jobs_internalMutations_scheduleDispatchRetry from "../domains/jobs/internalMutations/scheduleDispatchRetry.js";
import type * as domains_jobs_internalMutations_withdrawClaimInternalByJobAndInstructor from "../domains/jobs/internalMutations/withdrawClaimInternalByJobAndInstructor.js";
import type * as domains_jobs_internalMutations_withdrawClaimInternalByJobAndInstructorIdempotent from "../domains/jobs/internalMutations/withdrawClaimInternalByJobAndInstructorIdempotent.js";
import type * as domains_jobs_internalQueries_getJobInternal from "../domains/jobs/internalQueries/getJobInternal.js";
import type * as domains_jobs_internalQueries_getMyJobsInternal from "../domains/jobs/internalQueries/getMyJobsInternal.js";
import type * as domains_jobs_internalQueries_getStudioJobsForStudioInternal from "../domains/jobs/internalQueries/getStudioJobsForStudioInternal.js";
import type * as domains_jobs_mutations_cancelJob from "../domains/jobs/mutations/cancelJob.js";
import type * as domains_jobs_mutations_claimJob from "../domains/jobs/mutations/claimJob.js";
import type * as domains_jobs_mutations_completeJob from "../domains/jobs/mutations/completeJob.js";
import type * as domains_jobs_mutations_postJob from "../domains/jobs/mutations/postJob.js";
import type * as domains_jobs_mutations_respondToClaim from "../domains/jobs/mutations/respondToClaim.js";
import type * as domains_jobs_mutations_submitRating from "../domains/jobs/mutations/submitRating.js";
import type * as domains_jobs_mutations_withdrawClaim from "../domains/jobs/mutations/withdrawClaim.js";
import type * as domains_jobs_queries_getInstructorStats from "../domains/jobs/queries/getInstructorStats.js";
import type * as domains_jobs_queries_getJobById from "../domains/jobs/queries/getJobById.js";
import type * as domains_jobs_queries_getJobsForMap from "../domains/jobs/queries/getJobsForMap.js";
import type * as domains_jobs_queries_getMyJobs from "../domains/jobs/queries/getMyJobs.js";
import type * as domains_jobs_queries_getNearbyJobs from "../domains/jobs/queries/getNearbyJobs.js";
import type * as domains_jobs_queries_getStudioJobs from "../domains/jobs/queries/getStudioJobs.js";
import type * as domains_jobs_queries_getZoneJobsForInstructor from "../domains/jobs/queries/getZoneJobsForInstructor.js";
import type * as domains_notifications_internalActions_dispatchJobNotifications from "../domains/notifications/internalActions/dispatchJobNotifications.js";
import type * as domains_notifications_internalActions_notifyBackupPromoted from "../domains/notifications/internalActions/notifyBackupPromoted.js";
import type * as domains_notifications_internalActions_notifyClaimAccepted from "../domains/notifications/internalActions/notifyClaimAccepted.js";
import type * as domains_notifications_internalActions_notifyClaimRejected from "../domains/notifications/internalActions/notifyClaimRejected.js";
import type * as domains_notifications_internalActions_notifyJobCancelled from "../domains/notifications/internalActions/notifyJobCancelled.js";
import type * as domains_notifications_internalActions_notifyStudioOfBackupClaim from "../domains/notifications/internalActions/notifyStudioOfBackupClaim.js";
import type * as domains_notifications_internalActions_notifyStudioOfClaim from "../domains/notifications/internalActions/notifyStudioOfClaim.js";
import type * as domains_notifications_internalMutations_logNotification from "../domains/notifications/internalMutations/logNotification.js";
import type * as events from "../events.js";
import type * as geo from "../geo.js";
import type * as http from "../http.js";
import type * as invoicing from "../invoicing.js";
import type * as jobReadModels from "../jobReadModels.js";
import type * as jobs from "../jobs.js";
import type * as lib_auth from "../lib/auth.js";
import type * as lib_errors from "../lib/errors.js";
import type * as lib_secrets from "../lib/secrets.js";
import type * as lib_urlSecurity from "../lib/urlSecurity.js";
import type * as notifications from "../notifications.js";
import type * as payments from "../payments.js";
import type * as paymentsDiagnostics from "../paymentsDiagnostics.js";
import type * as payouts from "../payouts.js";
import type * as pricing from "../pricing.js";
import type * as rapyd from "../rapyd.js";
import type * as seed from "../seed.js";
import type * as seedZones from "../seedZones.js";
import type * as storage from "../storage.js";
import type * as testHarness from "../testHarness.js";
import type * as testing_dispatchTests from "../testing/dispatchTests.js";
import type * as users from "../users.js";
import type * as verifications from "../verifications.js";
import type * as webhooks from "../webhooks.js";
import type * as zoneSubscriptions from "../zoneSubscriptions.js";
import type * as zones from "../zones.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  "actions/geminiVerify": typeof actions_geminiVerify;
  "actions/sendPush": typeof actions_sendPush;
  backfill: typeof backfill;
  billing: typeof billing;
  bitpay: typeof bitpay;
  claims: typeof claims;
  crons: typeof crons;
  "domains/claims/internalQueries/getClaimById": typeof domains_claims_internalQueries_getClaimById;
  "domains/claims/internalQueries/getClaimsForInstructorInternal": typeof domains_claims_internalQueries_getClaimsForInstructorInternal;
  "domains/claims/mutations/withdrawClaim": typeof domains_claims_mutations_withdrawClaim;
  "domains/claims/queries/getJobClaims": typeof domains_claims_queries_getJobClaims;
  "domains/claims/queries/getMyClaims": typeof domains_claims_queries_getMyClaims;
  "domains/geo/indexes/instructorGeo": typeof domains_geo_indexes_instructorGeo;
  "domains/geo/indexes/jobGeo": typeof domains_geo_indexes_jobGeo;
  "domains/geo/internalQueries/findInstructorsForJobQuery": typeof domains_geo_internalQueries_findInstructorsForJobQuery;
  "domains/geo/queries/getNearbyJobsForInstructor": typeof domains_geo_queries_getNearbyJobsForInstructor;
  "domains/geo/services/findInstructorsForJob": typeof domains_geo_services_findInstructorsForJob;
  "domains/geo/services/findJobsForInstructor": typeof domains_geo_services_findJobsForInstructor;
  "domains/geo/services/removeInstructorLocation": typeof domains_geo_services_removeInstructorLocation;
  "domains/geo/services/removeJobLocation": typeof domains_geo_services_removeJobLocation;
  "domains/geo/services/syncInstructorLocation": typeof domains_geo_services_syncInstructorLocation;
  "domains/geo/services/syncJobLocation": typeof domains_geo_services_syncJobLocation;
  "domains/geo/utils/haversineDistanceKm": typeof domains_geo_utils_haversineDistanceKm;
  "domains/geo/utils/haversineDistanceMeters": typeof domains_geo_utils_haversineDistanceMeters;
  "domains/geo/utils/isWithinRadius": typeof domains_geo_utils_isWithinRadius;
  "domains/jobReadModels/operations/syncJobReadModels": typeof domains_jobReadModels_operations_syncJobReadModels;
  "domains/jobs/constants/CATEGORIES": typeof domains_jobs_constants_CATEGORIES;
  "domains/jobs/internalMutations/cancelJobInternalByStudio": typeof domains_jobs_internalMutations_cancelJobInternalByStudio;
  "domains/jobs/internalMutations/claimJobInternalByInstructor": typeof domains_jobs_internalMutations_claimJobInternalByInstructor;
  "domains/jobs/internalMutations/completeJobInternalByStudio": typeof domains_jobs_internalMutations_completeJobInternalByStudio;
  "domains/jobs/internalMutations/expireStaleClaims": typeof domains_jobs_internalMutations_expireStaleClaims;
  "domains/jobs/internalMutations/markNotified": typeof domains_jobs_internalMutations_markNotified;
  "domains/jobs/internalMutations/rebuildJobReadModels": typeof domains_jobs_internalMutations_rebuildJobReadModels;
  "domains/jobs/internalMutations/respondToClaimInternal": typeof domains_jobs_internalMutations_respondToClaimInternal;
  "domains/jobs/internalMutations/scheduleDispatchRetry": typeof domains_jobs_internalMutations_scheduleDispatchRetry;
  "domains/jobs/internalMutations/withdrawClaimInternalByJobAndInstructor": typeof domains_jobs_internalMutations_withdrawClaimInternalByJobAndInstructor;
  "domains/jobs/internalMutations/withdrawClaimInternalByJobAndInstructorIdempotent": typeof domains_jobs_internalMutations_withdrawClaimInternalByJobAndInstructorIdempotent;
  "domains/jobs/internalQueries/getJobInternal": typeof domains_jobs_internalQueries_getJobInternal;
  "domains/jobs/internalQueries/getMyJobsInternal": typeof domains_jobs_internalQueries_getMyJobsInternal;
  "domains/jobs/internalQueries/getStudioJobsForStudioInternal": typeof domains_jobs_internalQueries_getStudioJobsForStudioInternal;
  "domains/jobs/mutations/cancelJob": typeof domains_jobs_mutations_cancelJob;
  "domains/jobs/mutations/claimJob": typeof domains_jobs_mutations_claimJob;
  "domains/jobs/mutations/completeJob": typeof domains_jobs_mutations_completeJob;
  "domains/jobs/mutations/postJob": typeof domains_jobs_mutations_postJob;
  "domains/jobs/mutations/respondToClaim": typeof domains_jobs_mutations_respondToClaim;
  "domains/jobs/mutations/submitRating": typeof domains_jobs_mutations_submitRating;
  "domains/jobs/mutations/withdrawClaim": typeof domains_jobs_mutations_withdrawClaim;
  "domains/jobs/queries/getInstructorStats": typeof domains_jobs_queries_getInstructorStats;
  "domains/jobs/queries/getJobById": typeof domains_jobs_queries_getJobById;
  "domains/jobs/queries/getJobsForMap": typeof domains_jobs_queries_getJobsForMap;
  "domains/jobs/queries/getMyJobs": typeof domains_jobs_queries_getMyJobs;
  "domains/jobs/queries/getNearbyJobs": typeof domains_jobs_queries_getNearbyJobs;
  "domains/jobs/queries/getStudioJobs": typeof domains_jobs_queries_getStudioJobs;
  "domains/jobs/queries/getZoneJobsForInstructor": typeof domains_jobs_queries_getZoneJobsForInstructor;
  "domains/notifications/internalActions/dispatchJobNotifications": typeof domains_notifications_internalActions_dispatchJobNotifications;
  "domains/notifications/internalActions/notifyBackupPromoted": typeof domains_notifications_internalActions_notifyBackupPromoted;
  "domains/notifications/internalActions/notifyClaimAccepted": typeof domains_notifications_internalActions_notifyClaimAccepted;
  "domains/notifications/internalActions/notifyClaimRejected": typeof domains_notifications_internalActions_notifyClaimRejected;
  "domains/notifications/internalActions/notifyJobCancelled": typeof domains_notifications_internalActions_notifyJobCancelled;
  "domains/notifications/internalActions/notifyStudioOfBackupClaim": typeof domains_notifications_internalActions_notifyStudioOfBackupClaim;
  "domains/notifications/internalActions/notifyStudioOfClaim": typeof domains_notifications_internalActions_notifyStudioOfClaim;
  "domains/notifications/internalMutations/logNotification": typeof domains_notifications_internalMutations_logNotification;
  events: typeof events;
  geo: typeof geo;
  http: typeof http;
  invoicing: typeof invoicing;
  jobReadModels: typeof jobReadModels;
  jobs: typeof jobs;
  "lib/auth": typeof lib_auth;
  "lib/errors": typeof lib_errors;
  "lib/secrets": typeof lib_secrets;
  "lib/urlSecurity": typeof lib_urlSecurity;
  notifications: typeof notifications;
  payments: typeof payments;
  paymentsDiagnostics: typeof paymentsDiagnostics;
  payouts: typeof payouts;
  pricing: typeof pricing;
  rapyd: typeof rapyd;
  seed: typeof seed;
  seedZones: typeof seedZones;
  storage: typeof storage;
  testHarness: typeof testHarness;
  "testing/dispatchTests": typeof testing_dispatchTests;
  users: typeof users;
  verifications: typeof verifications;
  webhooks: typeof webhooks;
  zoneSubscriptions: typeof zoneSubscriptions;
  zones: typeof zones;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {
  geospatial: {
    document: {
      get: FunctionReference<
        "query",
        "internal",
        { key: string },
        {
          coordinates: { latitude: number; longitude: number };
          filterKeys: Record<
            string,
            | string
            | number
            | boolean
            | null
            | bigint
            | Array<string | number | boolean | null | bigint>
          >;
          key: string;
          sortKey: number;
        } | null
      >;
      insert: FunctionReference<
        "mutation",
        "internal",
        {
          document: {
            coordinates: { latitude: number; longitude: number };
            filterKeys: Record<
              string,
              | string
              | number
              | boolean
              | null
              | bigint
              | Array<string | number | boolean | null | bigint>
            >;
            key: string;
            sortKey: number;
          };
          levelMod: number;
          maxCells: number;
          maxLevel: number;
          minLevel: number;
        },
        null
      >;
      remove: FunctionReference<
        "mutation",
        "internal",
        {
          key: string;
          levelMod: number;
          maxCells: number;
          maxLevel: number;
          minLevel: number;
        },
        boolean
      >;
    };
    query: {
      debugCells: FunctionReference<
        "query",
        "internal",
        {
          levelMod: number;
          maxCells: number;
          maxLevel: number;
          minLevel: number;
          rectangle: {
            east: number;
            north: number;
            south: number;
            west: number;
          };
        },
        Array<{
          token: string;
          vertices: Array<{ latitude: number; longitude: number }>;
        }>
      >;
      execute: FunctionReference<
        "query",
        "internal",
        {
          cursor?: string;
          levelMod: number;
          logLevel: "DEBUG" | "INFO" | "WARN" | "ERROR";
          maxCells: number;
          maxLevel: number;
          minLevel: number;
          query: {
            filtering: Array<{
              filterKey: string;
              filterValue: string | number | boolean | null | bigint;
              occur: "should" | "must";
            }>;
            maxResults: number;
            rectangle: {
              east: number;
              north: number;
              south: number;
              west: number;
            };
            sorting: {
              interval: { endExclusive?: number; startInclusive?: number };
            };
          };
        },
        {
          nextCursor?: string;
          results: Array<{
            coordinates: { latitude: number; longitude: number };
            key: string;
          }>;
        }
      >;
      nearestPoints: FunctionReference<
        "query",
        "internal",
        {
          filtering: Array<{
            filterKey: string;
            filterValue: string | number | boolean | null | bigint;
            occur: "should" | "must";
          }>;
          levelMod: number;
          logLevel: "DEBUG" | "INFO" | "WARN" | "ERROR";
          maxDistance?: number;
          maxLevel: number;
          maxResults: number;
          minLevel: number;
          nextCursor?: string;
          point: { latitude: number; longitude: number };
          sorting: {
            interval: { endExclusive?: number; startInclusive?: number };
          };
        },
        Array<{
          coordinates: { latitude: number; longitude: number };
          distance: number;
          key: string;
        }>
      >;
    };
  };
};
