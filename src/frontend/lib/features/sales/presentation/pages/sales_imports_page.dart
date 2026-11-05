import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/brand.dart';
import '../../../../core/errors/base_state.dart';
import '../../../../core/errors/dialog_error_notifier.dart';
import '../../../../core/errors/error_notifier.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/files/file_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sales_import.dart';
import '../controllers/sales_imports_controller.dart';
import '../widgets/sales_spreadsheet_dialog.dart';
import '../../../settings/presentation/controllers/user_settings_controller.dart';
import '../../../settings/presentation/pages/user_settings_page.dart';
import 'manual_sale_page.dart';
import 'sales_import_detail_page.dart';

/// The confirmation text for removing a batch: what leaves the reports, what happens to the
/// linked products (they stay) and to the stock (checkout units go back).
@visibleForTesting
String deletionMessage(String fileName, BatchDeletionImpact impact) {
  final sales = impact.salesCount;
  final products = impact.linkedProducts;
  final units = impact.stockReturned;
  final count = Formatters.integer;

  return [
    '${sales == 1 ? 'A venda' : 'As ${count(sales)} vendas'} de "$fileName" '
        '(${Formatters.currency(impact.totalRevenue)}) '
        '${sales == 1 ? 'será removida e sai' : 'serão removidas e saem'} '
        'dos relatórios e do comparativo de meses.',
    if (products > 0)
      '${sales == 1 ? 'Ela está ligada' : 'Elas estão ligadas'} a '
          '${products == 1 ? '1 produto cadastrado. O produto continua' : '${count(products)} produtos cadastrados. Os produtos continuam'} '
          'no catálogo, mas sem essas vendas no histórico.',
    if (units > 0)
      units == 1
          ? '1 unidade vendida no caixa volta para o estoque.'
          : '${count(units)} unidades vendidas no caixa voltam para o estoque.',
    'Esta ação não pode ser desfeita.',
  ].join('\n\n');
}

/// Spreadsheet imports and every batch of sales. Shown inside the main menu,
/// which provides the app bar.
class SalesImportsPage extends ConsumerStatefulWidget {
  const SalesImportsPage({super.key});

  @override
  ConsumerState<SalesImportsPage> createState() => _SalesImportsPageState();
}

