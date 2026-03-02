# Quikfit: Technical Deep Dive & Corrections
## Authentication, Spatial Indexing & Pricing Analysis

**Document Version:** 2.2 - UPDATED  
**Date:** February 9, 2026  
**Focus:** Critical technical systems + pricing corrections

---

## Part 1: Critical Pricing Corrections

### 1.1 Gemini 2.0 Flash Pricing (CORRECTED)

**My Error:** I cited outdated/wrong Gemini pricing.

**ACTUAL 2026 Pricing (Gemini 2.5 Flash - current production model):**

```
Gemini 2.5 Flash (Production, Feb 2026):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input:   $0.30 per 1M tokens
Output:  $2.50 per 1M tokens (text)
Images:  ~560 tokens per image = $0.00017 per image input

For certificate verification:
- Each certificate image: ~560 tokens input
- AI analysis response: ~500 tokens output
- Cost per verification: ~$0.0014 (0.14 cents)

Monthly cost for 500 verifications:
500 × $0.0014 = $0.70 (NOT $10 as I stated)
```

**IMPORTANT NOTE:** Gemini 2.0 Flash is being deprecated March 31, 2026. The current production model is **Gemini 2.5 Flash** which is what you should use.

**Corrected Implementation Cost:**

```javascript
// Certificate verification cost calculation (CORRECTED)
export const estimateVerificationCost = () => {
  const IMAGE_TOKENS = 560;        // Per certificate image
  const RESPONSE_TOKENS = 500;     // Average AI response
  const INPUT_COST_PER_M = 0.30;   // $0.30 per 1M tokens
  const OUTPUT_COST_PER_M = 2.50;  // $2.50 per 1M tokens
  
  const inputCost = (IMAGE_TOKENS / 1_000_000) * INPUT_COST_PER_M;
  const outputCost = (RESPONSE_TOKENS / 1_000_000) * OUTPUT_COST_PER_M;
  const totalPerCert = inputCost + outputCost;
  
  // Total: ~$0.0014 per certificate (0.14 cents)
  
  return {
    perCertificate: totalPerCert,
    per100: totalPerCert * 100,      // $0.14
    per500: totalPerCert * 500,      // $0.70
    per1000: totalPerCert * 1000,    // $1.40
  };
};
```

### 1.2 Pilates Instructor Rates (CORRECTED)

**My Error:** Stated ₪250 average, but you correctly noted ₪120 is the MINIMUM now.

**ACTUAL Israeli Market Rates (2026):**

Based on salary data: ₪56-66/hour is the AVERAGE salaried rate, but freelance/substitute rates are different:

```
Israeli Pilates Instructor Market Rates (2026):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Minimum (entry level):        ₪120 per class
Average (2-5 years exp):      ₪180-220 per class
Premium (5+ years/studio):    ₪250-350 per class
Elite (celebrity/boutique):   ₪400+ per class

Typical substitute request:   ₪150-200 per class
```

**Corrected Revenue Model:**

```javascript
// CORRECTED: Israeli market pricing
export const RevenueCalculation = {
  // Conservative estimates with ₪120 minimum
  RATES: {
    min: 120,      // Entry level
    avg: 180,      // Realistic average for subs
    premium: 250,  // Experienced instructors
  },
  
  PLATFORM_FEE: 0.15,  // 15% commission
  
  // Year 1 projections (corrected)
  calculateRevenue: (jobsPerMonth, avgRate = 180) => {
    const grossPerJob = avgRate;
    const platformFeePerJob = grossPerJob * 0.15;  // ₪27 per job at ₪180 rate
    
    const monthlyRevenue = jobsPerMonth * platformFeePerJob;
    const annualRevenue = monthlyRevenue * 12;
    
    return {
      jobsPerMonth,
      avgRate,
      platformFeePerJob,
      monthlyRevenue,
      annualRevenue,
      annualRevenueUSD: annualRevenue / 3.3,  // ~$1 = ₪3.3
    };
  },
};

// Example calculations:
// 100 jobs/month × ₪180 avg × 15% = ₪2,700/month = ₪32,400/year (~$9,800 USD)
// 500 jobs/month × ₪180 avg × 15% = ₪13,500/month = ₪162,000/year (~$49,000 USD)
// 1000 jobs/month × ₪180 avg × 15% = ₪27,000/month = ₪324,000/year (~$98,000 USD)
```

