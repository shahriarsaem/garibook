import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/common_button.dart';
import '../controllers/location_controller.dart';

class LocationStatusOverlay extends StatelessWidget {
  final LocationState state;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  const LocationStatusOverlay({
    super.key,
    required this.state,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (state.permissionStatus == LocationPermissionStatus.permanentlyDenied) {
      return _buildCard(
        context: context,
        icon: Icons.location_off_rounded,
        title: AppStrings.permissionDenied,
        message: AppStrings.permissionPermanentlyDenied,
        action: CommonButton(
          label: AppStrings.openSettings,
          icon: Icons.settings,
          onPressed: onOpenSettings,
        ),
      );
    }

    if (state.permissionStatus == LocationPermissionStatus.denied) {
      return _buildCard(
        context: context,
        icon: Icons.location_disabled_rounded,
        title: AppStrings.permissionDenied,
        message: AppStrings.permissionDenied,
        action: CommonButton(
          label: AppStrings.grantPermission,
          icon: Icons.near_me,
          onPressed: onRequestPermission,
        ),
      );
    }

    if (!state.isServiceEnabled) {
      return _buildCard(
        context: context,
        icon: Icons.gps_off_rounded,
        title: AppStrings.locationServiceDisabled,
        message: AppStrings.locationServiceDisabled,
        action: CommonButton(
          label: AppStrings.retry,
          icon: Icons.refresh,
          onPressed: onRetry,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
    required Widget action,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: theme.colorScheme.error,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            action,
          ],
        ),
      ),
    );
  }
}
