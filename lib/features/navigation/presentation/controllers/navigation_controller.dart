import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_strings.dart';
import '../../data/repositories/routing_repository.dart';

/// Precomputed segment along the route for fast, accurate interpolation
class _RouteSegment {
  final LatLng start;
  final LatLng end;
  final double distance;
  final double bearing;

  const _RouteSegment({
    required this.start,
    required this.end,
    required this.distance,
    required this.bearing,
  });
}

/// Represents the navigation state (destination, route, car animation, speed, progress)
class NavigationState {
  final LatLng? destination;
  final RouteData? route;
  final bool isLoading;
  final String? errorMessage;
  final bool isNavigating;
  final bool isPaused;
  final bool isCompleted;
  final LatLng? carPosition;
  final double carBearing;
  final int speedMultiplier;
  final double distanceTraveledMeters;
  final double? remainingDistanceMeters;
  final double? remainingDurationSeconds;
  final List<LatLng> completedPoints;
  final List<LatLng> remainingPoints;

  const NavigationState({
    this.destination,
    this.route,
    this.isLoading = false,
    this.errorMessage,
    this.isNavigating = false,
    this.isPaused = false,
    this.isCompleted = false,
    this.carPosition,
    this.carBearing = 0.0,
    this.speedMultiplier = 1,
    this.distanceTraveledMeters = 0.0,
    this.remainingDistanceMeters,
    this.remainingDurationSeconds,
    this.completedPoints = const [],
    this.remainingPoints = const [],
  });

  const NavigationState.initial()
      : destination = null,
        route = null,
        isLoading = false,
        errorMessage = null,
        isNavigating = false,
        isPaused = false,
        isCompleted = false,
        carPosition = null,
        carBearing = 0.0,
        speedMultiplier = 1,
        distanceTraveledMeters = 0.0,
        remainingDistanceMeters = null,
        remainingDurationSeconds = null,
        completedPoints = const [],
        remainingPoints = const [];

  bool get hasDestination => destination != null;
  bool get hasRoute => route != null && route!.points.length >= 2;

  /// Progress along the route from 0.0 to 1.0
  double get progressFraction {
    if (isCompleted) return 1.0;
    final total = route?.distanceMeters ?? 0.0;
    if (total <= 0.0) return 0.0;
    return (distanceTraveledMeters / total).clamp(0.0, 1.0);
  }

  /// Live formatted remaining distance
  String get formattedRemainingDistance {
    final dist = remainingDistanceMeters ?? route?.distanceMeters;
    if (dist == null) return '';
    if (dist >= 1000) {
      final km = dist / 1000;
      return '${km.toStringAsFixed(1)} ${AppStrings.km}';
    }
    return '${dist.round()} ${AppStrings.m}';
  }

  /// Live formatted remaining duration
  String get formattedRemainingDuration {
    final duration = remainingDurationSeconds ?? route?.durationSeconds;
    if (duration == null) return '';
    final totalMinutes = (duration / 60).round();
    if (totalMinutes < 1) {
      return '< 1 ${AppStrings.min}';
    }
    if (totalMinutes < 60) {
      return '$totalMinutes ${AppStrings.min}';
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) {
      return '$hours ${AppStrings.hr}';
    }
    return '$hours ${AppStrings.hr} $mins ${AppStrings.min}';
  }

