import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/common_button.dart';
import '../controllers/navigation_controller.dart';

/// Navigation dashboard overlay showing live trip progress, remaining distance & ETA,
/// speed toggles (1x, 2x, 5x), pause/resume controls, and arrival celebration.
class NavigationDashboard extends StatelessWidget {
  final NavigationState state;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final ValueChanged<int> onSpeedChanged;
  final VoidCallback onDone;

  const NavigationDashboard({
    super.key,
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onSpeedChanged,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: state.isCompleted
            ? _buildCompletionContent(context, theme)
            : _buildNavigatingContent(context, theme),
      ),
    );
  }

  /// Celebratory banner shown upon reaching the destination
  Widget _buildCompletionContent(BuildContext context, ThemeData theme) {
    final route = state.route;

    return Padding(
      key: const ValueKey('completion_view'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 36,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.destinationReached,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.tripCompleted,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (route != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.route_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    route.formattedDistance,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    route.formattedDuration,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: CommonButton(
              onPressed: onDone,
              label: AppStrings.done,
              icon: Icons.done_all_rounded,
            ),
          ),
        ],
      ),
    );
  }

  /// Live navigation HUD with metrics, speed toggles, and pause/cancel controls
  Widget _buildNavigatingContent(BuildContext context, ThemeData theme) {
    final isPaused = state.isPaused;

    return Padding(
      key: const ValueKey('navigating_view'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: Status badge & Speed multiplier selector ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Navigation Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isPaused ? Colors.amber : Colors.green)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isPaused ? Colors.amber : Colors.green)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isPaused ? Colors.amber : Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPaused ? AppStrings.paused : AppStrings.navigating,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isPaused
                            ? Colors.amber.shade800
                            : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              // Speed Multiplier Pills (1x, 2x, 5x)
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSpeedChip(context, theme, multiplier: 1, label: AppStrings.speed1x),
                    const SizedBox(width: 2),
                    _buildSpeedChip(context, theme, multiplier: 2, label: AppStrings.speed2x),
                    const SizedBox(width: 2),
                    _buildSpeedChip(context, theme, multiplier: 5, label: AppStrings.speed5x),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Progress Bar ──
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.progressFraction,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),

          const SizedBox(height: 14),

          // ── Live Metrics: Remaining Distance & ETA ──
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  theme,
                  icon: Icons.straighten_rounded,
                  value: state.formattedRemainingDistance,
                  label: AppStrings.remaining,
                ),
              ),
              Container(
                height: 36,
                width: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _buildMetricTile(
                  context,
                  theme,
                  icon: Icons.timer_outlined,
                  value: state.formattedRemainingDuration,
                  label: AppStrings.eta,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Action Controls (Pause/Resume & Cancel) ──
          Row(
            children: [
              // Pause / Resume Button
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: isPaused ? onResume : onPause,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaused
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondaryContainer,
                    foregroundColor: isPaused
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSecondaryContainer,
                    elevation: isPaused ? 2 : 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 20,
                  ),
                  label: Text(
                    isPaused ? AppStrings.resume : AppStrings.pause,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Cancel Button
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(
                      color: theme.colorScheme.error.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(
                    AppStrings.cancel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedChip(
    BuildContext context,
    ThemeData theme, {
    required int multiplier,
    required String label,
  }) {
    final isSelected = state.speedMultiplier == multiplier;
    return InkWell(
      onTap: () => onSpeedChanged(multiplier),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 22,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.isNotEmpty ? value : '--',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
