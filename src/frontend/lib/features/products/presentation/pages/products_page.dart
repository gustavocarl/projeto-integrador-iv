import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/product.dart';
import '../controllers/products_controller.dart';
import '../../../../shared/widgets/brand.dart';
import '../widgets/product_avatar.dart';
import '../widgets/stock_badge.dart';
import 'product_form_page.dart';

/// The product catalog: search, filter by category, show inactive ones, open to edit.
/// Shown inside the main menu, which provides the app bar.
class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends BaseState<ProductsPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  ProductsController get _controller =>
      ref.read(productsControllerProvider.notifier);

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _setFilter(ProductFilter filter) {
    setState(() {}); // the chips read the filter from the controller
    runSafely(() => _controller.setFilter(filter));
  }

  void _onSearchChanged(String text) {
    setState(() {}); // shows/hides the clear button
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _setFilter(_controller.filter.copyWith(search: text.trim())),
    );
  }

  void _clearSearch() {
    _search.clear();
    _onSearchChanged('');
  }

  Future<void> _open([Product? product]) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ProductFormPage(product: product)),
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final products = ref.watch(productsControllerProvider);
    final filter = ref.watch(productsControllerProvider.notifier).filter;
    final categories = ref.watch(productCategoriesProvider).value ?? const [];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        // The main menu keeps several screens alive, each with its own button:
        // without a tag of its own they clash when a page is pushed.
        heroTag: null,
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Novo produto'),
      ),
      body: RefreshIndicator(
        onRefresh: _controller.reload,
        child: ListView(
          // Bottom room so the floating button doesn't cover the last product.
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Nome ou SKU',
                isDense: true,
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        icon: const Icon(Icons.close),
                        onPressed: _clearSearch,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (categories.isNotEmpty)
                  _CategoryMenu(
                    categories: categories,
                    selected: filter.category,
                    onSelected: (category) =>
                        _setFilter(filter.copyWith(category: () => category)),
                  ),
                FilterChip(
                  label: const Text('Mostrar inativos'),
                  selected: filter.includeInactive,
                  onSelected: (value) =>
                      _setFilter(filter.copyWith(includeInactive: value)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...switch (products) {
              AsyncValue(:final value?) when value.isEmpty => [
                _EmptyState(filtered: !filter.isEmpty),
              ],
              AsyncValue(:final value?) => [
                _Overview(products: value),
                const SizedBox(height: 16),
                Text(
                  _summary(value),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final product in value)
                  _ProductTile(product: product, onTap: () => _open(product)),
              ],
              AsyncError(:final error) => [
                Text(
                  error is Failure
                      ? error.generalMessages.join('\n')
                      : 'Não foi possível carregar os produtos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => ref.invalidate(productsControllerProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ),
              ],
              _ => [
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }

  static String _summary(List<Product> products) {
    final count = products.length == 1
        ? '1 produto'
        : '${Formatters.integer(products.length)} produtos';
    final low = products.where((p) => p.isActive && p.isLowStock).length;
    return switch (low) {
      0 => count,
      1 => '$count · 1 precisa de reposição',
      _ => '$count · $low precisam de reposição',
    };
  }
}

class _CategoryMenu extends StatelessWidget {
  const _CategoryMenu({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: () => onSelected(null),
          child: const Text('Todas as categorias'),
        ),
        for (final c in categories)
          MenuItemButton(onPressed: () => onSelected(c), child: Text(c)),
      ],
      builder: (context, controller, _) => FilterChip(
        avatar: const Icon(Icons.category_outlined, size: 18),
        label: Text(selected ?? 'Categoria'),
        selected: selected != null,
        showCheckmark: false,
        onSelected: (_) =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final p = product;

    return Opacity(
      opacity: p.isActive ? 1 : 0.6,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            child: Row(
              children: [
                ProductAvatar(
                  name: p.name,
                  category: p.category,
                  imageUrl: p.imageUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        [
                          p.sku,
                          ?p.category,
                          if (!p.isActive) 'Inativo',
                        ].join(' · '),
                        style: muted,
                      ),
                      const SizedBox(height: 6),
                      StockBadge(product: p),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.currency(p.salePrice),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (p.margin != null)
                      Text(
                        'margem ${Formatters.percent(p.margin!)}',
                        style: muted,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: filtered ? Icons.search_off_rounded : Icons.inventory_2_outlined,
    title: filtered
        ? 'Nenhum produto encontrado.'
        : 'Nenhum produto cadastrado.',
    message: filtered ? null : 'Cadastre os produtos para vendê-los no caixa.',
  );
}

/// Three numbers about the listed products: how many, how many need restocking, stock value.
class _Overview extends StatelessWidget {
  const _Overview({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final active = products.where((p) => p.isActive).toList();
    final restock = active.where((p) => p.isLowStock).length;
    final stockValue = active.fold<double>(
      0,
      (sum, p) => sum + p.salePrice * p.stockQuantity,
    );
    final colors = Theme.of(context).colorScheme;
    final tints = BrandColors.tintsOf(context);
    final tiles = [
      _OverviewTile(
        icon: Icons.inventory_2_outlined,
        color: tints[0],
        label: 'Ativos',
        value: Formatters.integer(active.length),
      ),
      _OverviewTile(
        icon: Icons.warning_amber_rounded,
        color: restock == 0 ? colors.onSurfaceVariant : colors.tertiary,
        label: 'Repor',
        value: Formatters.integer(restock),
      ),
      _OverviewTile(
        icon: Icons.payments_outlined,
        color: tints[1],
        label: 'Estoque',
        value: Formatters.compactCurrency(stockValue),
        tooltip:
            'Valor do estoque ativo pelo preço de venda: '
            '${Formatters.currency(stockValue)}',
      ),
    ];
    return Row(
      children: [
        for (final (i, tile) in tiles.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: tile),
        ],
      ],
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            TintedIcon(icon, color: color, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: theme.textTheme.titleMedium),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return tooltip == null ? card : Tooltip(message: tooltip, child: card);
  }
}
