import { action } from "./_generated/server";
import { internal } from "./_generated/api";

const CITIES_URL = "https://raw.githubusercontent.com/eladnava/pikud-haoref-api/master/cities.json";
const POLYGONS_URL = "https://raw.githubusercontent.com/eladnava/pikud-haoref-api/master/polygons.json";

export const seedPikudHaorefZones = action({
  args: {},
  handler: async (ctx) => {
    console.log("Starting zone seeding...");

    // 1. Fetch data
    const [citiesRes, polygonsRes] = await Promise.all([
      fetch(CITIES_URL),
      fetch(POLYGONS_URL),
    ]);

    if (!citiesRes.ok) throw new Error(`Failed to fetch cities: ${citiesRes.statusText}`);
    if (!polygonsRes.ok) throw new Error(`Failed to fetch polygons: ${polygonsRes.statusText}`);

    const cities = await citiesRes.json();
    const polygons = await polygonsRes.json();

    console.log(`Fetched ${cities.length} cities.`);

    let seededCount = 0;
    let skippedCount = 0;

    // 2. Iterate and Seed
    for (const city of cities as any[]) {
      const cityId = city.id.toString();
      const polygonData = polygons[cityId];

      if (!polygonData) {
        // console.log(`No polygon for city: ${city.name_en} (${cityId})`);
        skippedCount++;
        continue;
      }

      // Convert format [[lat, lng], ...] -> [{lat, lng}, ...]
      const formattedPolygon = polygonData.map((p: number[]) => ({
        lat: p[0],
        lng: p[1],
      }));

      // Use city lat/lng as centroid
      const centroid = {
        lat: city.lat,
        lng: city.lng,
      };

      try {
        await ctx.runMutation(internal.zones.seedZone, {
          orefId: cityId,
          name: city.name_en || city.name, // Prefer English, fallback to Hebrew
          nameHebrew: city.name,
          city: city.zone_en || city.zone, // "Zone" in Oref terms is usually the larger area (e.g. "Dan"), or specific city group
          polygon: formattedPolygon,
          centroid: centroid,
          shelterTime: city.countdown,
        });
        seededCount++;
        if (seededCount % 50 === 0) console.log(`Seeded ${seededCount} zones...`);
      } catch (e) {
        console.error(`Failed to seed zone ${city.name_en} (${cityId}):`, e);
      }
    }

    console.log(`Seeding complete. Seeded: ${seededCount}, Skipped: ${skippedCount}`);
    return { seeded: seededCount, skipped: skippedCount };
  },
});
