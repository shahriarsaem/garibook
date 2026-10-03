import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_strings.dart';

/// Exception thrown when route calculation fails
class RoutingException implements Exception {
  final String message;
  const RoutingException(this.message);

  @override
  String toString() => message;
}

/// Represents a parsed route from the OSRM routing service
class RouteData {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteData({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// Human-readable formatted distance (e.g., "1.5 km" or "850 m")
  String get formattedDistance {
    if (distanceMeters >= 1000) {
      final km = distanceMeters / 1000;
      return '${km.toStringAsFixed(1)} ${AppStrings.km}';
    }
    return '${distanceMeters.round()} ${AppStrings.m}';
  }

  /// Human-readable formatted duration (e.g., "15 min" or "1 hr 20 min")
  String get formattedDuration {
    final totalMinutes = (durationSeconds / 60).round();
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

  /// Parses OSRM GeoJSON response
  factory RouteData.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String?;
    if (code != 'Ok') {
      final message = json['message'] as String? ?? AppStrings.routeNotFound;
      throw RoutingException(message);
    }

    final routes = json['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw const RoutingException(AppStrings.routeNotFound);
    }

    final firstRoute = routes[0] as Map<String, dynamic>;
    final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
    if (geometry == null) {
      throw const RoutingException(AppStrings.routeNotFound);
    }

    final rawCoordinates = geometry['coordinates'] as List<dynamic>?;
    if (rawCoordinates == null || rawCoordinates.isEmpty) {
      throw const RoutingException(AppStrings.routeNotFound);
    }

    final points = <LatLng>[];
    for (final coord in rawCoordinates) {
      if (coord is List && coord.length >= 2) {
        // GeoJSON provides [longitude, latitude]
        final lng = (coord[0] as num).toDouble();
        final lat = (coord[1] as num).toDouble();
        points.add(LatLng(lat, lng));
      }
    }

    // A valid navigable route requires at least start and end points
    if (points.length < 2) {
      throw const RoutingException(AppStrings.routeNotFound);
    }

    final distance = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
    final duration = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;

    return RouteData(
      points: List.unmodifiable(points),
      distanceMeters: distance,
      durationSeconds: duration,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteData &&
          runtimeType == other.runtimeType &&
          distanceMeters == other.distanceMeters &&
          durationSeconds == other.durationSeconds &&
          listEquals(points, other.points);

  @override
  int get hashCode => Object.hash(
        distanceMeters,
        durationSeconds,
        Object.hashAll(points),
      );

  @override
  String toString() {
    return 'RouteData(points: ${points.length}, distance: $formattedDistance, duration: $formattedDuration)';
  }
}
