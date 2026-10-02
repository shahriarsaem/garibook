import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract interface for routing operations
abstract class RoutingRepository {
  Future<dynamic> fetchRoute(double startLat, double startLng, double endLat, double endLng);
}

/// Concrete implementation handling OSRM HTTP requests
class OsrmRoutingRepository implements RoutingRepository {
  @override
  Future<dynamic> fetchRoute(double startLat, double startLng, double endLat, double endLng) async {
    // TODO: Implement HTTP call to OSRM and polyline parsing
    throw UnimplementedError();
  }
}

/// Provider to inject the routing repository
final routingRepositoryProvider = Provider<RoutingRepository>((ref) {
  return OsrmRoutingRepository();
});
