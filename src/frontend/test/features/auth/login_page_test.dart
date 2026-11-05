import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/app/app.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:univesp_project/features/products/data/repositories/product_repository_impl.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:univesp_project/features/store/data/repositories/store_repository_impl.dart';

import '../../helpers/fakes.dart';

Future<FakeAuthRepository> _pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? repository,
}) async {
  final repo = repository ?? FakeAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storeRepositoryProvider.overrideWithValue(FakeStoreRepository()),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
        authRepositoryProvider.overrideWithValue(repo),
        // The main menu opens on the products screen.
        productRepositoryProvider.overrideWithValue(FakeProductRepository()),
        salesRepositoryProvider.overrideWithValue(FakeSalesRepository()),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _fillAndSubmit(
  WidgetTester tester,
  String email,
  String password,
) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('app uses the dark theme and starts on the login page', (
    tester,
  ) async {
    await _pumpApp(tester);

    final context = tester.element(find.text('Marcelo Eletrônicos'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
  });

  testWidgets('validates empty fields without calling the backend', (
    tester,
  ) async {
    final repo = await _pumpApp(tester);

    await _fillAndSubmit(tester, '', '');

    expect(find.text('Informe o e-mail.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
    expect(repo.loginCalls, 0);
  });

  testWidgets('shows the backend error when credentials are wrong', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _fillAndSubmit(tester, FakeAuthRepository.validEmail, 'SenhaErrada1');

    expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
  });

  testWidgets(
    'goes to the main menu after login and back to login after logout',
    (tester) async {
      await _pumpApp(tester);

      await _fillAndSubmit(
        tester,
        FakeAuthRepository.validEmail,
        FakeAuthRepository.validPassword,
      );
      // The test window is 800 px wide: the menu is on the side.
      expect(find.byType(NavigationRail), findsOneWidget);

      await tester.tap(find.byTooltip('Conta'));
      await tester.pumpAndSettle();
      expect(find.text('Maria Silva'), findsOneWidget);
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
    },
  );

  testWidgets('restores a saved session on startup', (tester) async {
    await _pumpApp(
      tester,
      repository: FakeAuthRepository(sessionUser: FakeAuthRepository.maria),
    );

    expect(find.text('Nenhum produto cadastrado.'), findsOneWidget);
  });
}
