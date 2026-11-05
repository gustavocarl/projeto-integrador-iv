import 'package:flutter/material.dart';

import '../../../../shared/widgets/brand.dart';

/// A headline number with an optional icon. Prefer [StatGrid] to lay several out.
///
/// [highlight] marks the main number with a soft brand gradient.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.highlight = false,
    this.icon,
    this.width,
  });

  final String label;
  final String value;
  final String? caption;
  final bool highlight;
  final IconData? icon;

  /// Fixed width (grid); null = at least 160 and grows with the content.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: width == null
          ? const BoxConstraints(minWidth: 160)
          : BoxConstraints.tightFor(width: width),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: highlight
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      BrandColors.teal.withValues(alpha: 0.22),
                      BrandColors.indigo.withValues(alpha: 0.16),
                    ],
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  // The card may have unbounded width (Wrap): no Expanded here.
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stat cards that wrap on wide screens and form a 2-column grid on narrow ones,
/// so they never wrap unevenly.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.stats});

  final List<StatCard> stats;

  static const _spacing = 12.0;
  static const _gridBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth < _gridBreakpoint
          ? (constraints.maxWidth - _spacing) / 2
          : null;
      return Wrap(
        spacing: _spacing,
        runSpacing: _spacing,
        children: [
          for (final s in stats)
            StatCard(
              label: s.label,
              value: s.value,
              caption: s.caption,
              highlight: s.highlight,
              icon: s.icon,
              width: width,
            ),
        ],
      );
    },
  );
}
