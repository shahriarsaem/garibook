import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_strings.dart';
import '../../data/repositories/routing_repository.dart';

/// Represents the navigation state (destination, route, car animation, speed)
class NavigationState {
  final LatLng? destination;
  final RouteData? route;
  final bool isLoading;
  final String? errorMessage;
  final bool isNavigating;
  final LatLng? carPosition;
  final double carBearing;
  final int speedMultiplier;

  const NavigationState({
    this.destination,
    this.route,
    this.isLoading = false,
    this.errorMessage,
    this.isNavigating = false,
    this.carPosition,
    this.carBearing = 0.0,
    this.speedMultiplier = 1,
  });

  const NavigationState.initial()
      : destination = null,
        route = null,
        isLoading = false,
        errorMessage = null,
        isNavigating = false,
        carPosition = null,
        carBearing = 0.0,
        speedMultiplier = 1;

  bool get hasDestination => destination != null;
  bool get hasRoute => route != null && route!.points.length >= 2;

  NavigationState copyWith({
    LatLng? destination,
    RouteData? route,
    bool? isLoading,
    String? errorMessage,
    bool? isNavigating,
    LatLng? carPosition,
    double? carBearing,
    int? speedMultiplier,
    bool clearDestination = false,
    bool clearRoute = false,
    bool clearError = false,
  }) {
    return NavigationState(
      destination: clearDestination ? null : (destination ?? this.destination),
      route: clearRoute ? null : (route ?? this.route),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isNavigating: isNavigating ?? this.isNavigating,
      carPosition: carPosition ?? this.carPosition,
      carBearing: carBearing ?? this.carBearing,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
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
          carPosition == other.carPosition &&
          carBearing == other.carBearing &&
          speedMultiplier == other.speedMultiplier;

  @override
  int get hashCode =>
      destination.hashCode ^
      route.hashCode ^
      isLoading.hashCode ^
      errorMessage.hashCode ^
      isNavigating.hashCode ^
      carPosition.hashCode ^
      carBearing.hashCode ^
      speedMultiplier.hashCode;
}

/// Notifier to manage route fetching and navigation state progression
class NavigationController extends Notifier<NavigationState> {
  int _activeRequestId = 0;

  @override
  NavigationState build() {
    return const NavigationState.initial();
  }

  /// Sets the destination and requests a driving route from [currentLocation]
  Future<void> selectDestination(LatLng destination, LatLng? currentLocation) async {
    final requestId = ++_activeRequestId;

    state = state.copyWith(
      destination: destination,
      clearRoute: true,
      clearError: true,
      isLoading: currentLocation != null,
      isNavigating: false,
      carPosition: null,
      carBearing: 0.0,
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
    state = state.copyWith(
      destination: destination,
      isLoading: true,
      clearError: true,
      isNavigating: false,
      carPosition: null,
      carBearing: 0.0,
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

  /// Updates navigation speed multiplier
  void updateSpeedMultiplier(int multiplier) {
    state = state.copyWith(speedMultiplier: multiplier);
  }

  /// Starts car movement animation (for Step 3)
  void startAnimation() {
    if (state.hasRoute) {
      state = state.copyWith(isNavigating: true);
    }
  }

  /// Pauses car movement animation (for Step 3)
  void pauseAnimation() {
    state = state.copyWith(isNavigating: false);
  }

  /// Clears destination and route, resetting state to idle
  void clearDestination() {
    _activeRequestId++;
    state = const NavigationState.initial();
  }

  /// Resets navigation state completely
  void reset() {
    clearDestination();
  }
}

final navigationControllerProvider =
    NotifierProvider.autoDispose<NavigationController, NavigationState>(
  NavigationController.new,
);
