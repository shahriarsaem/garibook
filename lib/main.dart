import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'features/navigation/presentation/screens/map_screen.dart';

void main() {
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
      title: AppStrings.appName,
      theme: AppTheme.lightTheme,
      home: const MapScreen(),
    );
  }
}
