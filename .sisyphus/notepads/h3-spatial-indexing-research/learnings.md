# H3 Hexagonal Hierarchical Spatial Indexing Research

## What is H3?

H3 is a **hexagonal hierarchical spatial indexing system** developed by Uber that partitions the world into hexagonal cells for efficient geospatial analytics and location-based matching.

### Key Characteristics:
- **Open Source**: Apache 2.0 license
- **Developer**: Uber Technologies
- **Purpose**: Efficient location-based matching and geospatial analysis
- **Grid Structure**: Hexagonal tiles with hierarchical subdivision (aperture 7)
- **Global Coverage**: Complete coverage of Earth's surface
- **Coordinate System**: WGS84 / EPSG:4326 with spherical Earth model

### How It Works:
1. **Base Resolution (0)**: 122 cells (110 hexagons + 12 pentagons)
2. **Hierarchical Subdivision**: Each hexagon divides into 7 child cells
3. **16 Resolution Levels**: From 0 (entire cities) to 15 (sub-meter precision)
4. **Cell Indexing**: 64-bit integer identifiers representing unique cells
5. **Grid Distance**: Number of "hops" between adjacent cells

### Why Hexagons?
- Equal area representation (better than squares)
- Consistent neighbor distances (all 6 neighbors are equidistant)
- Minimal distortion compared to square grids
- Better approximation of circular areas
- Efficient for clustering and aggregation

## H3 Resolution Levels for 50m Precision

