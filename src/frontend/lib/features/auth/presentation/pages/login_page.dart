import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../../../../shared/widgets/brand.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_form_parts.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends BaseState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isLoading || !_formKey.currentState!.validate()) return;

    TextInput.finishAutofillContext();
    // On success the auth state changes and AuthGate shows the dashboard.
    await runSafely(
      () => ref
          .read(authControllerProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text),
    );
  }

  /// The e-mail typed so far, handed to the sign-up and recovery screens.
  String? get _typedEmail {
    final email = _emailController.text.trim();
    return email.isEmpty ? null : email;
  }

  void _openRegister() {
    clearFailure();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegisterPage(initialEmail: _typedEmail),
      ),
    );
  }

  Future<void> _openForgotPassword() async {
    clearFailure();
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(initialEmail: _typedEmail),
      ),
    );
    if (email == null || !mounted) return;

    _emailController.text = email;
    _passwordController.clear();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Senha alterada. Entre com a nova senha.'),
        ),
      );
  }

  static String? _validatePassword(String? value) =>
      (value == null || value.isEmpty) ? 'Informe a senha.' : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: BrandLogo(size: 64)),
                        const SizedBox(height: 20),
                        Text(
                          'Marcelo Eletrônicos',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Entre para ver suas análises',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  enabled: !isLoading,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: InputDecoration(
                                    labelText: 'E-mail',
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                    ),
                                    errorText: fieldError('email'),
                                  ),
                                  validator: validateEmail,
                                  onChanged: (_) => clearFailure(),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  enabled: !isLoading,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    errorText: fieldError('password'),
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Mostrar senha'
                                          : 'Ocultar senha',
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  validator: _validatePassword,
                                  onChanged: (_) => clearFailure(),
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: isLoading
                                        ? null
                                        : _openForgotPassword,
                                    child: const Text('Esqueci minha senha'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FilledButton(
                                  onPressed: isLoading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                  child: isLoading
                                      ? const SizedBox.square(
                                          dimension: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text('Entrar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Ainda não tem conta?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextButton(
                              onPressed: isLoading ? null : _openRegister,
                              child: const Text('Criar conta'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Wraps on narrow phones instead of overflowing.
                        Wrap(
                          alignment: WrapAlignment.center,
                          runSpacing: 8,
                          children: [
                            for (final (icon, label) in const [
                              (Icons.inventory_2_outlined, 'Estoque'),
                              (Icons.point_of_sale_outlined, 'Caixa'),
                              (Icons.insights_outlined, 'Análises'),
                            ])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      label,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
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
