import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/flavor_config.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/presentation/screens/map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.initialize();

  runApp(
    const ProviderScope(
      child: RouteApp(),
    ),
  );
}

class RouteApp extends StatelessWidget {
  const RouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: FlavorConfig.instance.appName,
      theme: AppTheme.lightTheme,
      home: const MapScreen(),
    );
  }
}
