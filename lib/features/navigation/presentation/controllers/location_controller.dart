import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/location_repository.dart';

/// Represents the current location state
class LocationState {
  // TODO: Add fields like permission status, current LatLng, error messages, etc.
}

/// AsyncNotifier to manage location permissions and coordinates
class LocationController extends AsyncNotifier<LocationState> {
  @override
  FutureOr<LocationState> build() {
    // TODO: Initialize state, check current permission status
    throw UnimplementedError();
  }

  Future<void> requestPermissionAndLocation() async {
    // TODO: Use ref.read(locationRepositoryProvider) to request permission
    // TODO: Update state based on the result
  }
}

final locationControllerProvider =
    AsyncNotifierProvider.autoDispose<LocationController, LocationState>(
  LocationController.new,
);
