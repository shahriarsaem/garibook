import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/dev_banner.dart';
import '../../data/models/route_data.dart';
import '../../data/repositories/location_repository.dart';
import '../controllers/location_controller.dart';
import '../controllers/navigation_controller.dart';
import '../widgets/destination_marker.dart';
import '../widgets/location_status_overlay.dart';
import '../widgets/trip_summary_card.dart';
import '../widgets/user_location_marker.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  bool _hasInitiallyCentered = false;

  // Default coordinate (Dhaka center fallback until live GPS is acquired)
  static const LatLng _defaultCenter = LatLng(23.8103, 90.4125);
  static const double _defaultZoom = 15.0;

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

    ref.read(navigationControllerProvider.notifier).startAnimation();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${AppStrings.tripSummary}: ${route.formattedDistance}, ${route.formattedDuration}',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationAsync = ref.watch(locationControllerProvider);
    final locationState = locationAsync.value;
    final location = locationState?.location;
    final navState = ref.watch(navigationControllerProvider);

    // Fit map bounds when a new route is fetched
    ref.listen(navigationControllerProvider, (previous, next) {
      if (next.route != null &&
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
              onTap: (tapPosition, point) {
                final currentLoc =
                    ref.read(locationControllerProvider).value?.location;
                final start = currentLoc != null
                    ? LatLng(currentLoc.latitude, currentLoc.longitude)
                    : null;
                ref
                    .read(navigationControllerProvider.notifier)
                    .selectDestination(point, start);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.garibook',
              ),

              // Polyline Layer (Route with high-visibility outer border)
              if (navState.hasRoute)
                PolylineLayer(
                  polylines: [
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
                ),

              // User Location Accuracy Circle
              if (location != null && location.accuracy > 0)
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

              // Markers Layer: User Location & Destination Pin
              MarkerLayer(
                markers: [
                  // User Location Marker
                  if (location != null)
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
                ],
              ),
            ],
          ),

          // ── Dev Banner ───────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            child: const DevBanner(),
          ),

          // ── Location Status / Permission Alerts ───────────────────────────
          if (locationState != null)
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

          // ── Recenter FAB Button ──────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom +
                (navState.hasDestination ? 240 : 96),
            child: FloatingActionButton(
              heroTag: 'recenter_btn',
              tooltip: AppStrings.recenter,
              onPressed: () => _recenterToUser(locationState),
              child: Icon(
                location != null
                    ? Icons.my_location_rounded
                    : Icons.location_searching_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          // ── Bottom Panel (Instruction Pill or Trip Summary Card) ─────────
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: SafeArea(
              child: navState.hasDestination
                  ? TripSummaryCard(
                      route: navState.route,
                      isLoading: navState.isLoading,
                      errorMessage: navState.errorMessage,
                      onStart: () => _onStartPressed(location, navState.route),
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
                          color:
                              theme.colorScheme.surface.withValues(alpha: 0.95),
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
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
