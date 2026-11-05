import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/app/app.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:univesp_project/features/products/data/repositories/product_repository_impl.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:univesp_project/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:univesp_project/features/store/data/repositories/store_repository_impl.dart';

import '../../helpers/fakes.dart';

Future<FakeAuthRepository> _pumpLogin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        productRepositoryProvider.overrideWithValue(FakeProductRepository()),
        salesRepositoryProvider.overrideWithValue(FakeSalesRepository()),
        storeRepositoryProvider.overrideWithValue(FakeStoreRepository()),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _openFromLogin(WidgetTester tester, String link) async {
  await tester.ensureVisible(find.text(link));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, link));
  await tester.pumpAndSettle();
}

void main() {
  group('Criar conta', () {
    testWidgets('creates the account and opens the app logged in', (
      tester,
    ) async {
      final auth = await _pumpLogin(tester);
      await tester.enterText(_field('E-mail'), 'ana@exemplo.com');
      await _openFromLogin(tester, 'Criar conta');

      expect(find.widgetWithText(AppBar, 'Criar conta'), findsOneWidget);
      // The e-mail typed on the login comes along.
      expect(find.text('ana@exemplo.com'), findsOneWidget);

      await tester.enterText(_field('Nome'), '  Ana Souza ');
      await tester.enterText(_field('Senha'), 'Senha123');
      await tester.enterText(_field('Confirmar senha'), 'Senha123');
      await tester.enterText(_field('Nome da loja'), ' Loja da Ana ');
      await _tapButton(tester, 'Criar conta');

      expect(auth.registered, [('Ana Souza', 'ana@exemplo.com', 'Senha123')]);
      expect(auth.registeredStores, ['name:Loja da Ana']);
      expect(find.widgetWithText(AppBar, 'Produtos'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Criar conta'), findsNothing);
    });

    testWidgets('the name of an existing store waits for its admin', (
      tester,
    ) async {
      final auth = await _pumpLogin(tester);
      await _openFromLogin(tester, 'Criar conta');

      await tester.enterText(_field('Nome'), 'João');
      await tester.enterText(_field('E-mail'), 'joao@exemplo.com');
      await tester.enterText(_field('Senha'), 'Senha123');
      await tester.enterText(_field('Confirmar senha'), 'Senha123');
      // Casing and accents don't matter: same store.
      await tester.enterText(_field('Nome da loja'), 'marcelo eletrônicos');
      await _tapButton(tester, 'Criar conta');

      expect(auth.registeredStores, ['name:marcelo eletrônicos']);
      expect(find.byKey(const Key('pendingCard')), findsOneWidget);
      expect(find.textContaining('Marcelo Eletrônicos'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('checks the fields and the confirmation before calling', (
      tester,
    ) async {
      final auth = await _pumpLogin(tester);
      await _openFromLogin(tester, 'Criar conta');

      await tester.enterText(_field('E-mail'), 'ana');
      await tester.enterText(_field('Senha'), 'Senha123');
      await tester.enterText(_field('Confirmar senha'), 'Senha124');
      await _tapButton(tester, 'Criar conta');

      expect(find.text('Informe o nome.'), findsOneWidget);
      expect(find.text('E-mail inválido.'), findsOneWidget);
      expect(find.text('As senhas não conferem.'), findsOneWidget);
      expect(find.text('Informe o nome da loja.'), findsOneWidget);
      expect(auth.registered, isEmpty);
    });

    testWidgets('an e-mail already in use shows under the e-mail', (
      tester,
    ) async {
      await _pumpLogin(tester);
      await _openFromLogin(tester, 'Criar conta');

      await tester.enterText(_field('Nome'), 'Maria');
      await tester.enterText(_field('E-mail'), FakeAuthRepository.validEmail);
      await tester.enterText(_field('Senha'), 'Senha123');
      await tester.enterText(_field('Confirmar senha'), 'Senha123');
      await tester.enterText(_field('Nome da loja'), 'Outra loja');
      await _tapButton(tester, 'Criar conta');

      expect(
        find.text('Já existe um usuário cadastrado com este e-mail.'),
        findsWidgets,
      );
      expect(find.widgetWithText(AppBar, 'Criar conta'), findsOneWidget);
    });
  });

  group('Esqueci minha senha', () {
    testWidgets('sets a new password and the login accepts it', (tester) async {
      final auth = await _pumpLogin(tester);
      await tester.enterText(_field('E-mail'), FakeAuthRepository.validEmail);
      await _openFromLogin(tester, 'Esqueci minha senha');

      expect(find.widgetWithText(AppBar, 'Recuperar senha'), findsOneWidget);
      await tester.enterText(_field('Nova senha'), 'NovaSenha456');
      await tester.enterText(_field('Confirmar nova senha'), 'NovaSenha456');
      await _tapButton(tester, 'Salvar nova senha');

      expect(auth.resets, [(FakeAuthRepository.validEmail, 'NovaSenha456')]);
      // Back on the login, with the e-mail filled in.
      expect(
        find.text('Senha alterada. Entre com a nova senha.'),
        findsOneWidget,
      );
      expect(find.text(FakeAuthRepository.validEmail), findsOneWidget);

      await tester.enterText(_field('Senha'), 'NovaSenha456');
      await _tapButton(tester, 'Entrar');
      expect(find.widgetWithText(AppBar, 'Produtos'), findsOneWidget);
    });

    testWidgets('an unknown e-mail shows under the e-mail', (tester) async {
      final auth = await _pumpLogin(tester);
      await _openFromLogin(tester, 'Esqueci minha senha');

      await tester.enterText(_field('E-mail'), 'joao@exemplo.com');
      await tester.enterText(_field('Nova senha'), 'NovaSenha456');
      await tester.enterText(_field('Confirmar nova senha'), 'NovaSenha456');
      await _tapButton(tester, 'Salvar nova senha');

      expect(
        find.text('Nenhum usuário cadastrado com este e-mail.'),
        findsWidgets,
      );
      expect(auth.resets, isEmpty);
      expect(find.widgetWithText(AppBar, 'Recuperar senha'), findsOneWidget);
    });
  });
}
