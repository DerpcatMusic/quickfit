// convex/convex.config.ts
// Convex application configuration with geospatial component

import geospatial from "@convex-dev/geospatial/convex.config.js";
import { defineApp } from "convex/server";

const app = defineApp();

// Enable geospatial component for location-based queries
app.use(geospatial);

export default app;