class _SalesImportsPageState extends BaseState<SalesImportsPage>
    with SalesSpreadsheetDownload {
  // An invalid spreadsheet returns one message per row: a dialog fits better than a SnackBar.
  @override
  ErrorNotifier get errorNotifier => const DialogErrorNotifier();

  Future<void> _import() async {
    final file = await ref.read(fileServiceProvider).pickSpreadsheet();
    if (file == null) return;

    final created = await runSafely(
      () => ref
          .read(salesImportsControllerProvider.notifier)
          .importSpreadsheet(file),
    );
    if (created != null) {
      final products = created.createdProducts ?? 0;
      _showMessage(
        'Planilha importada: ${Formatters.integer(created.salesCount)} vendas, '
        '${Formatters.currency(created.totalRevenue)}'
        '${switch (products) {
          0 => '',
          1 => '; 1 produto cadastrado',
          _ => '; ${Formatters.integer(products)} produtos cadastrados',
        }}.',
      );
    }
  }

  Future<void> _downloadTemplate() async {
    final saved = await runSafely(() async {
      final bytes = await ref.read(salesRepositoryProvider).downloadTemplate();
      return ref
          .read(fileServiceProvider)
          .save(
            fileName: 'modelo-vendas.xlsx',
            bytes: bytes,
            mimeType: SalesRepositoryImpl.xlsxMimeType,
          );
    });
    if (saved == true) _showMessage('Modelo de planilha salvo.');
  }

  Future<void> _addManualSale() async {
    final result = await Navigator.of(context).push<ManualSaleResult>(
      MaterialPageRoute(builder: (_) => const ManualSalePage()),
    );
    if (result != null) {
      showSaleSavedMessage(
        'Venda lançada em "${result.salesImport.fileName}".',
        result.sale.date,
      );
    }
  }

  Future<void> _delete(SalesImport salesImport) async {
    // What goes away is asked to the backend at this moment (linked products, checkout units).
    final impact = await runSafely(
      () => ref.read(salesRepositoryProvider).getDeletionImpact(salesImport.id),
    );
    if (impact == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lote?'),
        content: SingleChildScrollView(
          child: Text(deletionMessage(salesImport.fileName, impact)),
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

    await runSafely(
      () => ref
          .read(salesImportsControllerProvider.notifier)
          .delete(salesImport.id),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final imports = ref.watch(salesImportsControllerProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        // The main menu keeps several screens alive, each with its own button:
        // without a tag of its own they clash when a page is pushed.
        heroTag: null,
        onPressed: isLoading ? null : _addManualSale,
        icon: const Icon(Icons.edit_note),
        label: const Text('Lançar venda'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(salesImportsControllerProvider.future),
        child: ListView(
          // Bottom room so the floating button doesn't cover the last batch.
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            _ImportCard(
              isLoading: isLoading,
              onImport: _import,
              onDownloadTemplate: _downloadTemplate,
              createProducts:
                  ref
                      .watch(userSettingsProvider)
                      .value
                      ?.createProductsOnImport ??
                  false,
              onOpenSettings: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UserSettingsPage(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Lotes de vendas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...switch (imports) {
              AsyncData(:final value) when value.isEmpty => [
                const _EmptyState(),
              ],
              AsyncData(:final value) => [
                for (final item in value)
                  _ImportTile(
                    salesImport: item,
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SalesImportDetailPage(salesImport: item),
                      ),
                    ),
                    onDelete: isLoading ? null : () => _delete(item),
                  ),
              ],
              AsyncError(:final error) => [
                _LoadError(
                  message: error is Failure
                      ? error.generalMessages.join('\n')
                      : null,
                  onRetry: () => ref.invalidate(salesImportsControllerProvider),
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
}

class _ImportCard extends StatelessWidget {
  const _ImportCard({
    required this.isLoading,
    required this.onImport,
    required this.onDownloadTemplate,
    required this.createProducts,
    required this.onOpenSettings,
  });

  final bool isLoading;
  final VoidCallback onImport;
  final VoidCallback onDownloadTemplate;

  /// The user's setting "Cadastrar produtos ao importar" (changed in Preferências).
  final bool createProducts;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        // A soft wash of the brand gradient: this is the screen's main action.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              BrandColors.teal.withValues(alpha: 0.14),
              BrandColors.indigo.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TintedIcon(
                    Icons.upload_file_rounded,
                    color: theme.colorScheme.primary,
                    size: 48,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Importar planilha',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Envie um arquivo .xlsx no formato do modelo. Cada venda informa o canal '
                '(Presencial ou Online) e, se online, o marketplace. A planilha só é salva '
                'quando todas as linhas estão corretas.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    createProducts
                        ? Icons.playlist_add_check_rounded
                        : Icons.playlist_remove_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      createProducts
                          ? 'SKUs novos viram produtos.'
                          : 'SKUs novos não viram produtos.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenSettings,
                    child: const Text('Preferências'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: isLoading ? null : onImport,
                    icon: isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_upload_outlined),
                    label: const Text('Selecionar planilha'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : onDownloadTemplate,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Baixar modelo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportTile extends StatelessWidget {
  const _ImportTile({
    required this.salesImport,
    required this.onOpen,
    required this.onDelete,
  });

  final SalesImport salesImport;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final i = salesImport;
    final period = i.periodStart == null
        ? null
        : '${Formatters.date(i.periodStart!)} a ${Formatters.date(i.periodEnd!)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              TintedIcon(
                switch (i.source) {
                  ImportSource.manual => Icons.edit_note,
                  ImportSource.store => Icons.point_of_sale_outlined,
                  ImportSource.spreadsheet => Icons.table_chart_outlined,
                },
                color: switch (i.source) {
                  ImportSource.manual => BrandColors.tintsOf(context)[2],
                  ImportSource.store => BrandColors.tintsOf(context)[1],
                  ImportSource.spreadsheet => BrandColors.tintsOf(context)[0],
                },
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.fileName,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: Formatters.currency(i.totalRevenue),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text:
                                ' · ${Formatters.integer(i.salesCount)} vendas'
                                '${period == null ? '' : ' · $period'}',
                          ),
                        ],
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${switch (i.source) {
                        ImportSource.manual => 'Lote manual criado',
                        ImportSource.store => 'Lote do caixa criado',
                        ImportSource.spreadsheet => 'Importado',
                      }} '
                      'em ${Formatters.dateTime(i.importedAt)} por ${i.importedBy}',
                      style: muted,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Excluir lote',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.inbox_outlined,
    title: 'Nenhuma venda ainda.',
    message: 'Importe uma planilha ou lance uma venda.',
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            message ?? 'Não foi possível carregar as importações.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
