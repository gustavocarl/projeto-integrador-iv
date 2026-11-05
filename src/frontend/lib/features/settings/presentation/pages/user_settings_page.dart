import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/brand.dart';
import '../../domain/entities/user_settings.dart';
import '../controllers/user_settings_controller.dart';

/// The logged-in user's preferences (saved in the backend, per user).
/// Each switch is saved as soon as it changes.
class UserSettingsPage extends ConsumerStatefulWidget {
  const UserSettingsPage({super.key});

  @override
  ConsumerState<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends BaseState<UserSettingsPage> {
  Future<void> _save({
    bool? requireProductImage,
    bool? createProductsOnImport,
    ThemePreference? theme,
    bool? notifyRestock,
  }) async {
    final saved = await runSafely(
      () => ref
          .read(userSettingsProvider.notifier)
          .save(
            requireProductImage: requireProductImage,
            createProductsOnImport: createProductsOnImport,
            theme: theme,
            notifyRestock: notifyRestock,
          ),
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Preferência salva.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(userSettingsProvider);
    final value = settings.value;
    final enabled = value != null && !isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Preferências')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (settings case AsyncError(:final error))
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      error is Failure
                          ? error.message
                          : 'Não foi possível carregar as preferências.',
                    ),
                    trailing: TextButton(
                      onPressed: () => ref.invalidate(userSettingsProvider),
                      child: const Text('Tentar de novo'),
                    ),
                  ),
                )
              else if (value == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
              Text('Aparência', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TintedIcon(
                            Icons.palette_outlined,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Tema',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemePreference>(
                          segments: const [
                            ButtonSegment(
                              value: ThemePreference.dark,
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Escuro'),
                            ),
                            ButtonSegment(
                              value: ThemePreference.light,
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Claro'),
                            ),
                          ],
                          selected: {value?.theme ?? ThemePreference.dark},
                          onSelectionChanged: enabled
                              ? (selected) => _save(theme: selected.single)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Produtos', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: TintedIcon(
                        Icons.image_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Exigir imagem nos produtos'),
                      subtitle: const Text(
                        'Ao ligar, um produto só é cadastrado ou salvo com uma imagem. '
                        'Os produtos que já existem não mudam até serem editados.',
                      ),
                      isThreeLine: true,
                      value: value?.requireProductImage ?? false,
                      onChanged: enabled
                          ? (on) => _save(requireProductImage: on)
                          : null,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: TintedIcon(
                        Icons.playlist_add_rounded,
                        color: theme.colorScheme.secondary,
                      ),
                      title: const Text('Cadastrar produtos ao importar'),
                      subtitle: const Text(
                        'Ao importar uma planilha, os SKUs que ainda não estão no catálogo '
                        'viram produtos, com o nome e o último preço vendido (estoque, '
                        'categoria, custo e imagem ficam para você completar). Linhas sem '
                        'SKU não viram produto.',
                      ),
                      isThreeLine: true,
                      value: value?.createProductsOnImport ?? false,
                      onChanged: enabled
                          ? (on) => _save(createProductsOnImport: on)
                          : null,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      key: const Key('notifyRestockSwitch'),
                      secondary: TintedIcon(
                        Icons.notification_important_outlined,
                        color: theme.colorScheme.tertiary,
                      ),
                      title: const Text('Avisar sobre reposição de estoque'),
                      subtitle: const Text(
                        'Mostra no menu Produtos quantos chegaram ao estoque mínimo e '
                        'avisa, depois de uma venda no caixa, quais produtos precisam '
                        'ser repostos.',
                      ),
                      isThreeLine: true,
                      value: value?.notifyRestock ?? true,
                      onChanged: enabled
                          ? (on) => _save(notifyRestock: on)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
