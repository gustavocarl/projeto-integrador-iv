import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../../../../shared/widgets/brand.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../widgets/store_name_field.dart';

/// Shown instead of the app while the user has no store access: waiting for an admin, or
/// without a store (removed). Typing a store name opens a new store or asks an existing one.
class StoreAccessPage extends ConsumerStatefulWidget {
  const StoreAccessPage({super.key, required this.user});

  final User user;

  /// While waiting, how often the app asks whether the admin approved.
  static const checkInterval = Duration(seconds: 30);

  @override
  ConsumerState<StoreAccessPage> createState() => _StoreAccessPageState();
}

class _StoreAccessPageState extends BaseState<StoreAccessPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  Timer? _timer;

  bool get _pending => widget.user.store?.isPending ?? false;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(StoreAccessPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  /// Checks now and then only while a request is waiting.
  void _syncTimer() {
    if (_pending && _timer == null) {
      _timer = Timer.periodic(StoreAccessPage.checkInterval, (_) => _check());
    } else if (!_pending) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    super.dispose();
  }

  Future<void> _check() =>
      ref.read(authControllerProvider.notifier).refreshProfile();

  Future<void> _submit() async {
    if (isLoading || !_formKey.currentState!.validate()) return;
    final auth = ref.read(authControllerProvider.notifier);
    await runSafely(() => auth.enterStore(_name.text.trim()));
    // Success: the AuthGate shows the app (new store) or this page in the waiting state.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = widget.user.store;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sua loja'),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_pending && store != null)
                    Card(
                      key: const Key('pendingCard'),
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            TintedIcon(
                              Icons.hourglass_top,
                              color: theme.colorScheme.primary,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aguardando aprovação',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Você pediu acesso à loja ${store.name} e o admin '
                              'recebeu uma notificação. Assim que ele aprovar, o '
                              'app abre aqui.',
                              textAlign: TextAlign.center,
                              style: muted,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              onPressed: _check,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Verificar agora'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Text(
                      'Olá, ${widget.user.name}! Você não faz parte de nenhuma loja '
                      '(o admin pode ter removido seu acesso). Informe o nome '
                      'da sua loja ou da loja onde você trabalha.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (_pending)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Não quer esperar? Informe outra loja ou crie a sua '
                        '(o pedido atual é cancelado).',
                        style: muted,
                      ),
                    ),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            StoreNameField(
                              controller: _name,
                              enabled: !isLoading,
                              errorText: fieldError('name'),
                              onChanged: clearFailure,
                              onSubmitted: _submit,
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: isLoading ? null : _submit,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                              ),
                              icon: isLoading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: const Text('Continuar'),
                            ),
                          ],
                        ),
                      ),
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
