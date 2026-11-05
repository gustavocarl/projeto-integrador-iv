import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_form_parts.dart';

/// Simple password recovery (prototype): e-mail and a new password, with no confirmation
/// code. Pops with the e-mail when saved, so the login screen can fill it in.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail});

  /// What was typed on the login screen.
  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends BaseState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isLoading || !_formKey.currentState!.validate()) return;

    final email = _email.text.trim();
    final saved = await runSafely(() async {
      await ref
          .read(authControllerProvider.notifier)
          .resetPassword(email, _password.text);
      return true;
    });
    if (saved == true && mounted) Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthFormScaffold(
      title: 'Recuperar senha',
      intro: 'Informe o e-mail da conta e escolha uma nova senha.',
      formKey: _formKey,
      submitLabel: 'Salvar nova senha',
      submitIcon: Icons.lock_reset,
      isLoading: isLoading,
      onSubmit: _submit,
      notice: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Versão simples do protótipo: a troca não pede nenhuma '
              'confirmação por e-mail.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      fields: [
        TextFormField(
          controller: _email,
          enabled: !isLoading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          onChanged: (_) => clearFailure(),
          validator: validateEmail,
          decoration: InputDecoration(
            labelText: 'E-mail',
            prefixIcon: const Icon(Icons.email_outlined),
            errorText: fieldError('email'),
          ),
        ),
        const SizedBox(height: 16),
        NewPasswordFields(
          password: _password,
          confirmation: _confirmation,
          label: 'Nova senha',
          enabled: !isLoading,
          errorText: fieldError('newPassword'),
          onChanged: clearFailure,
          onSubmitted: _submit,
        ),
      ],
    );
  }
}
