import 'package:flutter/material.dart';

/// E-mail check shared by the login, sign-up and recovery forms (the backend checks again).
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Informe o e-mail.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'E-mail inválido.';
  }
  return null;
}

/// The backend's password rules, shown under the new password field.
const passwordRules =
    'Mínimo de 8 caracteres, com letra maiúscula, minúscula e número.';

/// A new password and its confirmation. Only the confirmation is checked here: the
/// password rules come from the backend ([errorText], under the first field).
class NewPasswordFields extends StatefulWidget {
  const NewPasswordFields({
    super.key,
    required this.password,
    required this.confirmation,
    required this.label,
    required this.enabled,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController password;
  final TextEditingController confirmation;

  /// "Senha" or "Nova senha"; the confirmation is "Confirmar <label in lower case>".
  final String label;
  final bool enabled;
  final String? errorText;
  final VoidCallback? onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<NewPasswordFields> createState() => _NewPasswordFieldsState();
}

class _NewPasswordFieldsState extends State<NewPasswordFields> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        controller: widget.password,
        enabled: widget.enabled,
        obscureText: _obscure,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.next,
        onChanged: (_) => widget.onChanged?.call(),
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.lock_outline),
          helperText: passwordRules,
          helperMaxLines: 2,
          errorText: widget.errorText,
          errorMaxLines: 5,
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Mostrar senhas' : 'Ocultar senhas',
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: widget.confirmation,
        enabled: widget.enabled,
        obscureText: _obscure,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.done,
        validator: (value) =>
            value != widget.password.text ? 'As senhas não conferem.' : null,
        onFieldSubmitted: (_) => widget.onSubmitted?.call(),
        decoration: InputDecoration(
          labelText: 'Confirmar ${widget.label.toLowerCase()}',
          prefixIcon: const Icon(Icons.lock_outline),
        ),
      ),
    ],
  );
}

/// Layout of the screens opened from the login: app bar, a centered card, and the
/// main button with its loading state.
class AuthFormScaffold extends StatelessWidget {
  const AuthFormScaffold({
    super.key,
    required this.title,
    required this.intro,
    required this.formKey,
    required this.fields,
    required this.submitLabel,
    required this.submitIcon,
    required this.isLoading,
    required this.onSubmit,
    this.notice,
  });

  final String title;
  final String intro;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final String submitLabel;
  final IconData submitIcon;
  final bool isLoading;
  final VoidCallback onSubmit;

  /// Optional note above the fields (e.g. a warning).
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        // Top-aligned: under an app bar, a centered form leaves an odd gap above it.
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        intro,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ?notice,
                      if (notice != null) const SizedBox(height: 16),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...fields,
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: isLoading ? null : onSubmit,
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
                                    : Icon(submitIcon),
                                label: Text(submitLabel),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
