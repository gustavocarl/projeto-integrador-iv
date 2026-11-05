import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../../../../core/files/file_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/parsers.dart';
import '../../../../shared/widgets/suggestion_field.dart';
import '../../../settings/presentation/controllers/user_settings_controller.dart';
import '../../domain/entities/product.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../controllers/products_controller.dart';
import '../widgets/product_avatar.dart';

/// Creates a product, or edits [product]. Pops with a message for the list to show.
///
/// Validation is the backend's: the screen sends what was typed (null when empty or
/// unreadable) and shows each error under its field.
class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends BaseState<ProductFormPage> {
  late final Product? _product = widget.product;
  late final _name = TextEditingController(text: _product?.name);
  late final _sku = TextEditingController(text: _product?.sku);
  late final _category = TextEditingController(text: _product?.category);
  late final _salePrice = TextEditingController(
    text: _product == null ? null : Formatters.amount(_product.salePrice),
  );
  late final _costPrice = TextEditingController(
    text: _product?.costPrice == null
        ? null
        : Formatters.amount(_product!.costPrice!),
  );
  late final _stock = TextEditingController(
    text: _product?.stockQuantity.toString() ?? '0',
  );
  late final _minimumStock = TextEditingController(
    text: _product?.minimumStock.toString() ?? '0',
  );
  late final _imageUrl = TextEditingController(text: _product?.imageUrl);
  late bool _isActive = _product?.isActive ?? true;

  bool get _isEditing => _product != null;

  @override
  void dispose() {
    for (final c in [
      _name,
      _sku,
      _category,
      _salePrice,
      _costPrice,
      _stock,
      _minimumStock,
      _imageUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final input = ProductInput(
      name: _text(_name),
      sku: _text(_sku),
      category: _text(_category),
      salePrice: Parsers.decimal(_salePrice.text),
      costPrice: Parsers.decimal(_costPrice.text),
      stockQuantity: Parsers.integer(_stock.text),
      minimumStock: Parsers.integer(_minimumStock.text),
      isActive: _isActive,
      imageUrl: _text(_imageUrl),
    );

    final saved = await runSafely(
      () => ref
          .read(productsControllerProvider.notifier)
          .save(input, id: _product?.id),
    );
    if (saved != null && mounted) {
      Navigator.of(context).pop(
        _isEditing
            ? 'Produto atualizado.'
            : 'Produto "${saved.name}" cadastrado.',
      );
    }
  }

  /// Sends a photo chosen from the device; the field then holds its path on the API.
  Future<void> _uploadImage() async {
    final file = await ref.read(fileServiceProvider).pickImage();
    if (file == null || !mounted) return;

    final path = await runSafely(
      () => ref.read(productRepositoryProvider).uploadImage(file),
    );
    if (path != null && mounted) _imageUrl.text = path;
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir produto?'),
        content: Text(
          '"${_product!.name}" sairá do catálogo. Produtos que já foram vendidos '
          'não podem ser excluídos: desative-os.',
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

    final deleted = await runSafely(() async {
      await ref.read(productsControllerProvider.notifier).delete(_product!.id);
      return true;
    });
    if (deleted == true && mounted) {
      Navigator.of(context).pop('Produto excluído.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The user's setting; the backend enforces it, the screen only says so.
    final imageRequired =
        ref.watch(userSettingsProvider).value?.requireProductImage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar produto' : 'Novo produto'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ImageField(
                controller: _imageUrl,
                name: _name,
                category: _category,
                required: imageRequired,
                // "file" = the upload was refused; "imageUrl" = the saved product.
                errorText: fieldError('file') ?? fieldError('imageUrl'),
                isUploading: isLoading,
                onUpload: _uploadImage,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  errorText: fieldError('name'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sku,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'SKU',
                        helperText: 'Código único',
                        errorText: fieldError('sku'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SuggestionField(
                      controller: _category,
                      suggestions:
                          ref.watch(productCategoriesProvider).value ??
                          const [],
                      labelText: 'Categoria (opcional)',
                      errorText: fieldError('category'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Preços', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _MoneyField(
                      controller: _salePrice,
                      label: 'Preço de venda',
                      errorText: fieldError('salePrice'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MoneyField(
                      controller: _costPrice,
                      label: 'Custo (opcional)',
                      errorText: fieldError('costPrice'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: Listenable.merge([_salePrice, _costPrice]),
                builder: (context, _) {
                  final (text, isLoss) = _margin();
                  return Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isLoss
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Estoque', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Em estoque',
                        errorText: fieldError('stockQuantity'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _minimumStock,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Estoque mínimo',
                        helperText: 'Alerta de reposição',
                        errorText: fieldError('minimumStock'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo'),
                subtitle: const Text(
                  'Produtos inativos ficam no cadastro, mas não aparecem no caixa',
                ),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: isLoading ? null : _save,
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isEditing ? 'Salvar alterações' : 'Cadastrar'),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir produto'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The margin line under the prices; `isLoss` when the cost is above the sale price,
  /// which the backend refuses (a product is never sold at a loss).
  (String text, bool isLoss) _margin() {
    final price = Parsers.decimal(_salePrice.text);
    final cost = Parsers.decimal(_costPrice.text);
    if (price == null || cost == null || price < 0) {
      return ('Informe o custo para ver a margem e o lucro das vendas.', false);
    }
    if (cost > price) {
      return (
        'O custo não pode ser maior que o preço de venda: cada venda daria '
            'prejuízo de ${Formatters.currency(cost - price)}.',
        true,
      );
    }
    if (price == 0) return ('Sem lucro: custo e preço de venda iguais.', false);
    final profit = price - cost;
    return (
      'Margem de ${Formatters.percent(profit / price)}: lucro de '
          '${Formatters.currency(profit)} por unidade.',
      false,
    );
  }
}

/// The product photo: a link typed in, or a file sent with [onUpload] (the field then holds
/// its path on the API). A live preview stays beside it (or the category icon while there is none).
class _ImageField extends StatelessWidget {
  const _ImageField({
    required this.controller,
    required this.name,
    required this.category,
    required this.required,
    required this.isUploading,
    required this.onUpload,
    this.errorText,
  });

  final TextEditingController controller;
  final TextEditingController name;
  final TextEditingController category;
  final bool required;
  final bool isUploading;
  final VoidCallback onUpload;
  final String? errorText;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, name, category]),
    builder: (context, _) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductAvatar(
          name: name.text,
          category: category.text.trim().isEmpty ? null : category.text,
          imageUrl: controller.text.trim().isEmpty
              ? null
              : controller.text.trim(),
          size: 88,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: required
                      ? 'Imagem (obrigatória)'
                      : 'Imagem (opcional)',
                  hintText: 'https://...',
                  helperText: required
                      ? 'Suas configurações exigem imagem nos produtos.'
                      : 'Cole o link de uma foto ou envie um arquivo.',
                  helperMaxLines: 2,
                  errorText: errorText,
                  errorMaxLines: 3,
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Remover imagem',
                          icon: const Icon(Icons.close),
                          onPressed: controller.clear,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isUploading ? null : onUpload,
                icon: isUploading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_outlined),
                label: const Text('Enviar arquivo'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.controller,
    required this.label,
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      prefixText: r'R$ ',
      hintText: '0,00',
      errorText: errorText,
    ),
  );
}
