import 'package:flutter/material.dart';

/// Store brand colors, used only on the app's chrome (logo, headers, highlights, icons).
///
/// Charts keep their own validated palette (`ChartPalette`): series colors never come from here.
abstract final class BrandColors {
  /// Teal: the main accent (buttons, selected items).
  static const teal = Color(0xFF3DD6C3);

  /// Indigo: the other end of the brand gradient.
  static const indigo = Color(0xFF6C63FF);

  /// The brand gradient (logo, highlighted cards, totals).
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, indigo],
  );

  /// Soft decorative tints for icons on cards (products, batches, stats), on the dark theme.
  static const darkTints = [
    Color(0xFF3DD6C3), // teal
    Color(0xFF8B83FF), // violet
    Color(0xFFF2B455), // amber
    Color(0xFF5BB8F5), // sky
    Color(0xFFF07FA8), // pink
    Color(0xFF8FD16A), // green
  ];

  /// The same tints, deeper, so icons keep their contrast on the light theme's white cards.
  static const lightTints = [
    Color(0xFF0B8C7D), // teal
    Color(0xFF5E54D9), // violet
    Color(0xFFA86A00), // amber
    Color(0xFF1A78B8), // sky
    Color(0xFFC23F76), // pink
    Color(0xFF3F8A1F), // green
  ];

  /// The tints of the current theme (same order in both: index 1 is always violet).
  static List<Color> tintsOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? lightTints : darkTints;

  /// A tint picked by [key], always the same for the same key (e.g. a category).
  static Color tintFor(BuildContext context, String key) {
    // String.hashCode isn't guaranteed stable between runs; this one is.
    var hash = 0;
    for (final unit in key.toLowerCase().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final tints = tintsOf(context);
    return tints[hash % tints.length];
  }
}

/// The store logo: a rounded square with the brand gradient and a chip icon.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: BrandColors.gradient,
      borderRadius: BorderRadius.circular(size * 0.28),
      boxShadow: [
        BoxShadow(
          color: BrandColors.indigo.withValues(alpha: 0.35),
          blurRadius: size * 0.4,
          offset: Offset(0, size * 0.1),
        ),
      ],
    ),
    child: Icon(
      Icons.memory_rounded,
      size: size * 0.6,
      color: const Color(0xFF0D1220),
    ),
  );
}

/// Background with two soft brand-colored glows, behind the login and the main screens.
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, required this.child, this.strength = 1});

  final Widget child;

  /// 1 = login (more visible); smaller values for content screens.
  final double strength;

  @override
  Widget build(BuildContext context) {
    Widget glow(Color color, Alignment center) => Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: center,
              radius: 1.1,
              colors: [
                color.withValues(alpha: 0.16 * strength),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        children: [
          glow(BrandColors.teal, const Alignment(-1.1, -1.2)),
          glow(BrandColors.indigo, const Alignment(1.2, 1.1)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// An icon in a softly tinted rounded square (list items, stat cards, empty states).
class TintedIcon extends StatelessWidget {
  const TintedIcon(this.icon, {super.key, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Icon(icon, size: size * 0.55, color: color),
  );
}

/// Icon, title, message and an optional action, for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          TintedIcon(icon, color: theme.colorScheme.primary, size: 72),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
