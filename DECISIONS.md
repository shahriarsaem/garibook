# Architectural & Engineering Decisions

**Project:** Garibook — Route & Car Navigation  
**Assessment:** Senior Mobile Developer Assessment: Route & Car Navigation  
**Author:** Senior Mobile Developer Candidate  

---

## Q1. Why did you choose your architecture and state management?

I chose a **clean feature-based architecture** (`lib/core/` + `lib/features/`) combined with **Riverpod** using code-generation-free `Notifier` and `AsyncNotifier` primitives. Here's why:

1. **Compile-Time Safety & Zero Build Runner Overhead**:
   Riverpod declares providers globally and resolves them outside the widget tree, giving strict compile-time type safety. By opting for native Riverpod syntax (`Notifier` and `AsyncNotifier`), I avoided `build_runner` code generation complexity.

2. **Explicit Asynchronous State Modeling**:
   Location acquisition and route fetching are inherently asynchronous and error-prone. Riverpod's `AsyncValue` (`AsyncData`, `AsyncLoading`, `AsyncError`) allows the UI to model loading and failure states cleanly without boilerplate boolean flags (`isLoading`, `hasError`).

3. **Auto-Disposal and Lifecycle Encapsulation**:
   Riverpod's `ref.onDispose` hook guarantees that when controllers are unmounted, all native streams, tickers, and polling timers are immediately canceled. This prevents background memory leaks that often plague navigation apps when switching screens.

4. **Clean Architectural Boundaries**:
   Riverpod enforces clear separation between the presentation layer (`MapScreen`), business logic (`NavigationController`, `LocationController`), and data layer (`RoutingRepository`, `LocationRepository`).

The feature-based folder structure ensures each feature owns its data models, repositories, controllers, and UI widgets — making the codebase scalable without cross-feature coupling.

---

## Q2. How did you design the Flutter ↔ native location bridge (channel choice, error mapping, stream lifecycle)?

I built a custom native connection using Kotlin to handle location services.

### 1. Choosing the Right Channels
I used two different types of channels to talk between Flutter and Android, depending on the job:

- **`EventChannel` (for live updates):** Used strictly for continuous GPS updates. Since location data flows continuously while driving, an `EventChannel` is perfect because it translates directly into a Flutter `Stream`. This avoids the lag of constantly polling the native side for coordinates.
- **`MethodChannel` (for one-off requests):** Used for simple "ask and answer" tasks. For example: checking permissions, asking the user for permission, grabbing a single quick location fix, or opening the device settings.

### 2. Error Mapping
When Android throws an error (like "GPS is turned off" or "Permission Denied"), I don't just pass a generic error back to Flutter. Instead, I translate these native errors into clear, specific Dart exceptions (e.g., converting Android's `PERMISSION_DENIED` to a Dart `LocationPermissionDeniedException`). 

This makes the Flutter UI code much cleaner. It knows exactly what went wrong and can easily show the right message or action to the user (like showing an "Open Settings" button if permissions are permanently denied).

### 3. Stream Lifecycle (Saving Battery)
Leaving GPS running when the app isn't using it drains the battery fast. To prevent this, I made sure the bridge cleans up after itself safely:
- When the user leaves the map screen, Riverpod automatically cancels the Flutter location stream.
- This cancellation message travels through the `EventChannel` straight to the Android native side.
- The Android side immediately tells the phone's GPS to stop tracking. This ensures there are no hidden battery drains or orphaned listeners.

---

## Q3. How does your interpolation and bearing logic work?

Moving a car icon smoothly along a real road requires more than just jumping between GPS points — I needed proper math to make it look and feel like actual driving.

### Step 1: Break the Route into Segments