  NavigationState copyWith({
    LatLng? destination,
    RouteData? route,
    bool? isLoading,
    String? errorMessage,
    bool? isNavigating,
    bool? isPaused,
    bool? isCompleted,
    LatLng? carPosition,
    double? carBearing,
    int? speedMultiplier,
    double? distanceTraveledMeters,
    double? remainingDistanceMeters,
    double? remainingDurationSeconds,
    List<LatLng>? completedPoints,
    List<LatLng>? remainingPoints,
    bool clearDestination = false,
    bool clearRoute = false,
    bool clearError = false,
    bool clearCar = false,
  }) {
    return NavigationState(
      destination: clearDestination ? null : (destination ?? this.destination),
      route: clearRoute ? null : (route ?? this.route),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isNavigating: isNavigating ?? this.isNavigating,
      isPaused: isPaused ?? this.isPaused,
      isCompleted: isCompleted ?? this.isCompleted,
      carPosition: clearCar ? null : (carPosition ?? this.carPosition),
      carBearing: clearCar ? 0.0 : (carBearing ?? this.carBearing),
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      distanceTraveledMeters:
          distanceTraveledMeters ?? this.distanceTraveledMeters,
      remainingDistanceMeters:
          remainingDistanceMeters ?? this.remainingDistanceMeters,
      remainingDurationSeconds:
          remainingDurationSeconds ?? this.remainingDurationSeconds,
      completedPoints: completedPoints ?? this.completedPoints,
      remainingPoints: remainingPoints ?? this.remainingPoints,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationState &&
          runtimeType == other.runtimeType &&
          destination == other.destination &&
          route == other.route &&
          isLoading == other.isLoading &&
          errorMessage == other.errorMessage &&
          isNavigating == other.isNavigating &&
          isPaused == other.isPaused &&
          isCompleted == other.isCompleted &&
          carPosition == other.carPosition &&
          carBearing == other.carBearing &&
          speedMultiplier == other.speedMultiplier &&
          distanceTraveledMeters == other.distanceTraveledMeters &&
          remainingDistanceMeters == other.remainingDistanceMeters &&
          remainingDurationSeconds == other.remainingDurationSeconds &&
          completedPoints.length == other.completedPoints.length &&
          remainingPoints.length == other.remainingPoints.length;

  @override
  int get hashCode => Object.hash(
        destination,
        route,
        isLoading,
        errorMessage,
        isNavigating,
        isPaused,
        isCompleted,
        carPosition,
        carBearing,
        speedMultiplier,
        distanceTraveledMeters,
        remainingDistanceMeters,
        remainingDurationSeconds,
        completedPoints.length,
        remainingPoints.length,
      );
}

/// Notifier to manage route fetching and real-time turn-by-turn route progression
class NavigationController extends Notifier<NavigationState> {
  int _activeRequestId = 0;
  Timer? _animationTimer;
  List<_RouteSegment> _cachedSegments = const [];
  List<LatLng> _cleanPoints = const [];
  double _totalDistanceMeters = 0.0;
  double _distanceTraveled = 0.0;

  @override
  NavigationState build() {
    ref.onDispose(() {
      _animationTimer?.cancel();
      _animationTimer = null;
    });
    return const NavigationState.initial();
  }

  /// Sets the destination and requests a driving route from [currentLocation]
  Future<void> selectDestination(LatLng destination, LatLng? currentLocation) async {
    final requestId = ++_activeRequestId;
    _stopTimerInternal();

    state = state.copyWith(
      destination: destination,
      clearRoute: true,
      clearError: true,
      isLoading: currentLocation != null,
      isNavigating: false,
      isPaused: false,
      isCompleted: false,
      clearCar: true,
      distanceTraveledMeters: 0.0,
      completedPoints: const [],
      remainingPoints: const [],
    );

    if (currentLocation == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppStrings.locationNotAvailable,
      );
      return;
    }

    await _fetchRouteInternal(
      start: currentLocation,
      destination: destination,
      requestId: requestId,
    );
  }

  /// Fetches route between [start] and [destination] points
  Future<void> fetchRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    final requestId = ++_activeRequestId;
    _stopTimerInternal();

    state = state.copyWith(
      destination: destination,
      isLoading: true,
      clearError: true,
      isNavigating: false,
      isPaused: false,
      isCompleted: false,
      clearCar: true,
      distanceTraveledMeters: 0.0,
      completedPoints: const [],
      remainingPoints: const [],
    );

    await _fetchRouteInternal(
      start: start,
      destination: destination,
      requestId: requestId,
    );
  }

  Future<void> _fetchRouteInternal({
    required LatLng start,
    required LatLng destination,
    required int requestId,
  }) async {
    try {
      final repo = ref.read(routingRepositoryProvider);
      final route = await repo.fetchRoute(
        startLat: start.latitude,
        startLng: start.longitude,
        endLat: destination.latitude,
        endLng: destination.longitude,
      );

      // Discard result if disposed, superseded by newer request, or destination was changed/cleared
      if (!ref.mounted ||
          requestId != _activeRequestId ||
          state.destination != destination) {
        return;
      }

      state = state.copyWith(
        route: route,
        isLoading: false,
        clearError: true,
        remainingDistanceMeters: route.distanceMeters,
        remainingDurationSeconds: route.durationSeconds,
      );
    } on RoutingException catch (e) {
      if (!ref.mounted ||
          requestId != _activeRequestId ||
          state.destination != destination) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (_) {
      if (!ref.mounted ||
          requestId != _activeRequestId ||
          state.destination != destination) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppStrings.routeFetchError,
      );
    }
  }

