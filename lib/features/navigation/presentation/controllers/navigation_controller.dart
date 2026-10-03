import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents the navigation state (car animation, polyline, speed)
class NavigationState {
  // TODO: Add fields for route points, current car position, bearing, speed multiplier, etc.
}

/// Notifier to manage route fetching and animation progression
class NavigationController extends Notifier<NavigationState> {
  @override
  NavigationState build() {
    // TODO: Initialize default state (idle)
    throw UnimplementedError();
  }

  Future<void> fetchAndStartRoute(double destLat, double destLng) async {
    // TODO: Call ref.read(routingRepositoryProvider) to get route
    // TODO: Parse polyline and start animation
  }

  void updateSpeedMultiplier(int multiplier) {
    // TODO: Update speed in state
  }

  void startAnimation() {
    // TODO: Setup a Ticker or Timer to interpolate car position along polyline
  }

  void pauseAnimation() {
    // TODO: Pause the Ticker/Timer
  }

  void reset() {
    // TODO: Reset state to initial empty route
  }
}

final navigationControllerProvider =
    NotifierProvider.autoDispose<NavigationController, NavigationState>(
  NavigationController.new,
);
