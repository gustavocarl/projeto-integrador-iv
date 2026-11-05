import 'package:flutter/painting.dart';

/// Chart colors, the same in both themes.
///
/// Categorical slots are assigned in this fixed order and follow the entity (never its rank).
/// Validated against the dark card surface (#1a1b21): lightness band, chroma, color-blind
/// separation (ΔE 26.8) and 3:1 contrast all pass. On the light theme's white cards both
/// still pass 3:1 (blue ≈ 3.6:1, orange ≈ 3.9:1).
abstract final class ChartPalette {
  /// Categorical slots: 1 blue, 2 orange.
  static const categorical = [Color(0xFF3987E5), Color(0xFFD95926)];

  /// Single hue for magnitude comparisons (bar length carries the value, not the color).
  static const magnitude = Color(0xFF3987E5);

  /// 2px gap between adjacent fills, in the surface color.
  static const segmentGap = 2.0;
  static const markRadius = Radius.circular(4);
}
