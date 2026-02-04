# Flutter Offline-First & Real-Time Patterns Research - 2026
## 1. OFFLINE STORAGE SOLUTIONS

### 1.1 Hive (Recommended for QuickFit)
**Best For**: Key-value storage, user preferences, cached data
- **Source**: https://github.com/hivedb/hive
- **Performance**: Blazing fast, outperforms SQLite on writes/deletes
- **Features**: 
  - No native dependencies (pure Dart)
  - AES-256 encryption built-in
  - Cross-platform (mobile, desktop, web)
  - Type-safe with generated adapters

**Evidence** ([source](https://pub.dev/packages/hive)):
Hive provides a simple key-value API:
```dart
await Hive.initFlutter();
var box = await Hive.openBox('myBox');
box.put('name', 'David');
var name = box.get('name');
```

**QuickFit Use Case**: Store workout plans, user settings, cached fitness data locally.

### 1.2 Drift (formerly Moor)
**Best For**: Complex relational data, queries, transactions
- **Source**: https://github.com/simolus3/drift
- **Performance**: Reactive streams, built on SQLite
- **Features**:
  - Type-safe SQL & Dart queries
  - Built-in migrations support
  - Transactions, joins, complex filters
  - Auto-updating streams from queries

**Evidence** ([source](https://pub.dev/packages/drift)):
Drift provides reactive queries:
```dart
final users = select(users).watch();
// Returns a Stream that auto-updates when data changes
```

**QuickFit Use Case**: If you need complex queries (e.g., find all workouts by date range with tags).

### 1.3 Comparison Summary

| Feature | Hive | Drift | SQLite | ObjectBox |
|----------|-------|--------|---------|-----------|
| Performance | Fastest | Good | Medium | Fast |
| Native Deps | None | SQLite | Native | Native |
| Type Safety | Yes | Yes | Manual | Codegen |
| Offline Sync | Manual | Manual | Manual | Partial |
| Encryption | Built-in | Manual | Manual | Built-in |
| Best For | Key-value | Relational | Simple data | High perf |

**Recommendation for QuickFit**: **Hive** for simplicity and speed. Use **Drift** if you need complex queries.

## 2. BACKGROUND SYNC PATTERNS

### 2.1 flutter_background_service (Best for True Background)
**Best For**: Continuous background execution, real-time socket connections
- **Source**: https://github.com/ekasetiawans/flutter_background_service
- **Features**:
  - Execute Dart code even when app is closed
  - Android foreground service support
  - iOS background fetch (15-30 sec, min 15 min interval)
  - Isolate-based (no shared memory with UI)

**Evidence** ([source](https://pub.dev/packages/flutter_background_service)):
```dart
Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      autoStart: true,
      onStart: onStart,
      isForegroundMode: false,
      autoStartOnBoot: true,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  final socket = io.io("your-server-url", {'transports': ['websocket']});
  socket.on("new-booking", (data) {
    flutterLocalNotificationsPlugin.show(...);
  });
}
```

### 2.2 Bad Internet Sync Strategy

**Queue Pattern**:
1. Store actions in local queue (Hive)
2. Periodically attempt to sync when online
3. Use exponential backoff on failures
4. Deduplicate failed attempts

### 2.3 Connectivity Monitoring

**Source**: https://github.com/fluttercommunity/plus_plugins

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkMonitor {
  StreamSubscription<ConnectivityResult>? _subscription;

  void startMonitoring() {
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      switch (result) {
        case ConnectivityResult.wifi:
          processQueue(); // Sync when WiFi available
          break;
        case ConnectivityResult.mobile:
          // Optionally sync on mobile (may be metered)
          break;
        case ConnectivityResult.none:
          // Queue actions locally
          break;
      }
    });
  }
}
```

## 3. PUSH NOTIFICATIONS

### 3.1 Firebase Cloud Messaging (FCM)
**Best For**: Cross-platform push notifications
- **Source**: https://firebase.google.com/docs/cloud-messaging/flutter/client

**Setup Requirements**:
- iOS: Upload APNs key, enable Background Modes
- Android: Google Play Services, foreground service type for SDK 34+

**Evidence** ([source](https://firebase.google.com/docs/cloud-messaging/flutter/client)):
```dart
FirebaseMessaging messaging = FirebaseMessaging.instance;
String? token = await messaging.getToken();

FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // App in foreground
  showInAppNotification(message);
});

FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  // App opened from notification
  navigateToScreen(message);
});
```

### 3.2 flutter_local_notifications
**Best For**: Local notifications, scheduled notifications
- **Source**: https://github.com/MaikuB/flutter_local_notifications

**Evidence** ([source](https://github.com/MaikuB/flutter_local_notifications)):
```dart
final FlutterLocalNotificationsPlugin notifications = 
    FlutterLocalNotificationsPlugin();