Based on [H3 resolution table](https://h3geo.org/docs/core-library/restable/):

| Resolution | Avg Area (m²) | Avg Edge Length (m) | Best For |
|------------|-----------------|---------------------|-----------|
| 10 | 15,047 | 75.9 | 100m precision |
| **11** | **2,149** | **28.7** | **~50m precision** |
| 12 | 307 | 10.8 | 25m precision |

**Recommended Resolution**: **Resolution 11** for ~50m accuracy
- Cell area: ~2,149 m²
- Edge length: ~28.7m
- Balance between precision and performance

### Resolution Selection Guidelines:
- Use **Res 9** (105,333 m²) for ~100m precision (larger areas)
- Use **Res 11** (2,149 m²) for ~50m precision (urban areas)
- Use **Res 12** (307 m²) for ~25m precision (high accuracy)
- Avoid higher resolutions (13+) for performance-critical applications

## Code Examples

### 1. Converting Lat/Lng to H3 Index

**JavaScript/TypeScript:**
```javascript
import h3 from 'h3-js';

// Convert coordinates to H3 cell at resolution 11
const lat = 37.7749;
const lng = -122.4194;
const resolution = 11;

const h3Index = h3.latLngToCell(lat, lng, resolution);
console.log(h3Index); // e.g., '89283082b7ffff'

// Get cell center back
const center = h3.cellToLatLng(h3Index);
console.log(center); // {lat: 37.775, lng: -122.419}

// Get cell boundary (polygon)
const boundary = h3.cellToBoundary(h3Index);
console.log(boundary); // Array of lat/lng pairs
```

**Python:**
```python
import h3

# Convert coordinates to H3 cell
lat = 40.7128
lng = -74.0060
resolution = 11

h3_index = h3.geo_to_h3(lat, lng, resolution)
print(h3_index)  # e.g., 8a283082a677fff

# Get cell center
center = h3.h3_to_geo(h3_index)
print(center)  # {'lat': 40.7128, 'lng': -74.0060}

# Get cell boundary
boundary = h3.h3_to_geo_boundary(h3_index)
print(boundary)  # GeoJSON polygon
```

### 2. Finding All Hexes Within a Radius (Instructor Work Area)

**Method A: kRing (Fast - Grid Steps)**
Best for circular work areas centered at instructor's location.

```javascript
import h3 from 'h3-js';

const instructorLat = 40.7580;
const instructorLng = -73.9855;
const resolution = 11;
const workRadiusKm = 5; // 5km radius

// Convert instructor location to H3 cell
const originCell = h3.latLngToCell(instructorLat, instructorLng, resolution);

// Calculate k (grid steps) for radius
// Resolution 11 has ~28.7m edge length, so 5km ≈ 174 steps
const k = Math.ceil(workRadiusKm * 1000 / 28.7);

// Get all cells within k steps (hollow ring)
const workAreaCells = h3.kRing(originCell, k);

console.log(`Work area has ${workAreaCells.length} cells`);

// To get filled circle (all cells including center), use kRingDistances
const allCells = h3.kRingDistances(originCell, k);
```

**Method B: Polygon to Cells (Precise - Circular Area)**
Best for precise circular coverage at specific radius.

```javascript
import h3 from 'h3-js';

// Create a circle polygon
function createCirclePolygon(lat, lng, radiusKm) {
  const points = [];
  for (let i = 0; i < 360; i += 10) { // 36 points for smoothness
    const angle = (i * Math.PI) / 180;
    const R = 6371; // Earth radius in km
    const lat2 = lat + (radiusKm * Math.cos(angle)) / R;
    const lng2 = lng + (radiusKm * Math.sin(angle)) / (R * Math.cos(lat * Math.PI / 180));
    points.push([lat2, lng2]);
  }
  return [points];
}

const lat = 40.7580;
const lng = -73.9855;
const radiusKm = 5;
const resolution = 11;

// Create circle polygon
const circle = createCirclePolygon(lat, lng, radiusKm);

// Get all H3 cells within polygon
const workAreaCells = h3.polygonToCells(circle, resolution);

console.log(`Precise circle has ${workAreaCells.length} cells`);
```

**Python Version:**
```python
import h3
import math

lat = 40.7580
lng = -73.9855
radius_km = 5
resolution = 11

# Method 1: kRing (faster, hex-based)
origin = h3.geo_to_h3(lat, lng, resolution)
edge_length_m = 28.7  # at resolution 11
k = math.ceil(radius_km * 1000 / edge_length_m)
work_area = h3.k_ring(origin, k)

# Method 2: polygonToCells (more precise, circle-based)
from shapely.geometry import Point
center = Point(lng, lat)
circle = center.buffer(radius_km * 1000)  # buffer in meters
geojson = circle.__geo_interface__
work_area = h3.polyfill(geojson, resolution)
```

### 3. Checking if a Point is Within a Set of Hexes

**JavaScript:**
```javascript
import h3 from 'h3-js';

// Instructor's work area cells (pre-computed)
const workAreaCells = [
  '89283082b7ffff', '8928308280fffff', '89283082803ffff',
  // ... more cells
];

// Job location
const jobLat = 40.7614;
const jobLng = -73.9776;

// Convert job location to H3 cell
const jobCell = h3.latLngToCell(jobLat, jobLng, 11);

// Check if job cell is in work area
const isMatch = workAreaCells.includes(jobCell);
console.log(`Job within radius: ${isMatch}`);
```

**Python:**
```python
import h3

# Instructor's work area (set of H3 indexes)
work_area_cells = {
    '89283082b7ffff', '8928308280fffff', '89283082803ffff',
    # ... more cells
}

# Job location
job_lat = 40.7614
job_lng = -73.9776

# Convert to H3
job_cell = h3.geo_to_h3(job_lat, job_lng, 11)

# Check if in work area
is_match = job_cell in work_area_cells
print(f"Job within radius: {is_match}")
```

**Alternative: Grid Distance Check**
For more nuanced matching (e.g., partial matches):

```javascript
import h3 from 'h3-js';

const workAreaCells = ['89283082b7ffff', '8928308280fffff', ...];
const jobCell = h3.latLngToCell(40.7614, -73.9776, 11);

// Find minimum distance to any cell in work area
let minDistance = Infinity;
for (const cell of workAreaCells) {
  try {
    const distance = h3.gridDistance(cell, jobCell);
    if (distance !== null && distance < minDistance) {
      minDistance = distance;
    }
  } catch (e) {
    // Pentagon distortion can cause errors
  }
}

console.log(`Minimum grid distance: ${minDistance} cells`);
// Distance of 0 means perfect match, 1 means 1 cell away, etc.
```

## Performance Benefits vs Traditional Geospatial Queries

### H3 Advantages:

1. **O(1) Lookups**: Cell membership check is a simple hash/set lookup
2. **No Spatial Indexes Needed**: No requirement for R-tree, Quadtree, or GiST indexes
3. **Constant-Time Containment**: Checking if point-in-cell is instant
4. **Hierarchical Aggregation**: Easy to zoom in/out for different precision levels
5. **Compact Storage**: 64-bit integers vs complex geometries
6. **Neighbor Operations**: Fast grid traversal (6 neighbors per cell)
7. **Memory Efficient**: Set operations are extremely fast

### Traditional Geospatial Query Disadvantages:

1. **Haversine Distance**: O(n) - must calculate distance to all points
2. **PostGIS/GeoDjango**: Requires spatial indexes, still O(log n)
3. **Circle Intersections**: Complex geometric calculations
4. **Index Maintenance**: Spatial indexes need rebuilding on updates
