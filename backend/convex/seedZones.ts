// convex/actions/seedZones.ts
// Fetches Pikud HaOref zone data from GitHub and seeds the zones table
// Run this once to populate the ~1800 Israeli geographic zones

import { action } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";

// URL to the Pikud HaOref zone polygons (real geographic boundaries)
const POLYGONS_URL =
  "https://raw.githubusercontent.com/eladnava/pikud-haoref-api/master/polygons.json";

// Type for the raw Pikud HaOref polygon data
interface OrefZone {
  id?: number;
  label?: string;
  label_he?: string;
  value?: string;
  polygon?: number[][];
  migun_time?: number;
  // Some zones may have different structures
  [key: string]: unknown;
}

/**
 * Calculate centroid of a polygon
 */
function calculateCentroid(polygon: { lat: number; lng: number }[]): {
  lat: number;
  lng: number;
} {
  if (polygon.length === 0) {
    return { lat: 0, lng: 0 };
  }

  let sumLat = 0;
  let sumLng = 0;

  for (const point of polygon) {
    sumLat += point.lat;
    sumLng += point.lng;
  }

  return {
    lat: sumLat / polygon.length,
    lng: sumLng / polygon.length,
  };
}

/**
 * Extract city name from zone label
 * e.g., "תל אביב - מרכז העיר" -> "תל אביב"
 */
function extractCity(label: string): string | undefined {
  if (label.includes(" - ")) {
    return label.split(" - ")[0].trim();
  }
  if (label.includes("-")) {
    return label.split("-")[0].trim();
  }
  return undefined;
}

/**
 * Public action to trigger zone seeding (for admin use)
 * Run this once: await actions.seedZones.seedZones({ confirm: true })
 */
export const seedZones = action({
  args: { confirm: v.boolean() },
  handler: async (ctx, args) => {
    if (!args.confirm) {
      return { error: "Must confirm=true to seed zones" };
    }

    // Clear existing zones first
    await ctx.runMutation(internal.zones.clearAllZones);

    // Fetch the polygon data directly
    console.log("Fetching Pikud HaOref zone data from GitHub...");
    const response = await fetch(POLYGONS_URL);
    if (!response.ok) {
      throw new Error(`Failed to fetch zones: ${response.statusText}`);
    }

    const rawData = await response.json();
    console.log(`Fetched raw data, processing zones...`);

    // Parse zones
    let zones: OrefZone[] = [];
    if (Array.isArray(rawData)) {
      zones = rawData;
    } else if (rawData.zones && Array.isArray(rawData.zones)) {
      zones = rawData.zones;
    } else if (typeof rawData === "object") {
      zones = Object.values(rawData).filter(
        (v): v is OrefZone =>
          typeof v === "object" && v !== null && "polygon" in v
      );
    }

    console.log(`Found ${zones.length} zones to process`);

    let processed = 0;
    let skipped = 0;

    for (const zone of zones) {
      try {
        const orefId = String(zone.id ?? zone.value ?? `zone_${processed}`);
        const nameHebrew = zone.label_he ?? zone.label ?? zone.value ?? orefId;
        const name = zone.label ?? zone.value ?? orefId;
        const rawPolygon = zone.polygon;

        if (!rawPolygon || rawPolygon.length < 3) {
          skipped++;
          continue;
        }

        const polygon = rawPolygon.map((point) => ({
          lat: point[0],
          lng: point[1],
        }));

        const centroid = calculateCentroid(polygon);
        const city = extractCity(nameHebrew);
        const shelterTime = zone.migun_time ?? undefined;

        await ctx.runMutation(internal.zones.seedZone, {
          orefId,
          name,
          nameHebrew,
          city,
          polygon,
          centroid,
          shelterTime,
        });

        processed++;

        if (processed % 100 === 0) {
          console.log(`Processed ${processed} zones...`);
        }
      } catch (error) {
        console.error(`Error processing zone:`, error);
        skipped++;
      }
    }

    console.log(`Zone seeding complete. Processed: ${processed}, Skipped: ${skipped}`);
    return { processed, skipped };
  },
});

