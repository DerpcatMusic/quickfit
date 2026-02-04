# QuickFit Marketplace Patterns Analysis

## 1. Bid/Ask Matching System (First-Come-First-Served)

### Implementation
- File: backend/convex/jobs.ts (lines 366-430)
- Status flow: "open" -> "claimed" -> "confirmed" (or back to "open" on rejection)

### Race Condition Handling
Uses atomic mutation + status check + geospatial index removal:

1. Check if job is still "open"
2. Change status to "claimed" in single atomic mutation
3. Remove job from geospatial index immediately
4. Insert claim record

Result: Only one instructor succeeds; all others get "Job is no longer available" error.

## 2. Geospatial Radius Matching

### How Instructors Set Radius
- During onboarding: completeOnboarding accepts radiusKm parameter
- Default: 5km, min: 0.5km, max: 50km
- Stored in user record AND geospatial index as sortKey
- Can be updated via updateRadius mutation anytime

### Two-Way Matching

**Forward (Instructor -> Jobs)**:
Find all open jobs within instructor's radius for matching categories

**Reverse (Job -> Instructors)**:
Find all instructors whose radius COVERS the job location

### Precision
- Haversine formula provides meter-level accuracy
- A 2.95km job WILL match a 3.00km radius

## 3. Instructor Availability & Location

### Location Types
- Home Location: Set during onboarding (permanent)
- Current Location: Updated via GPS when app active  
- Effective Location: Used for queries

### Zone Selection
- Pikud HaOref zones (Israel emergency alert zones)
- Instructors select preferred zones during onboarding
- Used for UI filtering, NOT radius matching

## 4. Opportunity Creation Flow

### Studio Post Job
1. Studio submits job via postJob mutation
2. SOS detection: < 3 hours before start = +15% rate
3. Job inserted with status = "open"
4. Job location synced to geospatial index
5. If SOS, added to priority queue
6. Notification dispatch scheduled

## 5. Real-Time Opportunity Locking

### No Traditional Locks
Instead uses:
1. Atomic status change
2. Immediate geospatial index removal
3. Real-time subscriptions for UI updates

### Double-Booking Prevention
Three-layer protection:
1. Status check before claim
2. Atomic mutation (only one succeeds)
3. Immediate index removal (no one else sees it)

## 6. Conflict Resolution

### Studio Accepts Claim
Claim -> accepted, Job -> confirmed

### Studio Rejects Claim  
Claim -> rejected, Job -> open, Job re-indexed

### Studio Cancels Job
Job -> cancelled, Removed from index, Instructor notified

### Instructor Withdraws Claim
Claim -> withdrawn, Job -> open, Job re-indexed

## 7. Notification System

### Types
- new_job: Instructors within radius + category match
- job_claimed: Studio when instructor claims
- claim_accepted: Instructor when studio accepts
- claim_rejected: Instructor when studio rejects
- job_cancelled: Claimed instructor when studio cancels

## Key Insights

### No Traditional Locking Needed
Atomic status change + index removal = immediate lock
Works well with real-time subscriptions

### Missing Components
Per FEATURES.md:
- Payment/Escrow system not implemented
- Fraud detection (GPS telemetry) not implemented
- Calendar auto-sync not implemented