**Corrected Cost Structure:**

```
Monthly Infrastructure Costs (CORRECTED):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Service              Tier/Usage           Cost
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Convex               Pro Plan             $25
Firebase (FCM)       Free (unlimited)     $0
Gemini 2.5 Flash     500 certs/month      $0.70 (NOT $10!)
S3 Storage           10GB                 $1
Payment Rails        2.5% + ₪1 per tx     Variable
Total Fixed:                              ~$27/month

At 100 jobs/month (₪180 avg rate):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Revenue: ₪2,700 (~$818)
Payment Processing (2.5%): ₪450 (~$136)
Fixed Costs: $27
Total Costs: ~$163
Gross Profit: $655
Gross Margin: 80%

At 1000 jobs/month (₪180 avg rate):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Revenue: ₪27,000 (~$8,180)
Payment Processing (2.5%): ₪4,500 (~$1,364)
Fixed Costs: $99 (Convex Scale Plan)
Total Costs: ~$1,463
Gross Profit: $6,717
Gross Margin: 82%
```

---

## Part 2: Authentication Deep Dive

### 2.1 Why Passkeys? (The Modern Standard)

**Background:** Traditional authentication (username/password) has fundamental problems:
- Users reuse passwords → one breach compromises multiple accounts
- Phishing attacks work because users enter passwords on fake sites
- Password resets create support burden
- SMS 2FA is vulnerable to SIM swapping

**Passkeys solve ALL of these:**

```
Traditional Auth Problems → Passkey Solutions:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Password reuse         → Unique keypair per account
Phishing               → Cryptographic proof (can't be faked)
Password reset         → Biometric recovery
SMS 2FA vulnerabilities → Device-based cryptography
User friction          → Face/Touch ID (instant)
```

### 2.2 How Passkeys Work (Technical Explanation)

**The Cryptographic Flow:**

```
Registration (First Time):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. User initiates signup in Quikfit app
   ↓
2. App calls WebAuthn API: navigator.credentials.create()
   ↓
3. Device generates NEW keypair for Quikfit:
   - Private key: Stored in device's secure enclave (never leaves device)
   - Public key: Sent to Quikfit server
   ↓
4. User authenticates with biometric (Face ID / Touch ID)
   ↓
5. Server stores:
   {
     userId: "user_123",
     publicKey: "MFkwEwYHKoZI...",  // Can verify signatures
     credentialId: "cred_456",
     deviceInfo: "iPhone 15 Pro"
   }

Login (Every Time):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. User opens Quikfit app → taps "Login"
   ↓
2. App calls: navigator.credentials.get()
   ↓
3. Server sends challenge: "Sign this random nonce: abc123xyz"
   ↓
4. User authenticates with biometric
   ↓
5. Device's secure enclave signs challenge with private key
   ↓
6. Signed response sent to server
   ↓
7. Server verifies signature using stored public key
   ↓
8. If valid → User authenticated ✅

KEY INSIGHT: Private key NEVER leaves the device.
Server can't be hacked for passwords because it doesn't have them!
```

**What Makes This Phishing-Proof:**

```
Phishing Attack Scenario:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Traditional (VULNERABLE):
1. Attacker creates fake "quikfit-login.com"
2. User enters username/password
3. Attacker steals credentials ❌
4. Attacker logs into real Quikfit ❌

Passkey (IMMUNE):
1. Attacker creates fake "quikfit-login.com"
2. User attempts biometric login
3. WebAuthn checks domain: "quikfit-login.com" ≠ "quikfit.app"
4. Signature tied to WRONG domain
5. Real Quikfit server rejects signature ✅
6. Attack fails ✅

The cryptographic signature includes the domain name!
Can't be used on a different site.
```

### 2.3 Convex Auth + Passkeys Implementation

**Why NOT Clerk (Your Original Plan):**

