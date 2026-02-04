# H3 Spatial Indexing - Architectural Decisions

## Resolution Choice for QuickFit

**Decision**: Use **H3 Resolution 11** for instructor work area indexing

**Rationale**:
- Resolution 11 provides ~2,149 m² cell area (46m edge length)
- This aligns with ~50m precision requirement
- Balances accuracy with performance (not too fine-grained)
- Compatible with common H3 use cases

**Alternatives Considered**:
- Resolution 10 (15,047 m², ~76m edge) - Too coarse, would miss jobs
- Resolution 12 (307 m², ~11m edge) - Too fine, unnecessary overhead
- Multi-resolution approach - Complex, defer until needed

**Evidence**: [H3 Resolution Table](https://h3geo.org/docs/core-library/restable/)

## Matching Strategy Selection

**Decision**: Use **kRing (grid-based) approach** for primary matching

**Rationale**:
- O(1) lookup performance with pre-computed work areas
- Simple set containment check
- No need for complex geometric calculations
- Proven at scale by Uber and others
- Works perfectly for circular work areas

**Fallback Strategy**: Hierarchical matching with coarser resolution

**Rationale**:
- If exact match not found at Res 11, try Res 9 cells
- Provides broader coverage for edge cases
- Still O(1) performance with two sets
- Accounts for minor GPS errors or boundary effects

**Alternative Not Chosen**: polygonToCells (circle approximation)

**Reason**:
- More complex to implement
- Slower than kRing for simple cases
- Only needed if precise polygon shapes required (non-circular)

## Data Storage Architecture

**Decision**: Store H3 work areas as **sorted string arrays** in instructor records

**Rationale**:
- Compact storage: Each H3 ID is ~15 chars ('89283082b7ffff')
- Fast lookups: Array.includes() is optimized in JavaScript
- Easy serialization: JSON.stringify() / JSON.parse()
- Database indexing: Can create index on array column for fast queries

**Schema**:
```javascript
{
  id: 'instructor-123',
  name: 'Jane Doe',
  email: 'jane@example.com',
  lat: 40.7580,
  lng: -73.9855,
  workRadiusKm: 5,
  workAreaH3Res11: [
    '89283082b7ffff',  // Sorted array for binary search
    '8928308280fffff',
    '89283082803ffff',
    // ... ~1,000 cells for 5km radius at Res 11
  ],
  workAreaH3Res9: [
    '89283082b7ffff',  // Coarser for fallback
    '8928308280fffff',
    // ... ~20 cells at Res 9
  ],
  createdAt: '2026-02-04T18:45:00Z',
  updatedAt: '2026-02-04T18:45:00Z'
}
```

## Algorithm Selection for Job Matching

**Decision**: **Set containment with distance fallback** for job matching

**Rationale**:
- Primary: O(1) set lookup for exact match
- Secondary: O(n) grid distance check for nearby matches
- Return results sorted by distance for user experience
- Allows partial matches (nearby instructors)

**Algorithm**:
```javascript
function matchJobsToInstructors(job, allInstructors) {
  const jobCell = h3.latLngToCell(job.lat, job.lng, 11);
  
  // Primary: exact match (O(1))
  const exactMatches = allInstructors.filter(instructor =>
    instructor.workAreaH3Res11.includes(jobCell)
  );
  
  if (exactMatches.length > 0) {
    return exactMatches.map(instructor => ({
      instructor,
      distance: 0,  // Grid distance
      matchType: 'exact'
    }));
  }
  
  // Secondary: nearby matches (O(n*m) where m = avg work area size)
  const nearbyMatches = [];
  for (const instructor of allInstructors) {
    let minDistance = Infinity;
    for (const cell of instructor.workAreaH3Res11) {
      try {
        const distance = h3.gridDistance(cell, jobCell);
        if (distance !== null && distance < minDistance) {
          minDistance = distance;
        }
      } catch (e) {
        // Pentagon distortion
        continue;
      }
    }
    if (minDistance <= 3) { // Max 3 cells away (~150m)
      nearbyMatches.push({
        instructor,
        distance: minDistance,
        matchType: 'nearby'
      });
      break;
    }
  }
  
  // Combine and sort by distance
  return [...exactMatches, ...nearbyMatches]
    .sort((a, b) => a.distance - b.distance);
}
```

## Client vs Server Processing

**Decision**: **Server-side H3 computation**, client-side storage

**Rationale**:
- Server: Heavy lifting, consistent results, database integration
- Client: Cache work area cells locally, offline matching
- Reduces redundant H3 conversions on client
- Allows instant job/instructor matching without network

**Architecture**:
```
Server Responsibilities:
- Compute instructor work area H3 cells (on registration/update)
- Compute job H3 cells (when job created)
- Store H3 arrays in database
- Perform set containment queries

Client Responsibilities:
- Cache instructor work areas locally
- Pre-compute job H3 cells
- Perform initial matching using local data
- Sync with server for comprehensive results
```

## Database Indexing Strategy

**Decision**: **Hash index on H3 ID columns** + **GIN index on arrays**

**Rationale**:
- Hash index for single H3 ID lookups: O(1)
- GIN index for array containment: O(log n)
- PostgreSQL/SQLite both support these indexes
- Enables efficient job matching queries

**PostgreSQL Schema**:
```sql
CREATE TABLE instructors (
  id UUID PRIMARY KEY,
  name VARCHAR(255),
  email VARCHAR(255),
  lat FLOAT,
  lng FLOAT,
  work_radius_km FLOAT,
  work_area_h3_res11 TEXT[],  -- Array of H3 strings
  work_area_h3_res9 TEXT[],   -- Fallback coarser
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Index for exact H3 cell lookups
CREATE INDEX idx_instructor_work_area ON instructors 
  USING GIN (work_area_h3_res11);

-- Index for coarser resolution fallback
CREATE INDEX idx_instructor_work_area_res9 ON instructors 
  USING GIN (work_area_h3_res9);

-- B-tree index for other common queries
CREATE INDEX idx_instructor_location ON instructors (lat, lng);
CREATE INDEX idx_instructor_created ON instructors (created_at DESC);
```

## Caching Strategy

**Decision**: **Multi-level caching** with TTL

**Rationale**:
- L1: In-memory cache (Map/Set) for active work areas
- L2: LocalStorage/IndexedDB for offline access
- L3: Server cache for shared work areas
- TTL: 24 hours for work areas, indefinite for static data

**Implementation**:
```javascript
class H3Cache {
  constructor() {
    this.memoryCache = new Map();  // L1: Fast access
    this.persistentCache = new H3Store();  // L2: Offline storage
  }
  
  async getWorkArea(instructorId) {
    // L1: Check memory
    if (this.memoryCache.has(instructorId)) {
      return this.memoryCache.get(instructorId);
    }
    
    // L2: Check persistent
    const cached = await this.persistentCache.get(instructorId);
    if (cached && Date.now() - cached.timestamp < 24*60*60*1000) {
      this.memoryCache.set(instructorId, cached);
      return cached.cells;
    }
    
    // L3: Fetch from server
    const fresh = await this.fetchWorkArea(instructorId);
    this.memoryCache.set(instructorId, fresh);
    await this.persistentCache.set(instructorId, {
      cells: fresh,
      timestamp: Date.now()
    });
    return fresh;
  }
}
```

## Error Handling Strategy

**Decision**: **Graceful degradation** with multiple fallbacks

**Rationale**:
- H3 errors (pentagon distortion) should not crash app
- Grid distance failures are expected edge cases
- Provide partial results rather than none
- Log errors for monitoring and improvement

**Fallback Hierarchy**:
1. Exact match (Res 11) - ideal
2. Nearby match (Res 11, distance ≤ 3) - good
3. Coarser match (Res 9) - acceptable
4. Geographic distance (Haversine) - last resort
5. All instructors - no geographic filter

**Implementation**:
```javascript
function findInstructors(job) {
  try {
    // Try exact match
    let matches = tryExactMatch(job);
    if (matches.length > 0) return matches;
    
    // Try nearby match
    matches = tryNearbyMatch(job);
    if (matches.length > 0) return matches;
    
    // Try coarser resolution
    matches = tryCoarserMatch(job);
    if (matches.length > 0) return matches;
    
    // Fall back to geographic distance
    return tryGeographicFallback(job);
    
  } catch (error) {
    // Log but don't crash
    console.error('Matching e
