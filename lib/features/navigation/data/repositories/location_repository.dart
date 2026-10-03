import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Model
// ─────────────────────────────────────────────────────────────────────────────

class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double bearing;
  final double speed;
  final double altitude;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.bearing,
    required this.speed,
    required this.altitude,
  });

  factory LocationData.fromMap(Map<dynamic, dynamic> map) {
    return LocationData(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toDouble(),
      bearing: (map['bearing'] as num).toDouble(),
      speed: (map['speed'] as num).toDouble(),
      altitude: (map['altitude'] as num).toDouble(),
    );
  }

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lng: $longitude, accuracy: ${accuracy}m, bearing: $bearing°, speed: ${speed}m/s, altitude: ${altitude}m)';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class LocationRepository {
  Future<String> checkPermission();
  Future<String> requestPermission();
  Future<LocationData> getCurrentLocation();
  Future<void> openSettings();
  Stream<LocationData> getLocationStream();
}

// ─────────────────────────────────────────────────────────────────────────────
// Concrete Implementation
// ─────────────────────────────────────────────────────────────────────────────

class NativeLocationRepository implements LocationRepository {
  static const _methodChannel =
      MethodChannel('com.example.garibook/location_methods');
  static const _eventChannel =
      EventChannel('com.example.garibook/location_stream');

  @override
  Future<String> checkPermission() async {
    final result = await _methodChannel.invokeMethod<String>('checkPermission');
    return result ?? 'DENIED';
  }

  @override
  Future<String> requestPermission() async {
    final result =
        await _methodChannel.invokeMethod<String>('requestPermission');
    return result ?? 'DENIED';
  }

  @override
  Future<LocationData> getCurrentLocation() async {
    final result = await _methodChannel
        .invokeMapMethod<dynamic, dynamic>('getCurrentLocation');
    return LocationData.fromMap(result!);
  }

  @override
  Future<void> openSettings() async {
    await _methodChannel.invokeMethod<void>('openSettings');
  }

  @override
  Stream<LocationData> getLocationStream() {
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) => LocationData.fromMap(event as Map<dynamic, dynamic>));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return NativeLocationRepository();
});