```
Clerk Issues:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Flutter SDK still in beta (March 2025 release)
   → Risk of breaking changes
   
2. Additional network hop on hot path:
   Flutter → Clerk → Convex
   (Adds ~50-100ms latency)
   
3. Cost: $0.02 per MAU after free tier
   (1000 users = $20/month)
   
4. Vendor lock-in for auth system
```

**Better Approach: Convex Auth + Native Passkeys:**

```
Architecture:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Flutter App
    ↓
[passkeys package] → Device Secure Enclave
    ↓
Convex Auth (built-in)
    ↓
Convex Database

Direct path: Flutter → Convex (one hop)
Zero additional cost (included in Convex)
Full control over auth flow
```

**Implementation Code:**

```dart
// Flutter side (using passkeys package)
import 'package:passkeys/passkeys.dart';
import 'package:convex/convex.dart';

class PasskeyAuthService {
  final ConvexClient _convex;
  final Passkey _passkey = Passkey();
  
  PasskeyAuthService(this._convex);
  
  // Registration
  Future<void> registerWithPasskey({
    required String email,
    required String displayName,
  }) async {
    // 1. Request challenge from Convex
    final challenge = await _convex.mutation(
      'auth:createRegistrationChallenge',
      {'email': email},
    );
    
    // 2. Create passkey credential
    final credential = await _passkey.register(
      RegisterRequestType(
        challenge: challenge['challenge'],
        relyingParty: RelyingPartyType(
          id: 'quikfit.app',           // Your domain
          name: 'Quikfit',
        ),
        user: UserType(
          id: challenge['userId'],     // From Convex
          name: email,
          displayName: displayName,
        ),
        authenticatorSelection: AuthenticatorSelectionType(
          userVerification: UserVerificationRequirement.required,
          authenticatorAttachment: AuthenticatorAttachment.platform,
        ),
        attestation: AttestationConveyancePreference.none,
      ),
    );
    
    // 3. Complete registration in Convex
    await _convex.mutation(
      'auth:completeRegistration',
      {
        'userId': challenge['userId'],
        'credentialId': credential.id,
        'publicKey': credential.response.publicKey,
        'authenticatorData': credential.response.authenticatorData,
      },
    );
  }
  
  // Login
  Future<String> loginWithPasskey() async {
    // 1. Request challenge
    final challenge = await _convex.action(
      'auth:createLoginChallenge',
      {},
    );
    
    // 2. Get assertion from device
    final assertion = await _passkey.authenticate(
      AuthenticateRequestType(
        challenge: challenge['challenge'],
        relyingPartyId: 'quikfit.app',
        allowCredentials: challenge['allowedCredentials']
          .map((c) => PublicKeyCredentialDescriptorType(
            id: c['id'],
            type: PublicKeyCredentialType.publicKey,
          ))
          .toList(),
        userVerification: UserVerificationRequirement.required,
      ),
    );
    
    // 3. Verify and get session token
    final session = await _convex.mutation(
      'auth:verifyLogin',
      {
        'credentialId': assertion.id,
        'signature': assertion.response.signature,
        'authenticatorData': assertion.response.authenticatorData,
        'clientDataJSON': assertion.response.clientDataJSON,
      },
    );
    
    return session['token'];
  }
}
```

