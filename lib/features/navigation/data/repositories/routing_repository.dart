import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_strings.dart';
import '../models/route_data.dart';

export '../models/route_data.dart';

/// Abstract interface for routing operations
abstract class RoutingRepository {
  Future<RouteData> fetchRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  });
}

/// Concrete implementation handling OSRM HTTP requests
class OsrmRoutingRepository implements RoutingRepository {
  final http.Client _httpClient;
  static const Duration _defaultTimeout = Duration(seconds: 15);

  OsrmRoutingRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  Future<RouteData> fetchRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    if (startLat.isNaN ||
        startLng.isNaN ||
        endLat.isNaN ||
        endLng.isNaN ||
        startLat.isInfinite ||
        startLng.isInfinite ||
        endLat.isInfinite ||
        endLng.isInfinite) {
      throw const RoutingException(AppStrings.routeNotFound);
    }

    // Note: OSRM expects coordinates in {longitude},{latitude} order
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson',
    );

    try {
      final response = await _httpClient.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Garibook-Flutter-App/1.0',
        },
      ).timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        if (response.statusCode >= 500 || response.statusCode == 429) {
          throw const RoutingException(AppStrings.routeFetchError);
        }

        try {
          final dynamic errDecoded = jsonDecode(response.body);
          if (errDecoded is Map<String, dynamic>) {
            final code = errDecoded['code'] as String?;
            if (code == 'NoRoute') {
              throw const RoutingException(AppStrings.routeNotFound);
            }
            final message = errDecoded['message'] as String?;
            if (message != null && message.isNotEmpty) {
              throw RoutingException(message);
            }
          }
        } catch (e) {
          if (e is RoutingException) rethrow;
        }

        throw const RoutingException(AppStrings.routeNotFound);
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const RoutingException(AppStrings.routeFetchError);
      }

      return RouteData.fromJson(decoded);
    } on RoutingException {
      rethrow;
    } on SocketException {
      throw const RoutingException(AppStrings.routeFetchError);
    } on http.ClientException {
      throw const RoutingException(AppStrings.routeFetchError);
    } on TimeoutException {
      throw const RoutingException(AppStrings.routeFetchError);
    } on FormatException {
      throw const RoutingException(AppStrings.routeFetchError);
    } catch (_) {
      throw const RoutingException(AppStrings.routeFetchError);
    }
  }
}

/// Provider to inject the routing repository
final routingRepositoryProvider = Provider<RoutingRepository>((ref) {
  final client = http.Client();
  ref.onDispose(() => client.close());
  return OsrmRoutingRepository(httpClient: client);
});
