import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/brand.dart';
import '../../../products/presentation/widgets/product_avatar.dart';
import '../../../../core/errors/base_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/parsers.dart';
import '../../../../shared/widgets/suggestion_field.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/controllers/products_controller.dart';
import '../../../products/presentation/controllers/restock_providers.dart';
import '../../domain/entities/sale.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../controllers/sales_imports_controller.dart';

/// The checkout: picks catalog products into a cart and sells them all at once.
/// The sale goes into the month's batch and takes the products out of stock.
/// Shown inside the main menu, which provides the app bar.
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CartLine {
  _CartLine(this.product)
    : quantity = TextEditingController(text: '1'),
      price = TextEditingController(text: Formatters.amount(product.salePrice));

  final Product product;
  final TextEditingController quantity;
  final TextEditingController price;

  int? get quantityValue => Parsers.integer(quantity.text);
  double? get priceValue => Parsers.decimal(price.text);

  /// The typed price is below the product's cost (compared in cents, as the backend):
  /// the sale would lose money. Never without a cost or a valid price.
  bool get isBelowCost {
    final cost = product.costPrice;
    final value = priceValue;
    return cost != null &&
        value != null &&
        (value * 100).round() < (cost * 100).round();
  }

  /// Largest discount on the product's price (business rule, same as the backend).
  static const maxDiscount = 0.15;

  /// Lowest accepted price, in cents: the sale price minus [maxDiscount].
  int get _minimumCents =>
      (product.salePrice * (1 - maxDiscount) * 100).round();

  /// The typed price gives more than [maxDiscount] off the product's price.
  bool get isOverMaxDiscount {
    final value = priceValue;
    return value != null && (value * 100).round() < _minimumCents;
  }

  /// "Desconto de 10%": shown while the typed price is below the product's price.
  String? get discountHint {
    final value = priceValue;
    if (value == null || value >= product.salePrice || product.salePrice <= 0) {
      return null;
    }
    return 'Desconto de ${Formatters.percent(1 - value / product.salePrice)} '
        '(máximo ${Formatters.percent(maxDiscount)})';
  }

  /// Same text as the backend's error on `items[i].unitPrice`.
  String get maxDiscountMessage =>
      'O desconto não pode passar de 15% do preço do produto: o mínimo é '
      '${Formatters.currency(_minimumCents / 100)}.';

  /// The first rule the typed price breaks (cost, then discount), as the backend checks.
  String? get priceRuleMessage => isBelowCost
      ? belowCostMessage
      : isOverMaxDiscount
      ? maxDiscountMessage
      : null;

  /// Same text as the backend's error on `items[i].unitPrice`.
  String get belowCostMessage =>
      'O preço não pode ser menor que o custo '
      '(${Formatters.currency(product.costPrice ?? 0)}): a venda daria prejuízo.';

  void dispose() {
    quantity.dispose();
    price.dispose();
  }
}

class _CheckoutPageState extends BaseState<CheckoutPage> {
  static const maxWidth = 720.0;

