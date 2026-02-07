// H3 Hexagonal Spatial Indexing Utilities
// Resolution 11 = ~50m precision

import * as h3 from "h3-js";
import { v } from "convex/values";
import { internalQuery } from "./_generated/server";

const RESOLUTION = 11;
const EDGE_LENGTH_M = 28.7; // Average edge length at res 11

/**
 * Convert lat/lng to H3 cell ID at resolution 11
 */
export function latLngToHex11(lat: number, lng: number): string {
  return h3.latLngToCell(lat, lng, RESOLUTION);
}

/**
 * Get all H3 cells within a radius (in km) from a center point
 * Uses k-ring for efficient hex-based search
 */
export function getHexesInRadius(centerLat: number, centerLng: number, radiusKm: number): string[] {
  const centerHex = latLngToHex11(centerLat, centerLng);
  
  // Calculate k (number of rings) based on radius
  // Each ring adds ~28.7m at resolution 11
  const k = Math.max(1, Math.ceil((radiusKm * 1000) / EDGE_LENGTH_M));
  
  // Get all hexes within k rings
  return h3.gridDisk(centerHex, k);
}

/**
 * Convert H3 cell to lat/lng center
 */
export function hexToLatLng(hexId: string): { lat: number; lng: number } {
  const [lat, lng] = h3.cellToLatLng(hexId);
  return { lat, lng };
}

/**
 * Check if a hex is within a set of hexes
 */
export function isHexInSet(hexId: string, hexSet: string[]): boolean {
  return hexSet.includes(hexId);
}

/**
 * Get hex boundary for visualization
 */
export function getHexBoundary(hexId: string): Array<[number, number]> {
  return h3.cellToBoundary(hexId, true); // true = return as [lat, lng] pairs
}

// ==========================================
// CONVEX API WRAPPERS
// ==========================================

/**
 * Internal query to get neighboring hexes (1-ring expansion).
 * Used by dispatchJobNotifications action.
 */
export const getNeighbors = internalQuery({
  args: { hex: v.string() },
  handler: async (ctx, { hex }) => {
    // Returns the 6 neighbors of the given hex (distance k=1, excluding self)
    // Actually gridDisk(hex, 1) returns center + neighbors. 
    // We filter out the center to get only neighbors.
    const all = h3.gridDisk(hex, 1);
    return all.filter(h => h !== hex);
  },
});