```typescript
// Convex side (convex/auth.ts)
import { v } from "convex/values";
import { mutation, action } from "./_generated/server";
import { verifyAuthenticationResponse, verifyRegistrationResponse } from "@simplewebauthn/server";

// Storage schema
export const users = defineTable({
  email: v.string(),
  displayName: v.string(),
  role: v.union(v.literal("instructor"), v.literal("studio")),
  createdAt: v.number(),
})
  .index("by_email", ["email"]);

export const credentials = defineTable({
  userId: v.id("users"),
  credentialId: v.string(),
  publicKey: v.bytes(),           // The public key for verification
  counter: v.number(),             // Signature counter (prevents replay)
  deviceType: v.string(),
  createdAt: v.number(),
})
  .index("by_credential_id", ["credentialId"])
  .index("by_user", ["userId"]);

// Registration flow
export const createRegistrationChallenge = mutation({
  args: { email: v.string() },
  handler: async (ctx, { email }) => {
    // Generate random challenge (must be cryptographically secure)
    const challenge = crypto.randomBytes(32).toString("base64url");
    
    // Create pending user
    const userId = await ctx.db.insert("users", {
      email,
      displayName: "",  // Will be updated on completion
      role: "instructor",  // Default, can be changed
      createdAt: Date.now(),
    });
    
    // Store challenge temporarily (auto-expires after 5 minutes)
    await ctx.db.insert("pending_challenges", {
      userId,
      challenge,
      type: "registration",
      expiresAt: Date.now() + 5 * 60 * 1000,
    });
    
    return { challenge, userId };
  },
});

export const completeRegistration = mutation({
  args: {
    userId: v.id("users"),
    credentialId: v.string(),
    publicKey: v.bytes(),
    authenticatorData: v.bytes(),
    // ... other WebAuthn response fields
  },
  handler: async (ctx, args) => {
    // Retrieve challenge
    const pending = await ctx.db
      .query("pending_challenges")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .first();
    
    if (!pending || pending.expiresAt < Date.now()) {
      throw new Error("Challenge expired or not found");
    }
    
    // Verify the registration response
    const verification = await verifyRegistrationResponse({
      response: {
        id: args.credentialId,
        rawId: Buffer.from(args.credentialId, "base64url"),
        response: {
          attestationObject: args.authenticatorData,
          clientDataJSON: args.clientDataJSON,
        },
        type: "public-key",
      },
      expectedChallenge: pending.challenge,
      expectedOrigin: "https://quikfit.app",  // Your domain
      expectedRPID: "quikfit.app",
    });
    
    if (!verification.verified) {
      throw new Error("Verification failed");
    }
    
    // Store credential
    await ctx.db.insert("credentials", {
      userId: args.userId,
      credentialId: args.credentialId,
      publicKey: verification.registrationInfo.credentialPublicKey,
      counter: verification.registrationInfo.counter,
      deviceType: verification.registrationInfo.credentialDeviceType,
      createdAt: Date.now(),
    });
    
    // Clean up pending challenge
    await ctx.db.delete(pending._id);
    
    return { success: true };
  },
});

// Login flow
export const createLoginChallenge = action({
  args: {},
  handler: async (ctx) => {
    const challenge = crypto.randomBytes(32).toString("base64url");
    
    // Get all registered credentials (user hasn't identified yet)
    const credentials = await ctx.runQuery(internal.auth.getAllCredentials);
    
    // Store challenge
    await ctx.runMutation(internal.auth.storePendingLogin, {
      challenge,
      expiresAt: Date.now() + 5 * 60 * 1000,
    });
    
    return {
      challenge,
      allowedCredentials: credentials.map(c => ({ id: c.credentialId })),
    };
  },
});

export const verifyLogin = mutation({
  args: {
    credentialId: v.string(),
    signature: v.bytes(),
    authenticatorData: v.bytes(),
    clientDataJSON: v.bytes(),
  },
  handler: async (ctx, args) => {
    // Find credential
    const credential = await ctx.db
      .query("credentials")
      .withIndex("by_credential_id", (q) => 
        q.eq("credentialId", args.credentialId)
      )
      .first();
    
    if (!credential) {
      throw new Error("Credential not found");
    }
    
    // Get pending challenge
    const pending = await ctx.db
      .query("pending_challenges")
      .withIndex("by_type", (q) => q.eq("type", "login"))
      .order("desc")
      .first();
    
    if (!pending) {
      throw new Error("No pending challenge");
    }
    
    // Verify the assertion
    const verification = await verifyAuthenticationResponse({
      response: {
        id: args.credentialId,
        rawId: Buffer.from(args.credentialId, "base64url"),
        response: {
          authenticatorData: args.authenticatorData,
          clientDataJSON: args.clientDataJSON,
          signature: args.signature,
        },
        type: "public-key",
      },
      expectedChallenge: pending.challenge,
      expectedOrigin: "https://quikfit.app",
      expectedRPID: "quikfit.app",
      authenticator: {
        credentialID: Buffer.from(credential.credentialId, "base64url"),
        credentialPublicKey: credential.publicKey,
        counter: credential.counter,
      },
    });
    
    if (!verification.verified) {
      throw new Error("Authentication failed");
    }
    
    // Update counter (prevents replay attacks)
    await ctx.db.patch(credential._id, {
      counter: verification.authenticationInfo.newCounter,
    });
    
    // Create session token (use Convex Auth's built-in session handling)
    const sessionToken = await ctx.auth.createSession({
      userId: credential.userId,
    });
    
    return { token: sessionToken, userId: credential.userId };
  },
});
```

