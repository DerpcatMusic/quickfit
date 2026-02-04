# 🚨 CRITICAL HOLES & DEPRECATED CODE AUDIT

## ❌ CRITICAL MISSING PIECES

### 1. **STORAGE FUNCTIONS - BROKEN CERTIFICATE UPLOAD**
**Files**: `apps/mobile/lib/features/verification/presentation/verification_screen.dart`
**Issue**: Frontend calls non-existent backend functions:
- ❌ `storage:generateUploadUrl` - NOT IMPLEMENTED
- ❌ `storage:getUrl` - NOT IMPLEMENTED
- **Impact**: Certificate upload COMPLETELY BROKEN
- **Fix**: Need to create `backend/convex/storage.ts` with these functions

### 2. **STUDIO JOBS PROVIDER - MISSING**
**File**: Frontend calls `studioJobsProvider` in post_job_screen.dart
**Issue**: `apps/mobile/lib/features/jobs/providers/studio_jobs_provider.dart` - DOESN'T EXIST
**Impact**: Studios can't see their posted jobs
**Fix**: Need to create provider

### 3. **CLAIMS PROVIDER - MISSING**
**Path**: `apps/mobile/lib/features/claims/providers/`
**Issue**: Folder exists but is EMPTY
**Impact**: Can't manage claims from frontend
**Fix**: Need to implement claims provider

### 4. **RATINGS SYSTEM - NOT IMPLEMENTED**
**Path**: `apps/mobile/lib/features/ratings/`
**Issue**: Feature folder doesn't exist
**Schema**: Has `ratings` table but no frontend
**Impact**: No reputation system
**Fix**: Create entire ratings feature

### 5. **ADMIN PANEL - NOT IMPLEMENTED**
**Path**: `apps/mobile/lib/features/admin/`
**Issue**: Feature folder doesn't exist
**Impact**: Admins can't review certificates
**Fix**: Create admin verification review UI

### 6. **PAYMENTS - NOT IMPLEMENTED**
**Path**: `apps/mobile/lib/features/payments/`
**Issue**: Feature folder doesn't exist
**Impact**: No payment processing
**Fix**: Create payment integration

---

## ⚠️ DISCONNECTED FEATURES

### 7. **BACKUP QUEUE - BACKEND ONLY**
**Location**: Backend has backup queue logic
**Issue**: Frontend doesn't show backup status
**Impact**: Instructors don't know if they're backup
**Fix**: Update JobCard to show "Backup" status

### 8. **H3 HEX DISPLAY - INVISIBLE**
**Location**: Backend computes H3 hexes
**Issue**: Frontend doesn't show hex info
**Impact**: Users can't see their work area hexes
**Fix**: Add hex display in profile/settings

### 9. **OFFLINE QUEUE STATUS - PARTIAL**
**Location**: Implemented in provider
**Issue**: Not fully wired to UI in all places
**Impact**: Status indicators might not show everywhere
**Fix**: Verify all claim/withdraw flows show status

---

## 🔧 INCOMPLETE IMPLEMENTATIONS

### 10. **NOTIFICATION HANDLING**
**File**: `apps/mobile/lib/main.dart`
**Issue**: FCM notifications not fully handled
**Impact**: Push notifications may not work correctly
**Fix**: Add notification routing logic

### 11. **BACKGROUND SYNC - NOT IMPLEMENTED**
**Status**: Task failed multiple times
**Issue**: No WorkManager implementation
**Impact**: App must be open to sync
**Fix**: Implement background sync service

### 12. **LOCATION UPDATE FLOW**
**File**: `apps/mobile/lib/core/services/location_service.dart`
**Issue**: Updates location but doesn't sync to backend properly
**Impact**: Location might be stale
**Fix**: Ensure location syncs to Convex

---

## 🎨 UI/UX GAPS

### 13. **LOADING STATES**
**Issue**: Many screens lack proper loading skeletons
**Impact**: Users see empty states while loading
**Fix**: Add shimmer loading states

### 14. **ERROR BOUNDARIES**
**Issue**: No error boundaries for crash recovery
**Impact**: App crashes completely on errors
**Fix**: Add ErrorBoundary widgets

### 15. **EMPTY STATES**
**Issue**: Some lists don't have empty state designs
**Impact**: Users don't know what to do when no data
**Fix**: Add empty state illustrations

---

## 🔒 SECURITY ISSUES

### 16. **ADMIN CHECKS - PARTIALLY FIXED**
**Status**: Added to verifications.ts
**Issue**: Need to verify all admin functions have checks
**Impact**: Potential unauthorized access
**Fix**: Audit all mutations for admin checks

### 17. **RATE LIMITING - NOT IMPLEMENTED**
**Issue**: No rate limiting on client side
**Impact**: Users can spam operations
**Fix**: Add rate limiting UI feedback

---

## 📊 SCHEMA MISMATCHES

### 18. **MISSING INDEXES**
**Check**: Some queries might not have proper indexes
**Impact**: Slow queries
**Fix**: Verify all queries use indexes

### 19. **UNUSED FIELDS**
**Check**: Some schema fields not used in code
**Impact**: Database bloat
**Fix**: Remove unused fields

---

## 🎯 PRIORITY FIX ORDER

### 🔴 **CRITICAL (Ship Blockers)**
1. ✅ **Storage functions** - Certificate upload broken
2. ✅ **Studio jobs provider** - Studios can't see jobs
3. ✅ **Claims provider** - Can't manage claims

### 🟡 **HIGH (Major Features)**
4. ⚠️ **Ratings system** - No reputation
5. ⚠️ **Admin panel** - Can't review certs
6. ⚠️ **Background sync** - App must stay open

### 🟢 **MEDIUM (Polish)**
7. Backup queue UI
8. H3 hex display
9. Loading states
10. Error boundaries

### 🔵 **LOW (Nice to have)**
11. Payments
12. Empty states
13. Rate limiting UI

---

## ✅ COMPLETED FEATURES

These ARE working:
- ✅ User auth (Firebase + Convex)
- ✅ Onboarding (both roles)
- ✅ H3 hex matching (backend)
- ✅ Job posting (basic)
- ✅ Job listing for instructors
- ✅ Real-time subscriptions
- ✅ Push notification setup
- ✅ Basic offline queue
- ✅ Optimistic UI
- ✅ Color themes (studio purple, instructor blue)
- ✅ Static maps (OpenStreetMap)
- ✅ Admin security checks

---

## 🚀 RECOMMENDATION

**Current State**: Beta-ready with limitations
**Can Ship?**: YES, but with reduced feature set
**What's Working**: Core matching, job posting, claiming
**What's Broken**: Certificate upload, studio job view, ratings

**Next Steps**:
1. Fix storage.ts (1 hour)
2. Create studio jobs provider (2 hours)
3. Create claims provider (2 hours)
4. Test end-to-end
5. Deploy beta

**Missing for v1.0**: Ratings, admin panel, payments
