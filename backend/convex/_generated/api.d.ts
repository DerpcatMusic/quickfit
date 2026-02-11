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
import type * as geo from "../geo.js";
import type * as http from "../http.js";
import type * as invoicing from "../invoicing.js";
import type * as jobs from "../jobs.js";
import type * as lib_secrets from "../lib/secrets.js";
import type * as lib_urlSecurity from "../lib/urlSecurity.js";
import type * as notifications from "../notifications.js";
import type * as payments from "../payments.js";
import type * as paymentsDiagnostics from "../paymentsDiagnostics.js";
import type * as payouts from "../payouts.js";
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
  geo: typeof geo;
  http: typeof http;
  invoicing: typeof invoicing;
  jobs: typeof jobs;
  "lib/secrets": typeof lib_secrets;
  "lib/urlSecurity": typeof lib_urlSecurity;
  notifications: typeof notifications;
  payments: typeof payments;
  paymentsDiagnostics: typeof paymentsDiagnostics;
  payouts: typeof payouts;
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