await notifications.initialize(
  InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  ),
);

await notifications.show(
  123,
  'New Booking',
  'Client John booked a session',
  NotificationDetails(
    android: AndroidNotificationDetails('channel_id', 'Bookings'),
  ),
);
```

### 3.3 QuickFit Push Strategy
1. **FCM** for server-to-client push (new bookings, cancellations)
2. **Local notifications** for reminders (session starting in 15 min)
3. **Background service** to maintain WebSocket for real-time updates
4. **Offline fallback**: Show notification on app open when internet returns

## 4. LOCATION TRACKING OPTIMIZATION

### 4.1 Geolocator
**Source**: https://github.com/Baseflow/flutter-geolocator

**Features**:
- Accurate location (GPS, network, fused)
- Background location tracking
- Permission handling
- Distance filtering

**Evidence** ([source](https://github.com/Baseflow/flutter-geolocator)):
```dart
import 'package:geolocator/geolocator.dart';

class LocationTracker {
  StreamSubscription<Position>? _positionStream;

  Future<void> startTracking() async {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Only notify if moved 10 meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
      .listen((Position position) {
        handleLocationUpdate(position);
      });
  }
}
```

### 4.2 Battery Optimization Strategies

**1. Distance Filter**: Only notify when moved >10m
**2. Time Intervals**: Request location every 30-60 seconds instead of continuous
**3. Significant Location Changes**: iOS feature, minimal battery drain
**4. Activity Recognition**: Only track when user is active (walking/driving)

### 4.3 QuickFit Location Strategy
1. **Client app**: Track location only when session is active (during workout)
2. **Instructor app**: Background tracking when on duty
3. **Geofencing**: Use geofences for automatic check-in/out
4. **Battery savings**: Stop tracking when app is backgrounded for >5 minutes

## 5. REAL-TIME SYNC ARCHITECTURE

### 5.1 "Uber-like" Real-Time Pattern

**Architecture**:
Client (Flutter App)
├─ WebSocket (flutter_background_service)
│   └─ Background isolate
└─ Server (Node/Go)
    ├─ Firestore (data persistence)
    ├─ FCM (push notifications)
    └─ Redis (real-time pub/sub)

### 5.2 Dual-Channel Strategy

**Channel 1: WebSocket (Background Service)**
- Always connected (when possible)
- Real-time bidirectional updates
- Handles: Live session status, chat, location

**Channel 2: Firestore + FCM**
- Data persistence
- Push when WebSocket disconnected
- Handles: Booking confirmations, cancellations

**Evidence** ([source](https://pub.dev/packages/flutter_background_service)):
```dart
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  final socket = io.io(SERVER_URL, {'transports': ['websocket']});
  
  socket.on('session-update', (data) {
    Hive.box('sessions').put(data['id'], data);
    notifications.show(...);
  });

  socket.onDisconnect((_) {
    FirebaseMessaging.onMessage.listen((message) {
      handleFCMMessage(message);
    });
  });
}
```

### 5.3 Conflict Resolution

**Last-Write-Wins with Timestamps**:
```dart
class ConflictResolver {
  Future<void> resolve(Session local, Session remote) async {
    if (remote.updatedAt.isAfter(local.updatedAt)) {
      await Hive.box('sessions').put(remote.id, remote);
    } else {
      await api.updateSession(local);
    }
  }
}
```

### 5.4 Offline-First Data Flow

1. **Write**: Always write to local storage first (Hive/Drift)
2. **Queue**: Add sync operation to queue
3. **Process**: Background service processes queue when online
4. **Notify**: Update UI via streams (reactive)
5. **Conflict**: Resolve using timestamps or manual merge

## 6. BATTERY OPTIMIZATION CHECKLIST

### 6.1 Android
- **Disable battery optimization** for background service
- **Use WorkManager** for periodic tasks instead of continuous polling
- **Implement adaptive polling**: Less frequent when screen off
- **Use Doze mode exemptions**: Whitelist critical sync operations

### 6.2 iOS
- **Background Fetch**: Max 15-30 seconds, min 15 minutes
- **Silent Push**: Use push-to-sync instead of polling
- **Significant Location Changes**: Minimal battery drain
- **Avoid continuous timers**: iOS will terminate them

### 6.3 General
- **Batch network requests**: Combine multiple operations
- **Compress data**: Reduce payload size
- **Deduplicate**: Don't sync unchanged data
- **Background processing**: Use isolates for heavy computation

### 6.4 Adaptive Sync Example
```dart
class AdaptiveSync {
  Duration get syncInterval {
    if (isCharging) return Duration(minutes: 1);  // Fast
    if (onWiFi) return Duration(minutes: 5);   // Medium
    if (onMobile) return Duration(minutes: 15); // Slow
    return Duration(minutes: 30);  // Very slow
  }