  /// Retries fetching the route with [currentLocation] if destination is already set
  Future<void> retryFetchRoute(LatLng? currentLocation) async {
    final dest = state.destination;
    if (dest != null && currentLocation != null) {
      final requestId = ++_activeRequestId;
      _stopTimerInternal();
      state = state.copyWith(
        isLoading: true,
        clearError: true,
      );
      await _fetchRouteInternal(
        start: currentLocation,
        destination: dest,
        requestId: requestId,
      );
    } else if (dest != null && currentLocation == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppStrings.locationNotAvailable,
      );
    }
  }

  /// Updates navigation speed multiplier (e.g. 1x, 2x, 5x)
  void updateSpeedMultiplier(int multiplier) {
    if (multiplier <= 0) return;
    state = state.copyWith(speedMultiplier: multiplier);
  }

  /// Starts car movement animation along the route
  void startAnimation() {
    if (!state.hasRoute) return;

    if (state.isNavigating && state.isPaused) {
      resumeAnimation();
      return;
    }

    final points = state.route!.points;
    if (points.length < 2) return;

    // Build segments and calculate cumulative route distance
    // Filter out zero/near-zero distance waypoints to prevent azimuth division by zero
    final segments = <_RouteSegment>[];
    double totalDist = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final dist = _calculateDistance(p1, p2);
      if (dist < 0.5) continue;
      final bearing = _calculateBearing(p1, p2);
      segments.add(_RouteSegment(
        start: p1,
        end: p2,
        distance: dist,
        bearing: bearing,
      ));
      totalDist += dist;
    }

    if (segments.isEmpty) {
      final dist = _calculateDistance(points.first, points.last);
      final bearing = _calculateBearing(points.first, points.last);
      segments.add(_RouteSegment(
        start: points.first,
        end: points.last,
        distance: dist > 0 ? dist : 1.0,
        bearing: bearing,
      ));
      totalDist = dist > 0 ? dist : 1.0;
    }

    final cleanPoints = <LatLng>[
      segments.first.start,
      ...segments.map((s) => s.end),
    ];

    _cachedSegments = segments;
    _cleanPoints = cleanPoints;
    _totalDistanceMeters = totalDist;
    _distanceTraveled = 0.0;

    final initialPos = cleanPoints.first;
    final initialBearing = segments.first.bearing;

    state = state.copyWith(
      isNavigating: true,
      isPaused: false,
      isCompleted: false,
      carPosition: initialPos,
      carBearing: initialBearing,
      distanceTraveledMeters: 0.0,
      remainingDistanceMeters: totalDist,
      remainingDurationSeconds: state.route!.durationSeconds,
      completedPoints: [initialPos],
      remainingPoints: List.of(cleanPoints),
    );

    _startTimer();
  }

  /// Pauses car movement animation
  void pauseAnimation() {
    if (!state.isNavigating || state.isPaused) return;
    _animationTimer?.cancel();
    _animationTimer = null;
    state = state.copyWith(isPaused: true);
  }

  /// Resumes car movement animation from current position
  void resumeAnimation() {
    if (!state.isNavigating || !state.isPaused || state.isCompleted) return;
    state = state.copyWith(isPaused: false);
    _startTimer();
  }

  /// Cancels active navigation and returns to route preview
  void cancelNavigation() {
    _stopTimerInternal();
    state = state.copyWith(
      isNavigating: false,
      isPaused: false,
      isCompleted: false,
      clearCar: true,
      distanceTraveledMeters: 0.0,
      remainingDistanceMeters: state.route?.distanceMeters,
      remainingDurationSeconds: state.route?.durationSeconds,
      completedPoints: const [],
      remainingPoints: const [],
    );
  }

  /// Clears destination and route, resetting state to idle
  void clearDestination() {
    _activeRequestId++;
    _stopTimerInternal();
    state = const NavigationState.initial();
  }

  /// Resets navigation state completely
  void reset() {
    clearDestination();
  }

  void _startTimer() {
    _animationTimer?.cancel();
    // 30ms interval = ~33 FPS for smooth turn-by-turn interpolation
    _animationTimer = Timer.periodic(
      const Duration(milliseconds: 30),
      _onTick,
    );
  }

  void _stopTimerInternal() {
    _animationTimer?.cancel();
    _animationTimer = null;
    _distanceTraveled = 0.0;
    _cachedSegments = const [];
    _cleanPoints = const [];
    _totalDistanceMeters = 0.0;
  }

  void _onTick(Timer timer) {
    if (!state.isNavigating || state.isPaused || state.isCompleted) {
      timer.cancel();
      return;
    }

    if (_cachedSegments.isEmpty || _totalDistanceMeters <= 0.0) {
      timer.cancel();
      return;
    }

    // Base speed scaled so any route completes in ~35 seconds at 1x
    // Clamped between 20 m/s (~72 km/h) and 100 m/s (~360 km/h)
    final baseSpeed = (_totalDistanceMeters / 35.0).clamp(20.0, 100.0);
    final speed = baseSpeed * state.speedMultiplier;
    const dt = 0.030; // 30ms
    final stepDistance = speed * dt;

    _distanceTraveled += stepDistance;

    // Check for trip completion
    if (_distanceTraveled >= _totalDistanceMeters) {
      _distanceTraveled = _totalDistanceMeters;
      _animationTimer?.cancel();
      _animationTimer = null;

      final lastPoint = _cleanPoints.isNotEmpty
          ? _cleanPoints.last
          : state.route!.points.last;
      final lastBearing = _cachedSegments.isNotEmpty
          ? _cachedSegments.last.bearing
          : state.carBearing;

      state = state.copyWith(
        isNavigating: true,
        isPaused: false,
        isCompleted: true,
        carPosition: lastPoint,
        carBearing: lastBearing,
        distanceTraveledMeters: _totalDistanceMeters,
        remainingDistanceMeters: 0.0,
        remainingDurationSeconds: 0.0,
        completedPoints: List.of(_cleanPoints),
        remainingPoints: [lastPoint],
      );
      return;
    }

    // Determine current segment index
    double accumulated = 0.0;
    int segIdx = 0;
    while (segIdx < _cachedSegments.length - 1 &&
        accumulated + _cachedSegments[segIdx].distance <= _distanceTraveled) {
      accumulated += _cachedSegments[segIdx].distance;
      segIdx++;
    }

    final currentSegment = _cachedSegments[segIdx];
    final segmentDist = currentSegment.distance;
    final distInSegment =
        (_distanceTraveled - accumulated).clamp(0.0, segmentDist);
    final t = segmentDist > 0.0001
        ? (distInSegment / segmentDist).clamp(0.0, 1.0)
        : 1.0;

    // Interpolate coordinate
    final lat = currentSegment.start.latitude +
        (currentSegment.end.latitude - currentSegment.start.latitude) * t;
    final lng = currentSegment.start.longitude +
        (currentSegment.end.longitude - currentSegment.start.longitude) * t;
    final carPos = LatLng(lat, lng);

    final bearing = currentSegment.bearing;

    // Split polyline points at current vehicle position
    final completed = <LatLng>[
      ..._cleanPoints.sublist(0, segIdx + 1),
      carPos,
    ];
    final remaining = <LatLng>[
      carPos,
      ..._cleanPoints.sublist(segIdx + 1),
    ];

    final remDistance = (_totalDistanceMeters - _distanceTraveled)
        .clamp(0.0, _totalDistanceMeters);
    final remDuration = _totalDistanceMeters > 0
        ? (remDistance / _totalDistanceMeters) * (state.route?.durationSeconds ?? 0)
        : 0.0;

    state = state.copyWith(
      carPosition: carPos,
      carBearing: bearing,
      distanceTraveledMeters: _distanceTraveled,
      remainingDistanceMeters: remDistance,
      remainingDurationSeconds: remDuration,
      completedPoints: completed,
      remainingPoints: remaining,
    );
  }

  /// Calculates Haversine distance in meters between two coordinates
  double _calculateDistance(LatLng p1, LatLng p2) {
    const earthRadius = 6371000.0; // meters
    final dLat = (p2.latitude - p1.latitude) * (pi / 180.0);
    final dLon = (p2.longitude - p1.longitude) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(p1.latitude * (pi / 180.0)) *
            cos(p2.latitude * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Calculates spherical forward azimuth (bearing) from [start] to [end] in degrees [0, 360)
  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (pi / 180.0);
    final lon1 = start.longitude * (pi / 180.0);
    final lat2 = end.latitude * (pi / 180.0);
    final lon2 = end.longitude * (pi / 180.0);

    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final radians = atan2(y, x);
    final degrees = radians * (180.0 / pi);
    return (degrees + 360.0) % 360.0;
  }
}

final navigationControllerProvider =
    NotifierProvider.autoDispose<NavigationController, NavigationState>(
  NavigationController.new,
);
