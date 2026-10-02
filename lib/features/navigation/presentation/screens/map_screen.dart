import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/common_button.dart';
import '../controllers/location_controller.dart';
import '../controllers/navigation_controller.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Watch controllers
    // final locationState = ref.watch(locationControllerProvider);
    // final navigationState = ref.watch(navigationControllerProvider);

    return Scaffold(
      body: Stack(
        children: [
          // TODO: Implement flutter_map widget here
          const Center(child: Text('Map Placeholder')),
          
          // TODO: Extract Dev Banner to a common widget
          const Positioned(
            top: 40,
            left: 20,
            child: Text(AppStrings.devBanner, style: TextStyle(color: Colors.red)),
          ),

          // TODO: Extract Bottom Panel to a widget
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: CommonButton(
                label: AppStrings.start,
                onPressed: () {
                  // ref.read(navigationControllerProvider.notifier).startAnimation();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
