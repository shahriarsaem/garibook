import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/location_repository.dart';

/// Permission status enumeration
enum LocationPermissionStatus {
  unknown,
  granted,
  denied,
  permanentlyDenied,
}

/// Represents the current location state
class LocationState {
  final LocationData? location;
  final LocationPermissionStatus permissionStatus;
  final bool isServiceEnabled;
  final String? errorMessage;
  final bool isTracking;

  const LocationState({
    this.location,
    this.permissionStatus = LocationPermissionStatus.unknown,
    this.isServiceEnabled = true,
    this.errorMessage,
    this.isTracking = false,
  });

  LocationState copyWith({
    LocationData? location,
    LocationPermissionStatus? permissionStatus,
    bool? isServiceEnabled,
    String? errorMessage,
    bool? isTracking,
  }) {
    return LocationState(
      location: location ?? this.location,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isServiceEnabled: isServiceEnabled ?? this.isServiceEnabled,
      errorMessage: errorMessage,
      isTracking: isTracking ?? this.isTracking,
    );
  }
}

/// AsyncNotifier to manage location permissions, coordinates, and live stream
class LocationController extends AsyncNotifier<LocationState> {
  StreamSubscription<LocationData>? _streamSubscription;

  @override
  FutureOr<LocationState> build() async {
    ref.onDispose(() {
      _streamSubscription?.cancel();
    });

    return _initializeLocation();
  }

  Future<LocationState> _initializeLocation() async {
    final repo = ref.read(locationRepositoryProvider);
    try {
      final permissionStr = await repo.checkPermission();
      if (permissionStr == 'GRANTED') {
        return await _startTrackingAndGetInitial(repo);
      } else {
        final reqResult = await repo.requestPermission();
        if (reqResult == 'GRANTED') {
          return await _startTrackingAndGetInitial(repo);
        } else if (reqResult == 'PERMANENTLY_DENIED') {
          return const LocationState(
            permissionStatus: LocationPermissionStatus.permanentlyDenied,
          );
        } else {
          return const LocationState(
            permissionStatus: LocationPermissionStatus.denied,
          );
        }
      }
    } catch (e) {
      return LocationState(
        errorMessage: e.toString(),
      );
    }
  }

  Future<LocationState> _startTrackingAndGetInitial(
      LocationRepository repo) async {
    LocationData? initialLocation;
    bool isServiceEnabled = true;
    String? error;

    try {
      initialLocation = await repo.getCurrentLocation();
    } catch (e) {
      if (e is PlatformException && e.code == 'SERVICES_DISABLED') {
        isServiceEnabled = false;
      }
      error = e.toString();
    }

    _listenToStream(repo);

    return LocationState(
      location: initialLocation,
      permissionStatus: LocationPermissionStatus.granted,
      isServiceEnabled: isServiceEnabled,
      errorMessage: initialLocation == null ? error : null,
      isTracking: true,
    );
  }

  void _listenToStream(LocationRepository repo) {
    _streamSubscription?.cancel();
    _streamSubscription = repo.getLocationStream().listen(
      (newLocation) {
        final current = state.value;
        if (current != null) {
          state = AsyncData(
            current.copyWith(
              location: newLocation,
              isServiceEnabled: true,
              isTracking: true,
            ),
          );
        }
      },
      onError: (err) {
        if (err is PlatformException && err.code == 'SERVICES_DISABLED') {
          final current = state.value;
          if (current != null) {
            state = AsyncData(
              current.copyWith(
                isServiceEnabled: false,
                isTracking: false,
              ),
            );
          }
        }
      },
    );
  }

  Future<void> requestPermissionAndLocation() async {
    final current = state.value ?? const LocationState();
    final repo = ref.read(locationRepositoryProvider);

    if (current.permissionStatus ==
        LocationPermissionStatus.permanentlyDenied) {
      await repo.openSettings();
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final status = await repo.requestPermission();
      if (status == 'GRANTED') {
        return await _startTrackingAndGetInitial(repo);
      } else if (status == 'PERMANENTLY_DENIED') {
        return current.copyWith(
          permissionStatus: LocationPermissionStatus.permanentlyDenied,
        );
      } else {
        return current.copyWith(
          permissionStatus: LocationPermissionStatus.denied,
        );
      }
    });
  }

  Future<void> refreshLocation() async {
    final current = state.value;
    if (current == null ||
        current.permissionStatus != LocationPermissionStatus.granted) {
      await requestPermissionAndLocation();
      return;
    }

    final repo = ref.read(locationRepositoryProvider);
    try {
      final loc = await repo.getCurrentLocation();
      state = AsyncData(
        current.copyWith(
          location: loc,
          isServiceEnabled: true,
        ),
      );
    } catch (_) {
      // Keep existing location state on transient error
    }
  }

  Future<void> openSettings() async {
    final repo = ref.read(locationRepositoryProvider);
    await repo.openSettings();
  }
}

final locationControllerProvider =
    AsyncNotifierProvider.autoDispose<LocationController, LocationState>(
  LocationController.new,
);
