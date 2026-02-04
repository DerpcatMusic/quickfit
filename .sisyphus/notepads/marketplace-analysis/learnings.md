# QuickFit Codebase Learnings

## Patterns & Conventions

### Convex Backend Patterns

1. **Separation of Queries vs Mutations**
   - Queries (read-only): getNearbyJobs, getJobById
   - Mutations (write): postJob, claimJob, updateProfile
   - Internal queries/mutations: For server-side use only

2. **Geospatial Index Pattern**
   - Two indices: instructorGeo and jobGeo
   - Sync on every location change
   - Remove on status change (claimed/cancelled)
   - Haversine distance for precision

3. **Real-time Subscriptions**
   - Frontend subscribes via ConvexClient.instance.subscribe()
   - Backend pushes updates automatically
   - No polling needed

4. **Atomic Mutations for Safety**
   - Single mutation per operation
   - Status checks before writes
   - Index updates in same transaction

### Flutter/Riverpod Patterns

1. **Provider Structure**
   - State classes for data (JobsState)
   - Notifier classes for logic (JobsNotifier)
   - Riverpod code generation for type safety

2. **Real-time State Management**
   - useQuery for data fetching
   - Subscriptions for live updates
   - Optimistic UI for user actions

3. **Error Handling**
   - State has error field
   - Try-catch on mutations
   - User feedback via SnackBars

### Geospatial Patterns

1. **Haversine Distance**
   - Used for precise radius matching
   - Meter-level accuracy
   - Two functions: haversineDistanceMeters, haversineDistanceKm

2. **Reverse Radius Matching**
   - Job location is center
   - Find instructors whose radius covers job
   - Post-filter by distance

3. **Forward Radius Matching**
   - Instructor location is center
   - Find jobs within instructor's radius
   - Pre-filter by status and category

## Successful Approaches

### 1. Convex GeospatialIndex
- Native geospatial support
- Efficient radius queries
- Filters for category, status, verification
- Reduces manual distance calculations

### 2. Status-Based Workflow
- Clear state machine: open -> claimed -> confirmed
- Each transition has explicit logic
- Easy to reason about

### 3. Real-time Subscriptions
- Convex handles push updates
- UI stays in sync
- No manual refresh needed

### 4. Atomic Mutations
- Prevents race conditions
- No need for explicit locks
- Convex handles transactions

## Architectural Choices

### Why Convex?
- Built-in real-time
- Geospatial support
- Type-safe API
- No server deployment needed

### Why Flutter?
- Cross-platform mobile
- Riverpod for state
- Good performance
- Material Design

### Why Haversine?
- Sufficient for Israel-scale
- No external geospatial libs
- Meter-level precision
- Simple to implement

## Data Flow Examples

### Job Creation Flow
1. Studio -> postJob mutation
2. Validate studio role
3. Calculate SOS boost
4. Insert job (status: open)
5. Sync to jobGeo index
6. Schedule notifications
7. Background: findInstructorsForJob
8. Background: send FCM pushes
9. Background: mark notified

### Job Claim Flow
1. Instructor -> claimJob mutation
2. Validate instructor role
3. Check job status == "open"
4. Calculate distance (Haversine)
5. Insert claim record
6. Update job status to "claimed"
7. Remove job from jobGeo index
8. Schedule studio notification
9. Real-time: all instructors see job disappear

### Claim Accept Flow
1. Studio -> respondToClaim mutation(accept: true)
2. Validate studio is job owner
3. Update claim status to "accepted"
4. Update job status to "confirmed"
5. Schedule instructor notification
6. Real-time: instructor sees confirmation

## Index Strategy

### users table
- by_firebaseUid: Fast auth lookup
- by_role: Filter by studio/instructor
- by_verified: Find verified instructors
- by_category: Skill-based filtering

### jobs table
- by_studio: Studio's job history
- by_status: Find open jobs
- by_category_status: Category-specific searches
- by_claimedBy: Instructor's claims
- by_startTime: Time-based queries

### claims table
- by_job: All claims for a job
- by_instructor: Instructor's claim history
- by_job_status: Filter by status

## Security Considerations

### Auth Checks
- Every mutation validates userIdentity
- Role checks before operations
- Owner checks before modifications

### Input Validation
- Radius limits: 0.5km to 50km
- Future dates for jobs
- Required fields validation

### Data Privacy
- Email, phone only to owner
- Sensitive fields filtered in public queries

## Performance Optimizations

### Geospatial Queries
- Pre-filter by index (category, status)
- Post-filter by Haversine distance
- Limit result count (100, 1000)

### Subscription Management
- Cancel on dispose
- Re-subscribe on refresh
- Prevent duplicate subscriptions

### Caching
- Convex caches query results
- Subscriptions reduce DB load
- No manual caching needed

## Future Improvements

### Missing Features
1. Payment/Escrow system
2. Fraud detection (GPS telemetry)
3. Calendar auto-sync
4. Skill-based job matching (categories only partially implemented)
5. H3 neighbor search (partially scaffolded)

### Technical Debt
1. H3 neighbor search incomplete (FEATURES.md)
2. Push notification action incomplete
3. Web OAuth issues (FEATURES.md)
4. Type generation missing for Convex (FEATURES.md)

### Scalability Considerations
- Geospatial index may need optimization at scale
- FCM push rate limits
- Subscription load with many users