**Key Security Features:**

```
1. Challenge-Response Protocol:
   - Server generates random challenge
   - Device signs it with private key
   - Server verifies signature
   - Challenge is single-use (prevents replay)

2. Counter-based Replay Protection:
   - Each credential has a counter
   - Counter increments with each use
   - Server checks: newCounter > oldCounter
   - If counter decreases → cloned authenticator detected

3. Origin Binding:
   - Signature includes domain name
   - Can't be used on different site
   - Prevents phishing

4. Device Attestation (Optional):
   - Can verify device is genuine Apple/Android hardware
   - Useful for high-security requirements
```

### 2.4 Social Login (Google/Apple) for Fast Onboarding

Passkeys should be the **primary long-term auth** (fast, phishing-resistant),
but for growth you should **also support Google + Apple sign-in**.
This makes signup feel instant and reduces drop-off.

**Recommended Hybrid Approach:**

```
User picks:
- Continue with Google
- Continue with Apple
- Continue with Passkey
- Continue with Email

All methods map to the same Convex user record.
If a user starts with Google/Apple, allow them to add a passkey later.
```

**Implementation Notes:**
- Use **Firebase Auth** for Google/Apple (fast, proven UX).
- Store the Firebase UID in your Convex user record.
- Allow account linking (Google/Apple -> passkey) after onboarding.
- Keep Firebase only for auth + FCM; Convex remains your source of truth.

---

## Part 3: Geospatial Indexing (Spatial Index)

### 3.0 Dispatch Requirements (Updated Feb 9, 2026)

- Instructor radius only (studios have no radius).
- Max radius: 15km.
- High accuracy and low latency for last-minute jobs.
- Prefer on-the-fly spatial queries over heavy precomputation.

### 3.1 Why a Spatial Index

A spatial index (R-tree / S2 / similar) organizes points by location so queries avoid scanning all instructors.
Instead of checking every user, a query first prunes by bounding boxes, then runs an exact distance check.
This is the industry-standard approach for point-within-radius queries.

### 3.2 Data Model (Canonical)

```
users:
- latitude, longitude
- radiusKm
- categories[]
- isVerified
- notificationsEnabled

jobs:
- latitude, longitude
- category
- status
- requiresVerification
```

### 3.3 Core Algorithm (Convex Geospatial)

Use the Convex geospatial component as the primary index for instructors.
The index supports nearest queries with an optional max distance in meters and filtering.

```typescript
// Convex geospatial index
const instructorGeo = new GeospatialIndex(components.geospatial);

// On instructor location/radius update
await instructorGeo.insert(
  ctx,
  instructorId,
  { latitude, longitude },
  {
    category: primaryCategory,
    verified: isVerified,
    notificationsEnabled: true,
  },
  radiusKm * 1000
);

// On job post (dispatch)
const result = await instructorGeo.nearest(ctx, {
  point: { latitude: jobLat, longitude: jobLng },
  limit: 500,
  maxDistance: 15000, // 15km cap
  filter: (q) =>
    q.eq("category", jobCategory).eq("notificationsEnabled", true),
});

// Final eligibility check using each instructor's own radius
const eligible = [];
for (const row of result) {
  const instructor = await ctx.db.get(row.key);
  if (!instructor) continue;
  const distanceKm = haversineDistanceKm(
    instructor.latitude,
    instructor.longitude,
    jobLat,
    jobLng
  );
  if (distanceKm <= (instructor.radiusKm ?? 15)) {
    eligible.push(instructor);
  }
}
```

Notes:
- `nearest` supports a max distance in meters and indexed filters, which keeps queries fast.
- This is accurate enough for last-minute dispatch and avoids precomputing huge coverage sets.

