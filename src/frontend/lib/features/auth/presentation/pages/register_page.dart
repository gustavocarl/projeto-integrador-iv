import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../../../store/presentation/widgets/store_name_field.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_form_parts.dart';

/// Sign-up: name, e-mail, password and the store — a new one (the user is its admin) or an
/// existing one by its code (waits for the admin). No confirmation step. On success the user
/// is logged in (this screen closes back to the [AuthGate]).
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.initialEmail});

  /// What was typed on the login screen.
  final String? initialEmail;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends BaseState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _storeName = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _storeName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isLoading || !_formKey.currentState!.validate()) return;

    final user = await runSafely(
      () => ref
          .read(authControllerProvider.notifier)
          .register(
            _name.text.trim(),
            _email.text.trim(),
            _password.text,
            storeName: _storeName.text.trim(),
          ),
    );
    if (user == null || !mounted) return;

    TextInput.finishAutofillContext();
    // Logged in: the AuthGate below now shows the app (or, for an existing store, the wait).
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) => AuthFormScaffold(
    title: 'Criar conta',
    intro:
        'Preencha os dados para criar seu acesso. Informe o nome da sua loja ou da '
        'loja onde você trabalha.',
    formKey: _formKey,
    submitLabel: 'Criar conta',
    submitIcon: Icons.person_add_alt_1_outlined,
    isLoading: isLoading,
    onSubmit: _submit,
    fields: [
      TextFormField(
        controller: _name,
        enabled: !isLoading,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.name],
        onChanged: (_) => clearFailure(),
        validator: (value) =>
            (value?.trim() ?? '').isEmpty ? 'Informe o nome.' : null,
        decoration: InputDecoration(
          labelText: 'Nome',
          prefixIcon: const Icon(Icons.person_outline),
          errorText: fieldError('name'),
        ),
      ),
      const SizedBox(height: 16),
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
        label: 'Senha',
        enabled: !isLoading,
        errorText: fieldError('password'),
        onChanged: clearFailure,
        onSubmitted: _submit,
      ),
      const SizedBox(height: 24),
      StoreNameField(
        controller: _storeName,
        enabled: !isLoading,
        errorText: fieldError('storeName'),
        onChanged: clearFailure,
        onSubmitted: _submit,
      ),
    ],
  );
}
