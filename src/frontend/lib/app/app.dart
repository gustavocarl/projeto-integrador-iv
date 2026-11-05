import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/domain/entities/user_settings.dart';
import '../features/settings/presentation/controllers/user_settings_controller.dart';
import 'auth_gate.dart';
import 'theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Each user's choice (Preferências); dark by default and on the login screen.
    final theme = ref.watch(themePreferenceProvider);

    return MaterialApp(
      title: 'Univesp Project',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (theme) {
        ThemePreference.dark => ThemeMode.dark,
        ThemePreference.light => ThemeMode.light,
      },
      // Portuguese for Material's own texts (date picker, tooltips, "OK"/"Cancelar").
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
    );
  }
}
