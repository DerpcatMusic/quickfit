# QuickFit Architectural Decisions

## Technology Choices

### Why Convex?
- Built-in real-time subscriptions
- Native geospatial support
- Type-safe API (TypeScript)
- No server deployment needed
- Good for MVP speed
**Tradeoffs**: Vendor lock-in, potential scaling limits

### Why Flutter?
- Cross-platform (iOS + Android)
- Good performance
- Rich UI components
- Large ecosystem
**Tradeoffs**: Larger bundle, less native feel

### Why Haversine Distance?
- Sufficient accuracy for Israel
- No external dependencies
- Simple to implement
**Tradeoffs**: Does not account for Earth ellipsoid, slower than quadtree

## Data Model Decisions

### Status-Based Job Workflow
**Decision**: State machine (open -> claimed -> confirmed -> completed)
**Rationale**: Clear, easy to reason about, prevents invalid states
**Tradeoffs**: Less flexible, more code for transitions

### Two Location Fields
**Decision**: Home location (permanent) + current location (GPS)
**Rationale**: Reliable fallback + active tracking
**Tradeoffs**: More complex logic, potential confusion

### Separate Claims Table
**Decision**: Claims stored separately from jobs
**Rationale**: One-to-many relationship, track history
**Tradeoffs**: Extra join required

## Business Logic Decisions

### First-Come-First-Served
**Decision**: First to claim wins (no bidding)
**Rationale**: Simple, fast matching, clear expectations
**Tradeoffs**: No price optimization, no reputation prioritization

### SOS Boost (15 0.000000or < 3 hours)
**Decision**: Automatic rate increase for urgent jobs
**Rationale**: Encourages last-minute fills, fair compensation
**Tradeoffs**: Fixed percentage, could be abused

### Radius-Based Matching (5km default)
**Decision**: Instructors set personal radius
**Rationale**: User control, simple mental model
**Tradeoffs**: Does not account for traffic/travel time

### Verification Requirements
**Decision**: Jobs can require verification
**Rationale**: Trust and safety, quality control
**Tradeoffs**: Fewer matches for new instructors

## UI/UX Decisions

### Real-Time Job Feed
**Decision**: Live updates via Convex subscriptions
**Rationale**: Immediate feedback, competitive feel
**Tradeoffs**: Requires stable connection, no offline support

### SOS Job Priority
**Decision**: Show SOS jobs first in separate section
**Rationale**: Urgent jobs need attention, higher pay
**Tradeoffs**: Clutters UI, biases toward urgent

### Swipe-to-Claim
**Decision**: One-tap claim on job cards
**Rationale**: Fast action, mobile-optimized
**Tradeoffs**: Easy to accidentally claim

## Notification Decisions

### Push Notifications (FCM)
**Decision**: Firebase Cloud Messaging
**Rationale**: Cross-platform, Flutter integration
**Tradeoffs**: Setup complexity, not fully implemented

### Notify All Matching Instructors
**Decision**: Send to all matching, not just closest
**Rationale**: Fair chance, studios want options
**Tradeoffs**: More notifications, potential spam

## Future Considerations

### Payment/Escrow
Recommendation: Start with escrow for trust

### Skill-Based Matching
Recommendation: Implement skill certification first

### Fraud Detection
Recommendation: Start with photo verification

### Calendar Integration
Recommendation: Read-only sync first
