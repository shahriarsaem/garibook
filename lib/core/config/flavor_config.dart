import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_strings.dart';

/// Supported application flavors
enum AppFlavor {
  dev,
  prod,
}

/// Flavor configuration managing environment-specific settings:
/// app title, routing base URL, and DEV banner visibility.
class FlavorConfig {
  final AppFlavor flavor;
  final String appName;
  final String routingBaseUrl;
  final bool showDevBanner;

  const FlavorConfig({
    required this.flavor,
    required this.appName,
    required this.routingBaseUrl,
    required this.showDevBanner,
  });

  static FlavorConfig? _instance;

  static FlavorConfig get instance {
    if (_instance == null) {
      initialize();
    }
    return _instance!;
  }

  /// Initializes flavor configuration from Flutter's native `appFlavor`
  /// or explicit parameter.
  static void initialize({AppFlavor? flavor}) {
    final resolved = flavor ??
        (appFlavor == 'dev' ? AppFlavor.dev : AppFlavor.prod);

    switch (resolved) {
      case AppFlavor.dev:
        _instance = const FlavorConfig(
          flavor: AppFlavor.dev,
          appName: AppStrings.appNameDev,
          routingBaseUrl: 'https://router.project-osrm.org',
          showDevBanner: true,
        );
        break;
      case AppFlavor.prod:
        _instance = const FlavorConfig(
          flavor: AppFlavor.prod,
          appName: AppStrings.appNameProd,
          routingBaseUrl: 'https://router.project-osrm.org',
          showDevBanner: false,
        );
        break;
    }
  }
}

/// Provider to expose the active FlavorConfig across Riverpod controllers and UI
final flavorConfigProvider = Provider<FlavorConfig>((ref) {
  return FlavorConfig.instance;
});
