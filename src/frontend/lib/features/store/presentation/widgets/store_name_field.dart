import 'package:flutter/material.dart';

/// "Nome da loja", used on sign-up and on the store access screen. A name that already exists
/// (accents and casing don't matter) asks that store's admin for access; a new name opens the
/// store with the user as its admin.
class StoreNameField extends StatelessWidget {
  const StoreNameField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final VoidCallback? onChanged;
  final VoidCallback? onSubmitted;

  static const helper =
      'Loja nova: você será o admin. Se a loja já existir, o admin dela recebe '
      'uma notificação para aprovar o seu acesso.';

  @override
  Widget build(BuildContext context) => TextFormField(
    key: const Key('storeNameField'),
    controller: controller,
    enabled: enabled,
    textCapitalization: TextCapitalization.words,
    textInputAction: TextInputAction.done,
    onChanged: (_) => onChanged?.call(),
    onFieldSubmitted: (_) => onSubmitted?.call(),
    validator: (value) =>
        (value?.trim() ?? '').isEmpty ? 'Informe o nome da loja.' : null,
    decoration: InputDecoration(
      labelText: 'Nome da loja',
      prefixIcon: const Icon(Icons.storefront_outlined),
      helperText: helper,
      helperMaxLines: 3,
      errorText: errorText,
      errorMaxLines: 3,
    ),
  );
}
