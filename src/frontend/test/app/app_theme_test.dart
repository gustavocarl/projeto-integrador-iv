import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/app/app.dart';
import 'package:univesp_project/core/files/file_service.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:univesp_project/features/products/data/repositories/product_repository_impl.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:univesp_project/features/settings/domain/entities/user_settings.dart';
import 'package:univesp_project/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:univesp_project/features/store/data/repositories/store_repository_impl.dart';

import '../helpers/fakes.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  UserSettings settings = UserSettings.defaults,
}) async {
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storeRepositoryProvider.overrideWithValue(FakeStoreRepository()),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        settingsRepositoryProvider.overrideWithValue(
          FakeSettingsRepository(settings),
        ),
        productRepositoryProvider.overrideWithValue(FakeProductRepository()),
        salesRepositoryProvider.overrideWithValue(FakeSalesRepository()),
        fileServiceProvider.overrideWithValue(FakeFileService()),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}

ThemeMode? _themeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;

void main() {
  testWidgets('the login screen is dark', (tester) async {
    await _pumpApp(tester, auth: FakeAuthRepository());

    expect(_themeMode(tester), ThemeMode.dark);
  });

  testWidgets('a user who never chose a theme gets dark', (tester) async {
    await _pumpApp(
      tester,
      auth: FakeAuthRepository(sessionUser: FakeAuthRepository.maria),
    );

    expect(_themeMode(tester), ThemeMode.dark);
  });

  testWidgets('a user who chose light gets the light theme', (tester) async {
    await _pumpApp(
      tester,
      auth: FakeAuthRepository(sessionUser: FakeAuthRepository.maria),
      settings: const UserSettings(theme: ThemePreference.light),
    );

    expect(_themeMode(tester), ThemeMode.light);
    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.light);
  });
}
