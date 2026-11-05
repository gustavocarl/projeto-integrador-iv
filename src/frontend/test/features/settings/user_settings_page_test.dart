import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/core/files/file_service.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:univesp_project/features/auth/presentation/controllers/auth_controller.dart';
import 'package:univesp_project/features/home/presentation/pages/home_shell.dart';
import 'package:univesp_project/features/products/data/repositories/product_repository_impl.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:univesp_project/features/settings/domain/entities/user_settings.dart';
import 'package:univesp_project/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:univesp_project/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:univesp_project/features/store/data/repositories/store_repository_impl.dart';

import '../../helpers/fakes.dart';

Future<(FakeSettingsRepository, ProviderContainer)> _openPreferences(
  WidgetTester tester, [
  FakeSettingsRepository? settings,
]) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = settings ?? FakeSettingsRepository();
  final container = ProviderContainer(
    overrides: [
      storeRepositoryProvider.overrideWithValue(FakeStoreRepository()),
      notificationRepositoryProvider.overrideWithValue(
        FakeNotificationRepository(),
      ),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(sessionUser: FakeAuthRepository.maria),
      ),
      settingsRepositoryProvider.overrideWithValue(repository),
      productRepositoryProvider.overrideWithValue(FakeProductRepository()),
      salesRepositoryProvider.overrideWithValue(FakeSalesRepository()),
      fileServiceProvider.overrideWithValue(FakeFileService()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: HomeShell(user: FakeAuthRepository.maria)),
    ),
  );
  await tester.pumpAndSettle();

  // User button → "Configurações do usuário" → "Preferências".
  await tester.tap(find.byTooltip('Conta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Configurações do usuário'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Preferências'));
  await tester.pumpAndSettle();
  expect(find.widgetWithText(AppBar, 'Preferências'), findsOneWidget);
  return (repository, container);
}

bool _switchValue(WidgetTester tester, String title) => tester
    .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
    .value;

const _image = 'Exigir imagem nos produtos';
const _import = 'Cadastrar produtos ao importar';
const _restock = 'Avisar sobre reposição de estoque';

void main() {
  testWidgets('options start off, except the restock warnings', (tester) async {
    await _openPreferences(tester);

    expect(_switchValue(tester, _image), isFalse);
    expect(_switchValue(tester, _import), isFalse);
    expect(_switchValue(tester, _restock), isTrue);
  });

  testWidgets('turning off the restock warnings saves only it', (tester) async {
    final (repository, container) = await _openPreferences(tester);

    await tester.ensureVisible(find.text(_restock));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_restock));
    await tester.pumpAndSettle();

    expect(repository.updates, [(null, null, null)]);
    expect(repository.restockUpdates, [false]);
    expect(_switchValue(tester, _restock), isFalse);
    expect(container.read(userSettingsProvider).value?.notifyRestock, isFalse);
  });

  testWidgets('shows the settings saved for the user', (tester) async {
    await _openPreferences(
      tester,
      FakeSettingsRepository(const UserSettings(createProductsOnImport: true)),
    );

    expect(_switchValue(tester, _image), isFalse);
    expect(_switchValue(tester, _import), isTrue);
  });

  testWidgets('turning on "Exigir imagem nos produtos" saves only it', (
    tester,
  ) async {
    final (repository, container) = await _openPreferences(tester);

    await tester.tap(find.text(_image));
    await tester.pumpAndSettle();

    expect(repository.updates, [(true, null, null)]);
    expect(_switchValue(tester, _image), isTrue);
    expect(
      container.read(userSettingsProvider).value?.requireProductImage,
      isTrue,
    );
    expect(find.text('Preferência salva.'), findsOneWidget);
  });

  testWidgets('turning on "Cadastrar produtos ao importar" saves only it', (
    tester,
  ) async {
    final (repository, container) = await _openPreferences(tester);

    await tester.tap(find.text(_import));
    await tester.pumpAndSettle();

    expect(repository.updates, [(null, true, null)]);
    expect(_switchValue(tester, _import), isTrue);
    expect(
      container.read(userSettingsProvider).value?.createProductsOnImport,
      isTrue,
    );
  });

  testWidgets('a failure keeps the switch as it was and shows the message', (
    tester,
  ) async {
    final (repository, _) = await _openPreferences(tester);
    repository.saveFailure = const Failure('Sem conexão com o servidor.');

    await tester.tap(find.text(_import));
    await tester.pumpAndSettle();

    expect(_switchValue(tester, _import), isFalse);
    expect(find.text('Sem conexão com o servidor.'), findsOneWidget);
  });

  testWidgets('the theme starts dark and switching to light saves it', (
    tester,
  ) async {
    final (repository, container) = await _openPreferences(tester);
    SegmentedButton<ThemePreference> themeButton() =>
        tester.widget(find.byType(SegmentedButton<ThemePreference>));
    expect(themeButton().selected, {ThemePreference.dark});

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();

    expect(repository.updates, [(null, null, ThemePreference.light)]);
    expect(themeButton().selected, {ThemePreference.light});
    expect(container.read(themePreferenceProvider), ThemePreference.light);
  });

  testWidgets('a load failure can be retried', (tester) async {
    final repository = FakeSettingsRepository()
      ..loadFailure = const Failure('Sem conexão com o servidor.');
    await _openPreferences(tester, repository);

    expect(find.text('Sem conexão com o servidor.'), findsOneWidget);

    repository
      ..loadFailure = null
      ..settings = const UserSettings(requireProductImage: true);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Sem conexão com o servidor.'), findsNothing);
    expect(_switchValue(tester, _image), isTrue);
  });
}
