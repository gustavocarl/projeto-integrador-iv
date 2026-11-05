import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/parsers.dart';
import '../../../../shared/widgets/suggestion_field.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sales_import.dart';
import '../controllers/sales_imports_controller.dart';
import '../widgets/sales_spreadsheet_dialog.dart';

/// Form to type in a sale. Pops with the [ManualSaleResult] when saved.
///
/// Validation is the backend's: the screen sends what was typed (null when empty or
/// unreadable) and shows each error under its field.
class ManualSalePage extends ConsumerStatefulWidget {
  const ManualSalePage({super.key, this.importId});

  /// Batch preselected when the form is opened from a batch; null = new manual batch.
  final String? importId;

  @override
  ConsumerState<ManualSalePage> createState() => _ManualSalePageState();
}

class _ManualSalePageState extends BaseState<ManualSalePage>
    with SalesSpreadsheetDownload {
  /// Dropdown value for "create a new manual batch".
  static const _newBatch = '';

  late String _batch = widget.importId ?? _newBatch;
  final _batchName = TextEditingController(
    text: 'Vendas manuais - ${Formatters.monthYear(DateTime.now())}',
  );
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  final _product = TextEditingController();
  final _productFocus = FocusNode();
  final _sku = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();
  SalesChannel? _channel;
  final _marketplace = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _batchName,
      _product,
      _sku,
      _quantity,
      _price,
      _marketplace,
    ]) {
      c.dispose();
    }
    _productFocus.dispose();
    super.dispose();
  }

  static String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

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

  Future<void> _save({required bool another}) async {
    final isNew = _batch == _newBatch;
    final input = ManualSaleInput(
      importId: isNew ? null : _batch,
      importName: isNew ? _text(_batchName) : null,
      date: _date,
      productName: _text(_product),
      sku: _text(_sku),
      quantity: Parsers.integer(_quantity.text),
      unitPrice: Parsers.decimal(_price.text),
      channel: _channel,
      marketplace: _channel == SalesChannel.online ? _text(_marketplace) : null,
    );

    final result = await runSafely(
      () => ref
          .read(salesImportsControllerProvider.notifier)
          .createManualSale(input),
    );
    if (result == null || !mounted) return;

    if (!another) {
      Navigator.of(context).pop(result);
      return;
    }

    // Keep batch, date and channel: the next sale is usually from the same day and place.
    setState(() => _batch = result.salesImport.id);
    _product.clear();
    _sku.clear();
    _quantity.text = '1';
    _price.clear();
    _productFocus.requestFocus();
    showSaleSavedMessage(
      'Venda salva em "${result.salesImport.fileName}". Lance a próxima.',
      result.sale.date,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batches = ref.watch(salesImportsControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançar venda'),
        actions: [
          if (canExportSales)
            IconButton(
              tooltip: 'Gerar planilha de vendas',
              onPressed: isLoading
                  ? null
                  : () => downloadSalesSpreadsheet(_date),
              icon: const Icon(Icons.table_view_outlined),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _batchField(batches),
              if (_batch == _newBatch) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _batchName,
                  decoration: InputDecoration(
                    labelText: 'Nome do novo lote',
                    errorText: fieldError('importName'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Data da venda',
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                    errorText: fieldError('date'),
                  ),
                  child: Text(Formatters.date(_date)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _product,
                focusNode: _productFocus,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Produto',
                  errorText: fieldError('productName'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sku,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'SKU (opcional)',
                  errorText: fieldError('sku'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantidade',
                        errorText: fieldError('quantity'),
                        errorMaxLines: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Preço unitário',
                        prefixText: r'R$ ',
                        hintText: '0,00',
                        errorText: fieldError('unitPrice'),
                        errorMaxLines: 2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: Listenable.merge([_quantity, _price]),
                builder: (context, _) {
                  final quantity = Parsers.integer(_quantity.text);
                  final price = Parsers.decimal(_price.text);
                  return Text(
                    quantity == null || price == null
                        ? 'Total: -'
                        : 'Total: ${Formatters.currency(quantity * price)}',
                    style: theme.textTheme.titleSmall,
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Canal', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
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
                selected: {?_channel},
                emptySelectionAllowed: true,
                onSelectionChanged: (s) =>
                    setState(() => _channel = s.isEmpty ? null : s.first),
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
                _marketplaceField(),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: isLoading ? null : () => _save(another: false),
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Salvar venda'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isLoading ? null : () => _save(another: true),
                icon: const Icon(Icons.add),
                label: const Text('Salvar e lançar outra'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _batchField(List<SalesImport>? batches) {
    // The preselected batch must be in the list before the dropdown can show it.
    if (batches == null ||
        (_batch != _newBatch && !batches.any((b) => b.id == _batch))) {
      return const InputDecorator(
        decoration: InputDecoration(labelText: 'Lote'),
        child: Text('Carregando lotes...'),
      );
    }

    return DropdownButtonFormField<String>(
      // A new key resets the field when the batch changes in code (after "lançar outra").
      key: ValueKey(_batch),
      initialValue: _batch,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Lote',
        helperText: 'A venda entra nas análises deste lote',
        errorText: fieldError('importId'),
      ),
      items: [
        const DropdownMenuItem(
          value: _newBatch,
          child: Text('+ Novo lote manual'),
        ),
        for (final b in batches)
          DropdownMenuItem(
            value: b.id,
            child: Text(b.fileName, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => setState(() => _batch = value ?? _newBatch),
    );
  }

  Widget _marketplaceField() => SuggestionField(
    controller: _marketplace,
    suggestions: ref.watch(marketplacesProvider).value ?? const [],
    labelText: 'Marketplace (opcional)',
    helperText: 'Vazio = loja virtual própria',
    errorText: fieldError('marketplace'),
  );
}
