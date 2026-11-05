import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../controllers/auth_controller.dart';

/// Changes the logged-in user's password. Pops with `true` when saved.
///
/// Only the confirmation is checked here (the backend never sees it); the password
/// rules and the current password are checked by the backend, shown under each field.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends BaseState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isLoading || !_formKey.currentState!.validate()) return;

    final saved = await runSafely(() async {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(_current.text, _new.text);
      return true;
    });
    if (saved != true || !mounted) return;

    // Lets the browser/password manager offer to update the saved password.
    TextInput.finishAutofillContext();
    Navigator.of(context).pop(true);
  }

  String? _validateConfirmation(String? value) =>
      value != _new.text ? 'As senhas não conferem.' : null;

  Widget _visibilityToggle() => IconButton(
    tooltip: _obscure ? 'Mostrar senhas' : 'Ocultar senhas',
    icon: Icon(
      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
    ),
    onPressed: () => setState(() => _obscure = !_obscure),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alterar senha')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _current,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => clearFailure(),
                    decoration: InputDecoration(
                      labelText: 'Senha atual',
                      errorText: fieldError('currentPassword'),
                      suffixIcon: _visibilityToggle(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _new,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => clearFailure(),
                    decoration: InputDecoration(
                      labelText: 'Nova senha',
                      helperText: 'Mínimo de 8 caracteres, com letra maiúscula, minúscula e número.',
                      helperMaxLines: 2,
                      errorText: fieldError('newPassword'),
                      errorMaxLines: 5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmation,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    validator: _validateConfirmation,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Confirmar nova senha',
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: isLoading ? null : _submit,
                    icon: isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Salvar nova senha'),
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