### 3.4 Fairness & Latency (Dispatch Policy)

To avoid "fastest device wins":

Option A: Claim Window (fair)
- Notify all eligible instructors.
- Accept claims for 15-30 seconds.
- Server picks a winner by distance, rating, or random.

Option B: Wave Dispatch (fast + fair-ish)
- Wave 1: Top 50-100 closest.
- If no claim, wave 2: next 50-100.

### 3.5 Accuracy Notes

Spatial indexes use bounding boxes to prune candidates and then apply exact distance checks.
In spatial databases (e.g., PostGIS), `ST_DWithin` uses indexes for bounding box pruning and
geodesic distance for accuracy on the spheroid. This is the same pattern we rely on here.

---

## Part 4: Additional Potential Flaws Found

### 4.1 Race Condition in Job Expiry

**Flaw:**

```typescript
// Original expiry logic
export const expireStaleJobs = internalMutation({
  handler: async (ctx) => {
    const staleLocked = await ctx.db
      .query("subs")
      .withIndex("by_status", (q) => q.eq("status", "locked"))
      .filter((q) => q.lt(q.field("lockedAt"), Date.now() - TIMEOUT))
      .collect();
    
    for (const job of staleLocked) {
      await ctx.db.patch(job._id, { status: "open" });  // ❌ RACE CONDITION!
      // What if instructor confirms BETWEEN query and patch?
    }
  },
});
```

**Problem:** Time-of-check vs time-of-use (TOCTOU)

```
Timeline:
0:00 - Job locked by instructor A
2:00 - Expiry cron runs, queries stale jobs (finds this job)
2:00.5 - Instructor A confirms job
2:00.6 - Expiry cron patches job back to "open" (WRONG!)
```

**Fix: Atomic Compare-And-Swap**

```typescript
export const expireStaleJobs = internalMutation({
  handler: async (ctx) => {
    const LOCK_TIMEOUT = 2 * 60 * 1000;
    const now = Date.now();
    
    const staleLocked = await ctx.db
      .query("subs")
      .withIndex("by_status", (q) => q.eq("status", "locked"))
      .filter((q) => q.lt(q.field("lockedAt"), now - LOCK_TIMEOUT))
      .collect();
    
    for (const job of staleLocked) {
      // Re-fetch to get latest state
      const current = await ctx.db.get(job._id);
      
      // Only expire if STILL locked (atomic check)
      if (
        current.status === "locked" &&
        current.lockedAt < now - LOCK_TIMEOUT
      ) {
        await ctx.db.patch(job._id, {
          status: "open",
          instructorId: undefined,
          lockedAt: undefined,
          expiredCount: (current.expiredCount || 0) + 1,
        });
      }
      // Else: instructor confirmed in the meantime, skip
    }
  },
});
```

### 4.2 Payment Escrow Window

**Flaw:** Original docs show instant instructor payout.

**Problem:**

```
Timeline:
0:00 - Job completed
0:01 - Instructor paid out
1:00 - Studio disputes: "Instructor didn't show up!"
      → Money already gone, can't reverse ❌
```

**Fix: Escrow Period**

```typescript
export const PaymentTimeline = {
  JOB_COMPLETED: "Instructor completes job",
  FUNDS_HELD: "Platform holds payment for 24-48 hours",
  DISPUTE_WINDOW: "Studio can dispute during this period",
  AUTO_RELEASE: "If no dispute, auto-pay instructor",
  DISPUTE_FREEZE: "If dispute, freeze funds pending resolution",
};

export const processPayoutIfEligible = mutation({
  args: { jobId: v.id("subs") },
  handler: async (ctx, { jobId }) => {
    const job = await ctx.db.get(jobId);
    const payment = await ctx.db
      .query("payments")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .first();
    
    // Check eligibility
    const ESCROW_PERIOD = 24 * 60 * 60 * 1000;  // 24 hours
    const eligibleAt = job.completedAt + ESCROW_PERIOD;
    
    if (Date.now() < eligibleAt) {
      throw new Error(`Payout not eligible until ${new Date(eligibleAt)}`);
    }
    
    // Check for disputes
    const dispute = await ctx.db
      .query("disputes")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .first();
    
    if (dispute) {
      throw new Error("Payout frozen due to dispute");
    }
    
    // Process payout
    await processInstructorPayout(ctx, payment);
  },
});
```

