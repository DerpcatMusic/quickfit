// convex/testing/dispatchTests.ts
// Comprehensive testing suite for dual-mode dispatch system
// Run with: npx convex run testing/dispatchTests:runAllTests

import { internalMutation, internalAction, internalQuery } from "../_generated/server";
import { v } from "convex/values";
import { internal } from "../_generated/api";
import { Id } from "../_generated/dataModel";

// ==========================================
// TEST UTILITIES
// ==========================================

interface TestResult {
  name: string;
  passed: boolean;
  duration: number;
  error?: string;
}

// ==========================================
// SEED DATA HELPERS
// ==========================================

/**
 * Create a test instructor with all required fields
 */
export const createTestInstructor = internalMutation({
  args: {
    name: v.string(),
    dispatchMode: v.union(v.literal("radius"), v.literal("zone")),
    latitude: v.optional(v.float64()),
    longitude: v.optional(v.float64()),
    radiusKm: v.optional(v.float64()),
    zoneIds: v.optional(v.array(v.id("zones"))),
    categories: v.array(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const userId = await ctx.db.insert("users", {
      firebaseUid: `test_instructor_${now}_${Math.random().toString(36).slice(2)}`,
      name: args.name,
      email: `${args.name.toLowerCase().replace(/\s/g, ".")}@test.com`,
      role: "instructor",
      dispatchMode: args.dispatchMode,
      latitude: args.latitude,
      longitude: args.longitude,
      radiusKm: args.radiusKm,
      zoneIds: args.zoneIds,
      categories: args.categories,
      primaryCategory: args.categories[0] ?? "general",
      hasCompletedOnboarding: true,
      isVerified: true,
      notificationsEnabled: true,
      fcmToken: `test_token_${now}`,
      createdAt: now,
      updatedAt: now,
    });
    return userId;
  },
});

/**
 * Create a test studio
 */
export const createTestStudio = internalMutation({
  args: {
    name: v.string(),
    latitude: v.float64(),
    longitude: v.float64(),
    zoneId: v.optional(v.id("zones")),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const userId = await ctx.db.insert("users", {
      firebaseUid: `test_studio_${now}_${Math.random().toString(36).slice(2)}`,
      name: args.name,
      email: `${args.name.toLowerCase().replace(/\s/g, ".")}@studio.test.com`,
      role: "studio",
      latitude: args.latitude,
      longitude: args.longitude,
      zoneId: args.zoneId,
      hasCompletedOnboarding: true,
      isVerified: true,
      createdAt: now,
      updatedAt: now,
    });
    return userId;
  },
});

/**
 * Create a test job
 */
export const createTestJob = internalMutation({
  args: {
    studioId: v.id("users"),
    title: v.string(),
    category: v.string(),
    latitude: v.float64(),
    longitude: v.float64(),
    zoneId: v.optional(v.id("zones")),
    currentRate: v.float64(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const jobId = await ctx.db.insert("jobs", {
      studioId: args.studioId,
      title: args.title,
      category: args.category,
      latitude: args.latitude,
      longitude: args.longitude,
      address: "Test Address, Tel Aviv",
      zoneId: args.zoneId,
      startTime: now + 3600000,
      endTime: now + 7200000,
      durationMinutes: 60,
      sosBoostApplied: false,
      baseRate: args.currentRate,
      currentRate: args.currentRate,
      status: "open",
      requiresVerification: false,
      dispatchVersion: 1,
      notificationsSent: false,
      createdAt: now,
      updatedAt: now,
    });
    return jobId;
  },
});

/**
 * Create a test zone
 */
export const createTestZone = internalMutation({
  args: { name: v.string() },
  handler: async (ctx, { name }) => {
    const zoneId = await ctx.db.insert("zones", {
      orefId: `test_${name.toLowerCase().replace(/\\s/g, '_')}_${Date.now()}`,
      name,
      nameHebrew: name,
      city: 'Test City',
      polygon: [{ lat: 32.0, lng: 34.7 }, { lat: 32.1, lng: 34.7 }, { lat: 32.1, lng: 34.8 }, { lat: 32.0, lng: 34.8 }],
      centroid: { lat: 32.05, lng: 34.75 },
    });
    return zoneId;
  },
});

/**
 * Clean up test data
 */
export const cleanupTestData = internalMutation({
  args: {},
  handler: async (ctx) => {
    // Delete test users
    const testUsers = await ctx.db.query("users").collect();
    for (const user of testUsers) {
      if (user.firebaseUid.startsWith("test_")) {
        await ctx.db.delete(user._id);
      }
    }
    
    // Delete test jobs
    const testJobs = await ctx.db.query("jobs").collect();
    for (const job of testJobs) {
      if (job.title.startsWith("Test Job")) {
        await ctx.db.delete(job._id);
      }
    }
    
    // Delete zone subscriptions for test instructors
    const subs = await ctx.db.query("zoneSubscriptions").collect();
    for (const sub of subs) {
      const user = await ctx.db.get(sub.instructorId);
      if (!user || user.firebaseUid.startsWith("test_")) {
        await ctx.db.delete(sub._id);
      }
    }
    
    return { cleaned: true };
  },
});

// ==========================================
// UNIT TESTS
// ==========================================

/**
 * Test: Radius mode instructor is added to geospatial index
 */
export const testRadiusModeGeoSync = internalAction({
  args: {},
  handler: async (ctx): Promise<TestResult> => {
    const start = Date.now();
    const testName = "Radius mode instructor geo sync";
    
    try {
      // Create instructor in radius mode
      const instructorId = await ctx.runMutation(internal.testing.dispatchTests.createTestInstructor, {
        name: "Test Radius Instructor",
        dispatchMode: "radius",
        latitude: 32.0853, // Tel Aviv
        longitude: 34.7818,
        radiusKm: 5,
        categories: ["yoga"],
      });
      
      // Query geo index for nearby jobs
      const matches = await ctx.runQuery(internal.geo.findInstructorsForJobQuery, {
        jobPoint: { latitude: 32.0853, longitude: 34.7818 },
        jobCategory: "yoga",
        requiresVerification: false,
      });
      
      const found = matches.some(m => m.instructorId === instructorId);
      
      // Cleanup
      await ctx.runMutation(internal.testing.dispatchTests.cleanupTestData, {});
      
      return {
        name: testName,
        passed: found,
        duration: Date.now() - start,
        error: found ? undefined : "Instructor not found in geospatial index",
      };
    } catch (e) {
      return {
        name: testName,
        passed: false,
        duration: Date.now() - start,
        error: String(e),
      };
    }
  },
});

/**
 * Test: Zone mode instructor is NOT in geospatial index
 */
export const testZoneModeNotInGeo = internalAction({
  args: {},
  handler: async (ctx): Promise<TestResult> => {
    const start = Date.now();
    const testName = "Zone mode instructor NOT in geo index";
    
    try {
      // Create a zone first
      const zoneId = await ctx.runMutation(internal.testing.dispatchTests.createTestZone, {
        name: "Test Zone 1",
      });
      
      // Create instructor in zone mode
      const instructorId = await ctx.runMutation(internal.testing.dispatchTests.createTestInstructor, {
        name: "Test Zone Instructor",
        dispatchMode: "zone",
        latitude: 32.0853,
        longitude: 34.7818,
        zoneIds: [zoneId],
        categories: ["pilates"],
      });
      
      // Sync zone subscriptions
      await ctx.runMutation(internal.zoneSubscriptions.syncZoneSubscriptions, {
        instructorId,
      });
      
      // Query geo index - should NOT find this instructor
      const matches = await ctx.runQuery(internal.geo.findInstructorsForJobQuery, {
        jobPoint: { latitude: 32.0853, longitude: 34.7818 },
        jobCategory: "pilates",
        requiresVerification: false,
      });
      
      const notFound = !matches.some(m => m.instructorId === instructorId);
      
      // Cleanup
      await ctx.runMutation(internal.testing.dispatchTests.cleanupTestData, {});
      // Note: Test zones are left in DB - they're harmless and have unique names
      
      return {
        name: testName,
        passed: notFound,
        duration: Date.now() - start,
        error: notFound ? undefined : "Zone mode instructor incorrectly found in geo index",
      };
    } catch (e) {
      return {
        name: testName,
        passed: false,
        duration: Date.now() - start,
        error: String(e),
      };
    }
  },
});

/**
 * Test: Zone subscriptions are created for zone mode instructors
 */
export const testZoneSubscriptionsCreated = internalAction({
  args: {},
  handler: async (ctx): Promise<TestResult> => {
    const start = Date.now();
    const testName = "Zone subscriptions created for zone mode";
    
    try {
      // Create zones
      const zone1 = await ctx.runMutation(internal.testing.dispatchTests.createTestZone, { name: "Zone A" });
      const zone2 = await ctx.runMutation(internal.testing.dispatchTests.createTestZone, { name: "Zone B" });
      
      // Create instructor with 2 zones and 2 categories
      const instructorId = await ctx.runMutation(internal.testing.dispatchTests.createTestInstructor, {
        name: "Multi Zone Instructor",
        dispatchMode: "zone",
        zoneIds: [zone1, zone2],
        categories: ["yoga", "pilates"],
      });
      
      // Sync subscriptions
      const result = await ctx.runMutation(internal.zoneSubscriptions.syncZoneSubscriptions, {
        instructorId,
      });
      
      // Should have 4 subscriptions: 2 zones × 2 categories
      const passed = result.created === 4;
      
      // Cleanup
      await ctx.runMutation(internal.testing.dispatchTests.cleanupTestData, {});
      
      return {
        name: testName,
        passed,
        duration: Date.now() - start,
        error: passed ? undefined : `Expected 4 subscriptions, got ${result.created}`,
      };
    } catch (e) {
      return {
        name: testName,
        passed: false,
        duration: Date.now() - start,
        error: String(e),
      };
    }
  },
});

/**
 * Test: Dual dispatch finds both radius and zone instructors
 */
export const testDualDispatch = internalAction({
  args: {},
  handler: async (ctx): Promise<TestResult> => {
    const start = Date.now();
    const testName = "Dual dispatch merges radius and zone results";
    
    try {
      // Create a zone
      const zoneId = await ctx.runMutation(internal.testing.dispatchTests.createTestZone, {
        name: "Dispatch Test Zone",
      });
      
      // Create radius mode instructor
      const radiusInstructor = await ctx.runMutation(internal.testing.dispatchTests.createTestInstructor, {
        name: "Radius Dispatch Instructor",
        dispatchMode: "radius",
        latitude: 32.0853,
        longitude: 34.7818,
        radiusKm: 10,
        categories: ["hiit"],
      });
      
      // Create zone mode instructor
      const zoneInstructor = await ctx.runMutation(internal.testing.dispatchTests.createTestInstructor, {
        name: "Zone Dispatch Instructor",
        dispatchMode: "zone",
        zoneIds: [zoneId],
        categories: ["hiit"],
      });
      
      // Sync zone subscriptions
      await ctx.runMutation(internal.zoneSubscriptions.syncZoneSubscriptions, {
        instructorId: zoneInstructor,
      });
      
      // Create studio and job
      const studioId = await ctx.runMutation(internal.testing.dispatchTests.createTestStudio, {
        name: "Test Studio",
        latitude: 32.0853,
        longitude: 34.7818,
        zoneId,
      });
      
      const jobId = await ctx.runMutation(internal.testing.dispatchTests.createTestJob, {
        studioId,
        title: "Test Job - HIIT",
        category: "hiit",
        latitude: 32.0853,
        longitude: 34.7818,
        zoneId,
        currentRate: 150,
      });
      
      // Query both dispatch systems
      const radiusMatches = await ctx.runQuery(internal.geo.findInstructorsForJobQuery, {
        jobPoint: { latitude: 32.0853, longitude: 34.7818 },
        jobCategory: "hiit",
        requiresVerification: false,
      });
      
      const zoneMatches = await ctx.runQuery(internal.zoneSubscriptions.findZoneInstructors, {
        zoneId,
        category: "hiit",
        requiresVerification: false,
      });
      
      const foundRadius = radiusMatches.some(m => m.instructorId === radiusInstructor);
      const foundZone = zoneMatches.some(m => m.instructorId === zoneInstructor);
      
      const passed = foundRadius && foundZone;
      
      // Cleanup
      await ctx.runMutation(internal.testing.dispatchTests.cleanupTestData, {});
      
      return {
        name: testName,
        passed,
        duration: Date.now() - start,
        error: passed ? undefined : `Radius found: ${foundRadius}, Zone found: ${foundZone}`,
      };
    } catch (e) {
      return {
        name: testName,
        passed: false,
        duration: Date.now() - start,
        error: String(e),
      };
    }
  },
});

// ==========================================
// STRESS TESTS
// ==========================================

/**
 * Stress test: Create many instructors and measure query performance
 */
export const stressTestDispatch = internalAction({
  args: {
    radiusModeCount: v.number(),
    zoneModeCount: v.number(),
  },
  handler: async (ctx, { radiusModeCount, zoneModeCount }): Promise<{
    setup: { radiusCreated: number; zoneCreated: number; setupTimeMs: number };
    query: { radiusQueryMs: number; zoneQueryMs: number; totalMatchMs: number };
    cleanup: { cleanupTimeMs: number };
  }> => {
    const setupStart = Date.now();
    
    // Create a zone for zone-mode instructors
    const zoneId = await ctx.runMutation(internal.testing.dispatchTests.createTestZone, {
      name: "Stress Test Zone",
    });
    
    // Create radius-mode instructors
    const radiusPromises = [];
    for (let i = 0; i < radiusModeCount; i++) {
      radiusPromises.push(
        ctx.runMutation(internal.testing.dispatchTests.createTestInstructor, {
          name: `Stress Radius ${i}`,
          dispatchMode: "radius",
          latitude: 32.0853 + (Math.random() * 0.1 - 0.05), // Spread around Tel Aviv
          longitude: 34.7818 + (Math.random() * 0.1 - 0.05),
          radiusKm: 5 + Math.random() * 10,
          categories: ["yoga", "pilates"][Math.floor(Math.random() * 2)] ? ["yoga"] : ["pilates"],
        })
      );
    }
    await Promise.all(radiusPromises);
    
    // Create zone-mode instructors and sync subscriptions
    const zonePromises = [];
    for (let i = 0; i < zoneModeCount; i++) {
      zonePromises.push(
        (async () => {
          const instructorId = await ctx.runMutation(internal.testing.dispatchTests.createTestInstructor, {
            name: `Stress Zone ${i}`,
            dispatchMode: "zone",
            zoneIds: [zoneId],
            categories: ["yoga"],
          });
          await ctx.runMutation(internal.zoneSubscriptions.syncZoneSubscriptions, {
            instructorId,
          });
        })()
      );
    }
    await Promise.all(zonePromises);
    
    const setupTimeMs = Date.now() - setupStart;
    
    // Query performance tests
    const radiusQueryStart = Date.now();
    const radiusMatches = await ctx.runQuery(internal.geo.findInstructorsForJobQuery, {
      jobPoint: { latitude: 32.0853, longitude: 34.7818 },
      jobCategory: "yoga",
      requiresVerification: false,
    });
    const radiusQueryMs = Date.now() - radiusQueryStart;
    
    const zoneQueryStart = Date.now();
    const zoneMatches = await ctx.runQuery(internal.zoneSubscriptions.findZoneInstructors, {
      zoneId,
      category: "yoga",
      requiresVerification: false,
    });
    const zoneQueryMs = Date.now() - zoneQueryStart;
    
    const totalMatchMs = radiusQueryMs + zoneQueryMs;
    
    // Cleanup
    const cleanupStart = Date.now();
    await ctx.runMutation(internal.testing.dispatchTests.cleanupTestData, {});
    const cleanupTimeMs = Date.now() - cleanupStart;
    
    return {
      setup: {
        radiusCreated: radiusModeCount,
        zoneCreated: zoneModeCount,
        setupTimeMs,
      },
      query: {
        radiusQueryMs,
        zoneQueryMs,
        totalMatchMs,
      },
      cleanup: {
        cleanupTimeMs,
      },
    };
  },
});

// ==========================================
// TEST RUNNER
// ==========================================

/**
 * Run all dispatch tests
 */
export const runAllTests = internalAction({
  args: {},
  handler: async (ctx): Promise<{
    total: number;
    passed: number;
    failed: number;
    results: TestResult[];
  }> => {
    const results: TestResult[] = [];
    
    // Run unit tests
    results.push(await ctx.runAction(internal.testing.dispatchTests.testRadiusModeGeoSync, {}));
    results.push(await ctx.runAction(internal.testing.dispatchTests.testZoneModeNotInGeo, {}));
    results.push(await ctx.runAction(internal.testing.dispatchTests.testZoneSubscriptionsCreated, {}));
    results.push(await ctx.runAction(internal.testing.dispatchTests.testDualDispatch, {}));
    
    const passed = results.filter(r => r.passed).length;
    const failed = results.filter(r => !r.passed).length;
    
    console.log(`\n===== TEST RESULTS =====`);
    console.log(`Total: ${results.length} | Passed: ${passed} | Failed: ${failed}`);
    for (const result of results) {
      const status = result.passed ? "✅" : "❌";
      console.log(`${status} ${result.name} (${result.duration}ms)`);
      if (result.error) console.log(`   Error: ${result.error}`);
    }
    console.log(`========================\n`);
    
    return { total: results.length, passed, failed, results };
  },
});


