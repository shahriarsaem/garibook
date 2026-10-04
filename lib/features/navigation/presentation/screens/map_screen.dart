import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/config/flavor_config.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/dev_banner.dart';
import '../../data/models/route_data.dart';
import '../../data/repositories/location_repository.dart';
import '../controllers/location_controller.dart';
import '../controllers/navigation_controller.dart';
import '../widgets/car_marker.dart';
import '../widgets/destination_marker.dart';
import '../widgets/location_status_overlay.dart';
import '../widgets/navigation_dashboard.dart';
import '../widgets/osm_attribution_badge.dart';
import '../widgets/trip_summary_card.dart';
import '../widgets/user_location_marker.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  late final AppLifecycleListener _lifecycleListener;
  bool _hasInitiallyCentered = false;
  bool _isCameraFollowing = false;
  bool _wasAutoPausedByLifecycle = false;
  DateTime _lastCameraMoveTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Default coordinate (Dhaka center fallback until live GPS is acquired)
  static const LatLng _defaultCenter = LatLng(23.8103, 90.4125);
  static const double _defaultZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: _onAppPaused,
      onHide: _onAppPaused,
      onResume: _onAppResumed,
    );
  }

  void _onAppPaused() {
    final navState = ref.read(navigationControllerProvider);
    if (navState.isNavigating && !navState.isPaused && !navState.isCompleted) {
      _wasAutoPausedByLifecycle = true;
      ref.read(navigationControllerProvider.notifier).pauseAnimation();
    }
  }

  void _onAppResumed() {
    if (_wasAutoPausedByLifecycle) {
      _wasAutoPausedByLifecycle = false;
      final navState = ref.read(navigationControllerProvider);
      if (navState.isNavigating && navState.isPaused && !navState.isCompleted) {
        ref.read(navigationControllerProvider.notifier).resumeAnimation();
      }
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _recenterToUser(LocationState? locationState) {
    final location = locationState?.location;
    if (location != null) {
      _mapController.move(
        LatLng(location.latitude, location.longitude),
        _defaultZoom,
      );
    } else {
      ref.read(locationControllerProvider.notifier).refreshLocation();
    }
  }

  void _onRecenterPressed(LocationState? locationState, NavigationState navState) {
    if (navState.isNavigating && navState.carPosition != null) {
      setState(() {
        _isCameraFollowing = true;
      });
      _mapController.move(
        navState.carPosition!,
        16.5,
      );
    } else {
      _recenterToUser(locationState);
    }
  }

  void _onDestinationSelected(LatLng point, {bool isLongPress = false}) {
    final navState = ref.read(navigationControllerProvider);
    // Ignore destination selection while actively navigating
    if (navState.isNavigating) return;

    if (isLongPress) {
      HapticFeedback.selectionClick();
    }

    final currentLoc =
        ref.read(locationControllerProvider).value?.location;
    final start = currentLoc != null
        ? LatLng(currentLoc.latitude, currentLoc.longitude)
        : null;
    ref
        .read(navigationControllerProvider.notifier)
        .selectDestination(point, start);
  }

  void _onStartPressed(LocationData? location, RouteData? route) {
    if (location == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.locationNotAvailable),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (route == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.tapToSelectDestination),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isCameraFollowing = true;
    });

    ref.read(navigationControllerProvider.notifier).startAnimation();

    if (route.points.isNotEmpty) {
      _mapController.move(route.points.first, 16.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationAsync = ref.watch(locationControllerProvider);
    final locationState = locationAsync.value;
    final location = locationState?.location;
    final navState = ref.watch(navigationControllerProvider);

    // Fit map bounds when a new route is fetched and not yet navigating
    ref.listen(navigationControllerProvider, (previous, next) {
      if (!next.isNavigating &&
          next.route != null &&
          next.route != previous?.route &&
          next.route!.points.length >= 2) {
        final bounds = LatLngBounds.fromPoints(next.route!.points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            maxZoom: 17.0,
            padding: const EdgeInsets.only(
              left: 48,
              right: 48,
              top: 100,
              bottom: 240,
            ),
          ),
        );
      }

      // Smooth camera follow while vehicle is moving
      if (next.isNavigating &&
          !next.isPaused &&
          !next.isCompleted &&
          next.carPosition != null &&
          _isCameraFollowing) {
        final now = DateTime.now();
        if (now.difference(_lastCameraMoveTime).inMilliseconds >= 50) {
          _lastCameraMoveTime = now;
          _mapController.move(
            next.carPosition!,
            _mapController.camera.zoom,
          );
        }
      }

      // Handle trip completion camera centering
      if (next.isCompleted && previous?.isCompleted != true) {
        if (_isCameraFollowing) {
          setState(() {
            _isCameraFollowing = false;
          });
        }
        if (next.carPosition != null) {
          _mapController.move(next.carPosition!, 16.0);
        }
      }

      // Reset camera follow if navigation stopped or cancelled
      if (previous?.isNavigating == true && !next.isNavigating) {
        if (_isCameraFollowing) {
          setState(() {
            _isCameraFollowing = false;
          });
        }
      }
    });

    // Auto-fetch route if destination was picked before GPS lock was acquired
    ref.listen(locationControllerProvider, (previous, next) {
      final prevLoc = previous?.value?.location;
      final currentLoc = next.value?.location;
      if (prevLoc == null && currentLoc != null) {
        final currentNavState = ref.read(navigationControllerProvider);
        if (currentNavState.hasDestination &&
            !currentNavState.hasRoute &&
            !currentNavState.isLoading) {
          ref.read(navigationControllerProvider.notifier).retryFetchRoute(
                LatLng(currentLoc.latitude, currentLoc.longitude),
              );
        }
      }
    });

    // Automatically center map once live location becomes available for the first time
    if (!_hasInitiallyCentered && location != null) {
      _hasInitiallyCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(
            LatLng(location.latitude, location.longitude),
            _defaultZoom,
          );
        }
      });
    }

    final currentCenter = location != null
        ? LatLng(location.latitude, location.longitude)
        : _defaultCenter;

    final isFollowingCar = navState.isNavigating && _isCameraFollowing;

    return Scaffold(
      body: Stack(
        children: [
          // ── Real flutter_map ──────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentCenter,
              initialZoom: _defaultZoom,
              minZoom: 3.0,
              maxZoom: 19.0,
              onPositionChanged: (camera, hasGesture) {
                // When user pans manually while navigating, pause camera follow
                if (hasGesture && _isCameraFollowing) {
                  setState(() {
                    _isCameraFollowing = false;
                  });
                }
              },
              onTap: (tapPosition, point) =>
                  _onDestinationSelected(point, isLongPress: false),
              onLongPress: (tapPosition, point) =>
                  _onDestinationSelected(point, isLongPress: true),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.garibook',
              ),

              // Polyline Layer (Split rendering when navigating, standard when previewing)
              if (navState.hasRoute)
                PolylineLayer(
                  polylines: [
                    if (navState.isNavigating) ...[
                      if (navState.completedPoints.length >= 2)
                        // Completed segment (muted, subtle outline)
                        Polyline(
                          points: navState.completedPoints,
                          strokeWidth: 5.0,
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.5),
                          borderStrokeWidth: 1.5,
                          borderColor: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.3),
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        ),
                      if (navState.remainingPoints.length >= 2)
                        // Upcoming segment (vibrant primary blue with glow border)
                        Polyline(
                          points: navState.remainingPoints,
                          strokeWidth: 5.5,
                          color: theme.colorScheme.primary,
                          borderStrokeWidth: 2.5,
                          borderColor:
                              theme.colorScheme.primary.withValues(alpha: 0.35),
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        ),
                    ] else ...[
                      // Full route preview
                      Polyline(
                        points: navState.route!.points,
                        strokeWidth: 5.0,
                        color: theme.colorScheme.primary,
                        borderStrokeWidth: 2.5,
                        borderColor:
                            theme.colorScheme.primary.withValues(alpha: 0.35),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ],
                ),

              // User Location Accuracy Circle
              if (location != null &&
                  location.accuracy > 0 &&
                  (!navState.isNavigating || navState.carPosition == null))
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(location.latitude, location.longitude),
                      radius: location.accuracy.clamp(10.0, 100.0),
                      useRadiusInMeter: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderColor:
                          theme.colorScheme.primary.withValues(alpha: 0.4),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

              // Markers Layer: User Location, Destination Pin & Car Marker
              MarkerLayer(
                markers: [
                  // User Location Marker (visible when not navigating)
                  if (location != null &&
                      (!navState.isNavigating || navState.carPosition == null))
                    Marker(
                      point: LatLng(location.latitude, location.longitude),
                      width: 56,
                      height: 56,
                      child: UserLocationMarker(
                        bearing: location.bearing,
                        accuracy: location.accuracy,
                      ),
                    ),

                  // Destination Pin Marker
                  if (navState.destination != null)
                    Marker(
                      key: ValueKey(navState.destination),
                      point: navState.destination!,
                      width: 44,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: DestinationMarker(
                        key: ValueKey(navState.destination),
                      ),
                    ),

                  // Animated Top-down Car Marker
                  if (navState.carPosition != null)
                    Marker(
                      key: const ValueKey('car_marker'),
                      point: navState.carPosition!,
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      child: CarMarker(
                        bearing: navState.carBearing,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Dev Banner (Visible only for dev flavor) ─────────────────────
          if (ref.watch(flavorConfigProvider).showDevBanner)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              child: const DevBanner(),
            ),

          // ── Location Status / Permission Alerts ───────────────────────────
          if (locationState != null && !navState.isNavigating)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 48,
              left: 0,
              right: 0,
              child: LocationStatusOverlay(
                state: locationState,
                onRequestPermission: () => ref
                    .read(locationControllerProvider.notifier)
                    .requestPermissionAndLocation(),
                onOpenSettings: () => ref
                    .read(locationControllerProvider.notifier)
                    .openSettings(),
                onRetry: () => ref
                    .read(locationControllerProvider.notifier)
                    .refreshLocation(),
              ),
            ),

          // ── Loading indicator when acquiring initial location ─────────────
          if (locationAsync.isLoading && location == null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.fetchingLocation,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── OSM Attribution Badge ─────────────────────────────────────────
          Positioned(
            left: 16,
            bottom: MediaQuery.paddingOf(context).bottom +
                (navState.isNavigating
                    ? 210
                    : (navState.hasDestination ? 240 : 88)),
            child: const OsmAttributionBadge(),
          ),

          // ── Recenter / Follow FAB Button ─────────────────────────────────
          if (!navState.isCompleted)
            Positioned(
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom +
                  (navState.hasDestination ? 240 : 96),
              child: FloatingActionButton(
                heroTag: 'recenter_btn',
                tooltip: navState.isNavigating
                    ? AppStrings.recenterVehicle
                    : AppStrings.recenter,
                onPressed: () => _onRecenterPressed(locationState, navState),
                child: Icon(
                  navState.isNavigating
                      ? (isFollowingCar
                          ? Icons.navigation_rounded
                          : Icons.near_me_disabled_rounded)
                      : (location != null
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded),
                  color: isFollowingCar
                      ? theme.colorScheme.primary
                      : (navState.isNavigating
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary),
                ),
              ),
            ),

          // ── Bottom Panel (Instruction Pill, Trip Summary Card, or Navigation Dashboard) ──
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: SafeArea(
              child: navState.isNavigating
                  ? NavigationDashboard(
                      state: navState,
                      onPause: () => ref
                          .read(navigationControllerProvider.notifier)
                          .pauseAnimation(),
                      onResume: () => ref
                          .read(navigationControllerProvider.notifier)
                          .resumeAnimation(),
                      onCancel: () {
                        setState(() {
                          _isCameraFollowing = false;
                        });
                        ref
                            .read(navigationControllerProvider.notifier)
                            .cancelNavigation();
                      },
                      onSpeedChanged: (multiplier) => ref
                          .read(navigationControllerProvider.notifier)
                          .updateSpeedMultiplier(multiplier),
                      onDone: () {
                        setState(() {
                          _isCameraFollowing = false;
                        });
                        ref
                            .read(navigationControllerProvider.notifier)
                            .clearDestination();
                      },
                    )
                  : (navState.hasDestination
                      ? TripSummaryCard(
                          route: navState.route,
                          isLoading: navState.isLoading,
                          errorMessage: navState.errorMessage,
                          onStart: () =>
                              _onStartPressed(location, navState.route),
                          onClear: () => ref
                              .read(navigationControllerProvider.notifier)
                              .clearDestination(),
                          onRetry: () {
                            final loc = ref
                                .read(locationControllerProvider)
                                .value
                                ?.location;
                            ref
                                .read(navigationControllerProvider.notifier)
                                .retryFetchRoute(
                                  loc != null
                                      ? LatLng(loc.latitude, loc.longitude)
                                      : null,
                                );
                          },
                        )
                      : Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface
                                  .withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppStrings.tapToSelectDestination,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
            ),
          ),
        ],
      ),
    );
  }
}