  final _lines = <_CartLine>[];
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  SalesChannel _channel = SalesChannel.inPerson;
  final _marketplace = TextEditingController();

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _marketplace.dispose();
    super.dispose();
  }

  /// Rebuilds the totals and the +/- buttons. Error keys point to line positions
  /// ("items[2].quantity"), so any change to the cart makes them stale.
  void _cartChanged() {
    clearFailure();
    setState(() {});
  }

  void _add(Product product) {
    final existing = _lines
        .where((l) => l.product.id == product.id)
        .firstOrNull;
    if (existing == null) {
      _lines.add(_CartLine(product));
    } else {
      final next = (existing.quantityValue ?? 0) + 1;
      existing.quantity.text = '${next.clamp(1, product.stockQuantity)}';
    }
    _cartChanged();
  }

  void _remove(_CartLine line) {
    _lines.remove(line);
    line.dispose();
    _cartChanged();
  }

  void _step(_CartLine line, int delta) {
    final next = (line.quantityValue ?? 0) + delta;
    if (next < 1 || next > line.product.stockQuantity) return;
    line.quantity.text = '$next';
    _cartChanged();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// The user's "Avisar sobre reposição de estoque" preference.
  bool _notifyRestock = false;

  Future<void> _finish() async {
    final input = CheckoutInput(
      date: _date,
      channel: _channel,
      marketplace:
          _channel == SalesChannel.online && _marketplace.text.trim().isNotEmpty
          ? _marketplace.text.trim()
          : null,
      lines: [
        for (final line in _lines)
          CheckoutLine(
            productId: line.product.id,
            quantity: line.quantityValue,
            unitPrice: line.priceValue,
          ),
      ],
    );

    final result = await runSafely(
      () => ref.read(salesRepositoryProvider).checkout(input),
    );
    if (result == null || !mounted) return;
    salesBatchSaved(ref, result.salesImport);

    final restock = _notifyRestock
        ? productsToRestock([
            for (final line in _lines)
              (product: line.product, quantity: line.quantityValue ?? 0),
          ])
        : const <({Product product, int stockLeft})>[];

    // Stock changed: the catalog and the checkout's product list are stale.
    ref.invalidate(sellableProductsProvider);
    // Only when the products screen was opened (a checkout-only user doesn't have it).
    if (ref.exists(productsControllerProvider)) {
      ref.read(productsControllerProvider.notifier).reload();
    }

    for (final line in _lines) {
      line.dispose();
    }
    setState(_lines.clear);

    final profit = result.profit == null
        ? ''
        : ' (lucro de ${Formatters.currency(result.profit!)})';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // Longer when there is a restock warning to read.
          duration: Duration(seconds: restock.isEmpty ? 4 : 8),
          content: Text(
            'Venda de ${Formatters.currency(result.total)}$profit registrada em '
            '"${result.salesImport.fileName}".'
            '${restock.isEmpty ? '' : '\n${_restockMessage(restock)}'}',
          ),
        ),
      );
  }

  /// "Repor estoque: Mouse sem fio (restam 2), Teclado (sem estoque)."
  static String _restockMessage(
    List<({Product product, int stockLeft})> restock,
  ) {
    final items = [
      for (final r in restock)
        '${r.product.name} '
            '(${r.stockLeft <= 0 ? 'sem estoque' : 'restam ${Formatters.integer(r.stockLeft)}'})',
    ];
    return 'Repor estoque: ${items.join(', ')}.';
  }

  @override
  Widget build(BuildContext context) {
    // Watched so the preference is loaded by the time a sale ends.
    _notifyRestock = ref.watch(notifyRestockProvider);
    final theme = Theme.of(context);
    final catalog = ref.watch(sellableProductsProvider);

    return Scaffold(
      bottomNavigationBar: _TotalsBar(
        totals: _Totals.of(_lines),
        isLoading: isLoading,
        onFinish: _finish,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProductSearch(
                products: catalog.value ?? const [],
                isLoading: catalog.isLoading,
                errorText: catalog.hasError
                    ? 'Não foi possível carregar os produtos.'
                    : null,
                onRetry: () => ref.invalidate(sellableProductsProvider),
                onSelected: _add,
              ),
              if (fieldError('items') case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 12),
                  child: Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (_lines.isEmpty)
                const _EmptyCart()
              else
                for (final (i, line) in _lines.indexed)
                  _CartLineCard(
                    line: line,
                    quantityError: fieldError('items[$i].quantity'),
                    priceError:
                        fieldError('items[$i].unitPrice') ??
                        line.priceRuleMessage,
                    productError: fieldError('items[$i].productId'),
                    onChanged: _cartChanged,
                    onStep: (delta) => _step(line, delta),
                    onRemove: () => _remove(line),
                  ),
              const SizedBox(height: 16),
              Text('Venda', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Data da venda',
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                    helperText:
                        'Entra no lote "Vendas - ${Formatters.monthYear(_date)}"',
                    errorText: fieldError('date'),
                  ),
                  child: Text(Formatters.date(_date)),
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<SalesChannel>(
                segments: const [
                  ButtonSegment(
                    value: SalesChannel.inPerson,
                    icon: Icon(Icons.storefront_outlined),
                    label: Text('Presencial'),
                  ),
                  ButtonSegment(
                    value: SalesChannel.online,
                    icon: Icon(Icons.language),
                    label: Text('Online'),
                  ),
                ],
                selected: {_channel},
                onSelectionChanged: (s) => setState(() => _channel = s.first),
              ),
              if (fieldError('channel') case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              if (_channel == SalesChannel.online) ...[
                const SizedBox(height: 16),
                SuggestionField(
                  controller: _marketplace,
                  suggestions:
                      ref.watch(marketplacesProvider).value ?? const [],
                  labelText: 'Marketplace (opcional)',
                  helperText: 'Vazio = loja virtual própria',
                  errorText: fieldError('marketplace'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search box over the active products; picking one adds it to the cart.
class _ProductSearch extends StatelessWidget {
  const _ProductSearch({
    required this.products,
    required this.isLoading,
    required this.errorText,
    required this.onRetry,
    required this.onSelected,
  });

  final List<Product> products;
  final bool isLoading;
  final String? errorText;
  final VoidCallback onRetry;
  final ValueChanged<Product> onSelected;

  static const _maxOptions = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RawAutocomplete<Product>(
      displayStringForOption: (_) => '',
      optionsBuilder: (value) {
        final typed = value.text.trim().toLowerCase();
        if (typed.isEmpty) return const [];
        return products
            .where(
              (p) =>
                  p.name.toLowerCase().contains(typed) ||
                  p.sku.toLowerCase().contains(typed),
            )
            .take(_maxOptions);
      },
      onSelected: (product) {
        if (!product.isOutOfStock) onSelected(product);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
          TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: 'Adicionar produto',
              hintText: 'Nome ou SKU',
              helperText: isLoading ? 'Carregando produtos...' : null,
              errorText: errorText,
              suffixIcon: errorText == null
                  ? null
                  : IconButton(
                      tooltip: 'Tentar novamente',
                      icon: const Icon(Icons.refresh),
                      onPressed: onRetry,
                    ),
            ),
          ),
      optionsViewBuilder: (context, onSelect, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          color: theme.colorScheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320, maxWidth: 560),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final p in options)
                  ListTile(
                    enabled: !p.isOutOfStock,
                    leading: ProductAvatar(
                      name: p.name,
                      category: p.category,
                      imageUrl: p.imageUrl,
                      size: 36,
                    ),
                    title: Text(p.name),
                    subtitle: Text(
                      p.isOutOfStock
                          ? '${p.sku} · sem estoque'
                          : '${p.sku} · ${Formatters.integer(p.stockQuantity)} em estoque',
                    ),
                    trailing: Text(
                      Formatters.currency(p.salePrice),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    onTap: () => onSelect(p),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.quantityError,
    required this.priceError,
    required this.productError,
    required this.onChanged,
    required this.onStep,
    required this.onRemove,
  });

  final _CartLine line;
  final String? quantityError;
  final String? priceError;
  final String? productError;
  final VoidCallback onChanged;
  final ValueChanged<int> onStep;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = line.product;
    final quantity = line.quantityValue ?? 0;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProductAvatar(
                  name: p.name,
                  category: p.category,
                  imageUrl: p.imageUrl,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: theme.textTheme.titleSmall),
                      Text(
                        '${p.sku} · ${Formatters.integer(p.stockQuantity)} em estoque',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remover do carrinho',
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
              ],
            ),
            if (productError != null)
              Text(
                productError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Menos um',
                    onPressed: quantity > 1 ? () => onStep(-1) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: line.quantity,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (_) => onChanged(),
                      decoration: InputDecoration(
                        isDense: true,
                        // Error text goes below the row: the field is too narrow.
                        error: quantityError == null
                            ? null
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Mais um',
                    onPressed: quantity < p.stockQuantity
                        ? () => onStep(1)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: line.price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => onChanged(),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Preço unitário',
                        prefixText: r'R$ ',
                        errorText: priceError,
                        errorMaxLines: 3,
                        helperText: line.discountHint,
                        helperMaxLines: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (quantityError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  quantityError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Total of the cart, profit when the costs are known, and the finish button.
class _TotalsBar extends StatelessWidget {
  const _TotalsBar({
    required this.totals,
    required this.isLoading,
    required this.onFinish,
  });

  final _Totals totals;
  final bool isLoading;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        // Lined up with the cart column on wide screens.
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _CheckoutPageState.maxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          totals.items == 1
                              ? '1 item'
                              : '${Formatters.integer(totals.items)} itens',
                          style: theme.textTheme.labelMedium,
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Formatters.currency(totals.total),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: totals.lines == 0
                                  ? null
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        if (totals.profitText case final text?)
                          Text(
                            text,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: isLoading || totals.lines == 0 ? null : onFinish,
                    icon: isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.point_of_sale),
                    label: const Text('Finalizar venda'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Totals {
  const _Totals(this.lines, this.items, this.total, this.profitText);

  final int lines;
  final int items;
  final double total;

  /// Null when no product in the cart has a cost price.
  final String? profitText;

  static _Totals of(List<_CartLine> lines) {
    var items = 0;
    var total = 0.0;
    var profit = 0.0;
    var withCost = 0;
    for (final line in lines) {
      final quantity = line.quantityValue ?? 0;
      final price = line.priceValue ?? 0;
      items += quantity;
      total += quantity * price;
      if (line.product.costPrice case final cost?) {
        profit += quantity * (price - cost);
        withCost++;
      }
    }

    final profitText = withCost == 0
        ? null
        : withCost == lines.length
        ? 'Lucro estimado: ${Formatters.currency(profit)}'
        : 'Lucro dos itens com custo: ${Formatters.currency(profit)}';
    return _Totals(lines.length, items, total, profitText);
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.shopping_cart_outlined,
    title: 'Carrinho vazio.',
    message: 'Busque os produtos pelo nome ou SKU para adicioná-los.',
  );
}
