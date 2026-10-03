import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/common_button.dart';
import '../../../../core/widgets/dev_banner.dart';
import '../../data/repositories/location_repository.dart';
import '../controllers/location_controller.dart';
import '../widgets/location_status_overlay.dart';
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

  void _onStartPressed(LocationData? location) {
    if (location != null) {
      debugPrint('${AppStrings.currentLocation}: $location');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.currentLocation}: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      debugPrint(AppStrings.locationNotAvailable);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.locationNotAvailable),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationAsync = ref.watch(locationControllerProvider);
    final locationState = locationAsync.value;
    final location = locationState?.location;

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
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.garibook',
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
              // User Location Marker
              if (location != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(location.latitude, location.longitude),
                      width: 56,
                      height: 56,
                      child: UserLocationMarker(
                        bearing: location.bearing,
                        accuracy: location.accuracy,
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
            bottom: 96,
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

          // ── Bottom Panel (Start Action) ──────────────────────────────────
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Center(
                child: CommonButton(
                  label: AppStrings.start,
                  icon: Icons.navigation_rounded,
                  onPressed: () => _onStartPressed(location),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