  void startAdaptiveSync() {
    Timer.periodic(syncInterval, (_) {
      syncQueue.processQueue();
    });
  }
}
```

## 7. QUICKFIT RECOMMENDATIONS

### 7.1 Recommended Stack
1. **Storage**: Hive (for simplicity) or Drift (for complex queries)
2. **Background**: flutter_background_service
3. **Push**: Firebase FCM + flutter_local_notifications
4. **Location**: Geolocator with distance filtering
5. **Connectivity**: connectivity_plus
6. **Real-time**: WebSocket in background service + Firestore backup

### 7.2 Architecture for QuickFit

```
Client (Flutter App)
│
├─ Hive Box: 'sessions'
│   ├─ Key: session_id
│   └─ Value: Session data
│
├─ Hive Box: 'syncQueue'
│   └─ List: Pending operations
│
├─ Background Service
│   ├─ WebSocket: Always connected
│   ├─ Timer: Periodic sync (adaptive interval)
│   └─ Notifications: Local + FCM
│
└─ Connectivity Listener
    ├─ WiFi: Full sync
    ├─ Mobile: Throttled sync
    └─ None: Queue locally

Server
│
├─ Firestore: Data persistence
├─ FCM: Push notifications
└─ WebSocket: Real-time updates
```

### 7.3 Implementation Priority
1. **Phase 1**: Setup Hive + basic CRUD operations
2. **Phase 2**: Add connectivity_plus + sync queue
3. **Phase 3**: Implement background service with WebSocket
4. **Phase 4**: Add FCM + local notifications
5. **Phase 5**: Implement location tracking with battery optimization
6. **Phase 6**: Advanced features (conflict resolution, offline editing)

## 8. ADDITIONAL RESOURCES

### 8.1 Documentation Links
- **Hive**: https://docs.hivedb.dev/
- **Drift**: https://drift.simonbinder.eu/docs/
- **flutter_background_service**: https://pub.dev/packages/flutter_background_service
- **Firebase FCM**: https://firebase.google.com/docs/cloud-messaging/flutter/client
- **Geolocator**: https://pub.dev/packages/geolocator
- **connectivity_plus**: https://pub.dev/packages/connectivity_plus

### 8.2 Package Dependencies (pubspec.yaml)
```yaml
dependencies:
  # Offline storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  
  # Background service
  flutter_background_service: ^5.1.0
  
  # Push notifications
  firebase_messaging: ^14.0.0
  flutter_local_notifications: ^16.0.0
  
  # Location
  geolocator: ^10.0.0
  
  # Connectivity
  connectivity_plus: ^5.0.0
  
  # Real-time
  socket_io_client: ^2.0.0
  
  # HTTP
  dio: ^5.0.0
```

### 8.3 Android Permissions (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### 8.4 iOS Capabilities (Xcode)
- **Background Modes**: Background fetch, Remote notifications
- **Push Notifications**: Enabled
- **Location**: Always/When in use
- **Background Fetch**: Enabled (optional)

---
*Research completed: February 4, 2026*
*Sources: pub.dev, GitHub repositories, Firebase documentation*
