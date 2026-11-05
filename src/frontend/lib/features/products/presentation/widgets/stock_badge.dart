import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/product.dart';

/// How many units are left, colored when the product needs restocking.
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, background, foreground) = switch (product) {
      Product(isOutOfStock: true) => (
        'Sem estoque',
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      Product(isLowStock: true) => (
        'Estoque baixo: ${Formatters.integer(product.stockQuantity)}',
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      _ => (
        'Estoque: ${Formatters.integer(product.stockQuantity)}',
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: foreground),
        ),
      ),
    );
  }
}