### 4.3 Notification Delivery Guarantee

**Flaw:** Original design assumes FCM always works.

**Problem:**

```
Failure Scenarios:
1. Device offline → FCM queues message (OK, handled by Google)
2. App uninstalled → FCM fails silently ❌
3. Token expired → FCM returns error ❌
4. Rate limit exceeded → FCM rejects ❌
```

**Fix: Multi-Channel Fallback**

```typescript
export const sendCriticalNotification = action({
  args: {
    userId: v.id("users"),
    jobId: v.id("subs"),
    priority: v.union(v.literal("CRITICAL"), v.literal("HIGH")),
  },
  handler: async (ctx, args) => {
    const user = await ctx.runQuery(internal.users.get, { id: args.userId });
    
    // 1. Try FCM (primary)
    let fcmSuccess = false;
    try {
      await sendFCM({
        token: user.fcmToken,
        notification: { ... },
        android: { priority: "high" },
        apns: { headers: { "apns-priority": "10" } },
      });
      fcmSuccess = true;
    } catch (error) {
      console.error("FCM failed:", error);
      
      // Update token if invalid
      if (error.code === "messaging/invalid-registration-token") {
        await ctx.runMutation(internal.users.update, {
          id: args.userId,
          fcmToken: null,  // Force user to re-register
        });
      }
    }
    
    // 2. Fallback: In-app notification (always store)
    await ctx.runMutation(internal.notifications.storeInApp, {
      userId: args.userId,
      jobId: args.jobId,
      type: "job_available",
      createdAt: Date.now(),
      read: false,
    });
    
    // 3. Critical only: SMS fallback
    if (!fcmSuccess && args.priority === "CRITICAL") {
      await sendSMS({
        to: user.phoneNumber,
        message: `Urgent Quikfit job available! Open app to view.`,
      });
    }
    
    // 4. Log delivery attempt
    await ctx.runMutation(internal.analytics.logNotification, {
      userId: args.userId,
      jobId: args.jobId,
      channel: fcmSuccess ? "FCM" : "SMS",
      success: true,
    });
  },
});
```

---

## Summary of Technical Deep Dives

### Authentication (Passkeys + Convex Auth)

**What We Learned:**
- Passkeys use public-key cryptography (private key never leaves device)
- Challenge-response protocol prevents phishing
- Counter-based replay protection
- Domain binding in signatures
- Convex Auth integrates seamlessly (no extra network hop)

**Key Takeaway:** Use Convex Auth + native passkeys instead of Clerk for better performance, lower cost, and tighter integration.

### Spatial Indexing

**What We Learned:**
- Spatial indexes avoid scanning all instructors
- Queries prune by bounding boxes, then confirm by distance
- Instructor radius is enforced server-side
- Fast enough for last-minute dispatch at scale

**Key Takeaway:** Use the geospatial index for dispatch and enforce instructor radius with an exact distance check.

### Critical Flaws Fixed

1. Job expiry race condition → Atomic compare-and-swap
2. Payment escrow missing → 24-hour hold period
3. Notification single point of failure → Multi-channel fallback
4. Pricing errors corrected (Gemini, instructor rates)

### Corrected Economics

```
Year 1 Realistic Projections:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Avg job rate: ₪180 (not ₪250)
Platform fee: 15%
Revenue per job: ₪27

Month 1: 100 jobs → ₪2,700 revenue (~$818)
Month 6: 500 jobs → ₪13,500 revenue (~$4,090)
Month 12: 1000 jobs → ₪27,000 revenue (~$8,180)

Infrastructure costs: $27-99/month
Gross margin: 80-82%
```

---

**Next Steps:**
1. Review this corrected technical architecture
2. Validate pricing assumptions with real Israeli studios
3. Prototype passkey auth flow
4. Implement geospatial dispatch with strict radius checks and fairness policy
5. Implement atomic job state machine