When OSRM returns a list of coordinates for the route, I first break them into small segments (point A → point B, point B → point C, and so on). For each segment, I pre-calculate:
- The **real-world distance** between the two points using the **Haversine formula** (which accounts for Earth's curvature, unlike simple straight-line math).
- The **cumulative distance** from the route start, so I always know how far the car has "traveled."
- The **bearing** (compass direction) of that segment.

I also filter out points that are less than 0.5 meters apart to avoid glitchy calculations.

### Step 2: Point the Car in the Right Direction

To make the car icon face the road ahead, I calculate the **forward azimuth** — essentially the compass heading from the current point to the next point, using spherical trigonometry. This gives a degree value (0° = North, 90° = East, etc.) that I apply as rotation to the car marker widget.

### Step 3: Smooth the Rotation

Without smoothing, the car would snap instantly between angles. Worse — if the car goes from heading 355° (almost North) to 5° (also almost North), a naive approach would spin it 350° the wrong way around. I solve this by always rotating along the **shortest arc** and applying a smoothing factor so the turn animates gradually.

### Step 4: Animate at 33 FPS

I run the animation with a `Ticker` firing every 30ms (~33 FPS). On each frame, I calculate exactly where the car should be along the current segment using simple linear interpolation. This frame rate gives smooth visual movement without overloading the UI thread on lower-end Android devices.

---

## Q4. How did you structure the flavor configuration?

The assessment requires separate `dev` and `prod` environments capable of side-by-side device installation. I structured this as a two-layer system — Android Gradle flavors for native configuration and a Dart-side config class for runtime behavior.

### Android Gradle Configuration (`android/app/build.gradle.kts`)

I established dimension `"app"` with:
```kotlin
flavorDimensions += listOf("app")
productFlavors {
    create("dev") {
        dimension = "app"
        applicationIdSuffix = ".dev"
        manifestPlaceholders["appLabel"] = "Garibook Dev"
    }
    create("prod") {
        dimension = "app"
        manifestPlaceholders["appLabel"] = "Garibook"
    }
}
```

- The `.dev` suffix on `applicationId` allows both dev and prod builds to be installed simultaneously on the same device.
- In `AndroidManifest.xml`, `android:label="${appLabel}"` dynamically resolves the application launcher title so users can visually distinguish between the two builds.

### Dart Environment Injection (`lib/core/config/flavor_config.dart`)

At the Dart layer, `FlavorConfig` inspects `appFlavor` provided by the Flutter build pipeline. This configures:
- Base routing API endpoints (pointing to different OSRM instances per environment).
- Visibility of the top `DEV` banner badge so developers always know which build they're running.
- Logger verbosity (verbose in dev, minimal in prod).

---

## Q5. What would you change before shipping this to production (battery usage, background location, routing server choice, cost at scale)?

If deploying Garibook to hundreds of thousands of daily active users, I would prioritize the following architectural upgrades:

1. **Production Routing Server (OSRM / Valhalla)**:
   - Replace the demo public OSRM endpoint with a production-grade, self-hosted routing server. The public OSRM demo server has no SLA, no rate limiting guarantees, and cannot handle production-scale traffic.
   - On the Flutter side, implement client-side exponential backoff, circuit breaking, and offline route fallbacks to handle server unavailability gracefully.

2. **Foreground Location Service with Sticky Notification**:
   - Continuous navigation while the screen is off or during background audio calls requires an Android **Foreground Service** with `foregroundServiceType="location"` and persistent notification.
   - Without this, Android OS will kill the location updates within minutes of backgrounding.

3. **Adaptive Battery Throttling**:
   - Implement dynamic GPS request intervals: decrease frequency to $10\text{ s}$ when vehicle is stationary or moving under $5\text{ km/h}$, and scale to $1\text{ s}$ during high-speed highway travel.
   - This alone can reduce battery consumption by 40–60% during typical urban driving with frequent stops.

4. **Offline Map Tile Caching (MBTiles / SQLite)**:
   - Integrate vector tile caching using SQLite or raster MBTiles so that maps and routes remain browsable in low-connectivity areas (tunnels, rural highways).

5. **Security & SSL Pinning**:
   - Enforce HTTP Public Key Pinning (HPKP) on all API endpoints to protect against man-in-the-middle attacks.

---

## Q6. What did you deliberately leave out due to time?

The following features were intentionally scoped out to maintain strict focus on the core assessment deliverables — route rendering, native location accuracy, and movement interpolation:

1. **Turn-by-Turn Voice Directions (TTS)**:
   - Voice synthesis engine using `flutter_tts` was omitted. While important for a real navigation app, it is a separate concern from the core routing and simulation logic being assessed.

2. **Alternative Routes & Waypoint Re-ordering**:
   - The UI supports single destination routing. Multi-stop routing and multiple polyline alternatives were deferred as they require significant additional OSRM API integration and UI work.

3. **Map 3D Tilt & Perspective Camera**:
   - `flutter_map` excels at 2D orthographic cartography. Full 3D terrain tilt and vehicle follow-pitch would require vector engines like Mapbox GL or MapLibre Native, which is a fundamentally different rendering approach.
