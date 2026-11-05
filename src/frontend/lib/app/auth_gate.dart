import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/home/presentation/pages/home_shell.dart';
import '../features/store/presentation/pages/store_access_page.dart';

/// Shows the login screen, the app, or — without an approved store — the store access screen.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return switch (auth) {
      AsyncData(value: final user?) =>
        user.hasStoreAccess
            ? HomeShell(user: user)
            : StoreAccessPage(user: user),
      AsyncData() || AsyncError() => const LoginPage(),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
