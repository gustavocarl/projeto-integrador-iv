import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/sale.dart';
import '../controllers/sales_imports_controller.dart';
import '../pages/manual_sale_page.dart';

/// The sales of a batch: search, add a sale typed in, remove a single sale.
class SalesTab extends ConsumerStatefulWidget {
  const SalesTab({super.key, required this.importId});

  final String importId;

  @override
  ConsumerState<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends BaseState<SalesTab> {
  final _search = TextEditingController();
  Timer? _debounce;

  BatchSalesController get _controller =>
      ref.read(batchSalesProvider(widget.importId).notifier);

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    setState(() {}); // shows/hides the clear button
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _controller.search(text),
    );
  }

  void _clearSearch() {
    _search.clear();
    _onSearchChanged('');
  }

  Future<void> _add() async {
    final result = await Navigator.of(context).push<ManualSaleResult>(
      MaterialPageRoute(
        builder: (_) => ManualSalePage(importId: widget.importId),
      ),
    );
    if (result != null) _showMessage('Venda lançada.');
  }

  Future<void> _delete(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir venda?'),
        content: Text(
          '"${sale.productName}" de ${Formatters.date(sale.date)}, '
          '${Formatters.currency(sale.totalPrice)}. Os totais e as análises do lote '
          'serão recalculados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final removed = await runSafely(() async {
      await _controller.remove(sale.id);
      return true;
    });
    if (removed == true) _showMessage('Venda excluída.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sales = ref.watch(batchSalesProvider(widget.importId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Produto ou SKU',
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
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Lançar venda'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...switch (sales) {
          AsyncData(:final value) when value.items.isEmpty => [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                value.search.isEmpty
                    ? 'Este lote não tem vendas.'
                    : 'Nenhuma venda encontrada para "${value.search}".',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
          AsyncData(:final value) => [
            Text(
              value.totalCount == 1
                  ? '1 venda'
                  : '${Formatters.integer(value.totalCount)} vendas',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final sale in value.items)
              _SaleTile(
                sale: sale,
                onDelete: isLoading ? null : () => _delete(sale),
              ),
            if (value.hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: isLoading
                      ? null
                      : () => runSafely(_controller.loadMore),
                  child: Text(
                    'Carregar mais (${Formatters.integer(value.totalCount - value.items.length)} restantes)',
                  ),
                ),
              ),
          ],
          AsyncError(:final error) => [
            Text(
              error is Failure
                  ? error.generalMessages.join('\n')
                  : 'Não foi possível carregar as vendas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(batchSalesProvider(widget.importId)),
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
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale, required this.onDelete});

  final Sale sale;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final where = switch (sale.channel) {
      SalesChannel.inPerson => 'Presencial',
      SalesChannel.online => 'Online · ${sale.marketplace ?? 'loja própria'}',
    };
    final origin = sale.isCheckout
        ? 'Vendida no caixa por ${sale.createdBy}'
        : sale.isManual
        ? 'Lançada por ${sale.createdBy}'
        : 'Linha ${sale.rowNumber} da planilha';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.sku == null
                        ? sale.productName
                        : '${sale.productName} · ${sale.sku}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${Formatters.date(sale.date)} · ${Formatters.integer(sale.quantity)} × '
                    '${Formatters.currency(sale.unitPrice)} · $where',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(origin, style: muted),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Formatters.currency(sale.totalPrice),
              style: theme.textTheme.titleSmall,
            ),
            IconButton(
              tooltip: 'Excluir venda',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
