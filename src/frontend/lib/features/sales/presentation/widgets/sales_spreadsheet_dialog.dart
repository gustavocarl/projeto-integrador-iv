import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../store/domain/entities/store.dart';
import '../../../store/presentation/controllers/store_providers.dart';

import '../../../../core/errors/base_state.dart';
import '../../../../core/files/file_service.dart';
import '../../data/repositories/sales_export_repository_impl.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/entities/sales_export.dart';
import '../../domain/entities/sales_period.dart';
import '../controllers/sales_exports_controller.dart';

/// Asks which period the sales spreadsheet covers: the day, the week (Monday to Sunday)
/// or the month of [reference], or any range. Returns null when cancelled.
Future<SalesPeriod?> showSalesSpreadsheetDialog(
  BuildContext context, {
  required DateTime reference,
}) => showDialog<SalesPeriod>(
  context: context,
  builder: (_) => SalesSpreadsheetDialog(reference: reference),
);

/// Downloads a generated spreadsheet and asks where to save it (web: download).
/// Returns false when the user cancels the save; errors are thrown as Failure.
Future<bool> saveSalesExport(WidgetRef ref, SalesExport export) async {
  final bytes = await ref
      .read(salesExportRepositoryProvider)
      .download(export.id);
  return ref
      .read(fileServiceProvider)
      .save(
        fileName: export.fileName,
        bytes: bytes,
        mimeType: SalesRepositoryImpl.xlsxMimeType,
      );
}

/// Screens that generate sales spreadsheets (Exportações and where sales are typed in).
mixin SalesSpreadsheetDownload<T extends ConsumerStatefulWidget>
    on BaseState<T> {
  /// Asks the period (around [reference]), generates the spreadsheet (it is listed in
  /// Exportações) and saves it.
  Future<void> downloadSalesSpreadsheet(DateTime reference) async {
    final period = await showSalesSpreadsheetDialog(
      context,
      reference: reference,
    );
    if (period == null || !mounted) return;

    final export = await runSafely(
      () => ref.read(salesExportsControllerProvider.notifier).create(period),
    );
    if (export == null || !mounted) return;

    final saved = await runSafely(() => saveSalesExport(ref, export));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            saved == true
                ? 'Planilha de ${export.periodLabel} salva. Ela fica em Exportações.'
                : 'Planilha de ${export.periodLabel} gerada. Baixe quando quiser em Exportações.',
          ),
        ),
      );
  }

  /// Generated spreadsheets belong to the Exports area.
  bool get canExportSales =>
      ref.read(storeAreasProvider).contains(StoreArea.exports);

  /// Message after a sale is typed in, with the "Gerar planilha" shortcut.
  void showSaleSavedMessage(String message, DateTime saleDate) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // With an action the snack bar would stay until closed.
          persist: false,
          duration: const Duration(seconds: 8),
          // Only for users the admin gave the Exports area.
          action: canExportSales
              ? SnackBarAction(
                  label: 'Gerar planilha',
                  onPressed: () => downloadSalesSpreadsheet(saleDate),
                )
              : null,
        ),
      );
  }
}

class SalesSpreadsheetDialog extends StatefulWidget {
  const SalesSpreadsheetDialog({super.key, required this.reference});

  /// Day the period is built around (the sale just typed in, usually).
  final DateTime reference;

  @override
  State<SalesSpreadsheetDialog> createState() => _SalesSpreadsheetDialogState();
}

class _SalesSpreadsheetDialogState extends State<SalesSpreadsheetDialog> {
  PeriodKind _kind = PeriodKind.month;
  late DateTime _reference = widget.reference;
  late SalesPeriod _range = SalesPeriod.of(PeriodKind.month, widget.reference);

  SalesPeriod get _period =>
      _kind == PeriodKind.custom ? _range : SalesPeriod.of(_kind, _reference);

  static DateTime get _today => DateUtils.dateOnly(DateTime.now());

  Future<void> _pick() async {
    if (_kind == PeriodKind.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: _today,
        initialDateRange: DateTimeRange(
          start: _range.start,
          end: _range.end.isAfter(_today) ? _today : _range.end,
        ),
      );
      if (picked != null) {
        setState(() => _range = SalesPeriod(picked.start, picked.end));
      }
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _reference.isAfter(_today) ? _today : _reference,
      firstDate: DateTime(2000),
      lastDate: _today,
    );
    if (picked != null) setState(() => _reference = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final period = _period;

    return AlertDialog(
      title: const Text('Planilha de vendas'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Todas as vendas do período: planilhas importadas, lançamentos '
              'manuais e caixa.',
            ),
            const SizedBox(height: 16),
            // Chips wrap on narrow phones (a segmented button broke "Semana" in two).
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in PeriodKind.values)
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() {
                      // A custom range starts from the period shown before the switch.
                      if (kind == PeriodKind.custom) _range = _period;
                      _kind = kind;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: Icon(
                _kind == PeriodKind.custom
                    ? Icons.date_range_outlined
                    : Icons.calendar_today_outlined,
              ),
              label: Text(switch (_kind) {
                PeriodKind.day => 'Escolher o dia',
                PeriodKind.week || PeriodKind.month => 'Escolher outra data',
                PeriodKind.custom => 'Escolher o período',
              }),
            ),
            const SizedBox(height: 12),
            Text(
              period.label,
              key: const Key('salesSpreadsheetPeriod'),
              style: theme.textTheme.titleMedium,
            ),
            if (_kind == PeriodKind.week)
              Text(
                'Semana de segunda a domingo.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(period),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Baixar'),
        ),
      ],
    );
  }
}
