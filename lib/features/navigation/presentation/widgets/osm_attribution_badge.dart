import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';

/// Clean, theme-aware attribution badge complying with OpenStreetMap tile usage guidelines
class OsmAttributionBadge extends StatelessWidget {
  const OsmAttributionBadge({super.key});

  void _showAttributionDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.map_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'Map Data Attribution',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Map tiles and geodata provided by OpenStreetMap.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.osmAttribution,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.osmAttributionUrl,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAttributionDialog(context),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.osmAttribution,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
