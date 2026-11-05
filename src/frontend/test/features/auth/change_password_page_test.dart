import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/files/file_service.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:univesp_project/features/home/presentation/pages/home_shell.dart';
import 'package:univesp_project/features/products/data/repositories/product_repository_impl.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:univesp_project/features/store/data/repositories/store_repository_impl.dart';

import '../../helpers/fakes.dart';

Future<FakeAuthRepository> _openChangePassword(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository(sessionUser: FakeAuthRepository.maria);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storeRepositoryProvider.overrideWithValue(FakeStoreRepository()),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        productRepositoryProvider.overrideWithValue(FakeProductRepository()),
        salesRepositoryProvider.overrideWithValue(FakeSalesRepository()),
        fileServiceProvider.overrideWithValue(FakeFileService()),
      ],
      child: MaterialApp(home: HomeShell(user: FakeAuthRepository.maria)),
    ),
  );
  await tester.pumpAndSettle();

  // User button → "Configurações do usuário" → "Alterar senha".
  await tester.tap(find.byTooltip('Conta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Configurações do usuário'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Alterar senha'));
  await tester.pumpAndSettle();
  expect(find.widgetWithText(AppBar, 'Alterar senha'), findsOneWidget);
  return auth;
}

Future<void> _fill(
  WidgetTester tester, {
  required String current,
  required String newPassword,
  String? confirmation,
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Senha atual'),
    current,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nova senha'),
    newPassword,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Confirmar nova senha'),
    confirmation ?? newPassword,
  );
  await tester.tap(find.text('Salvar nova senha'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('changes the password and goes back with a message', (
    tester,
  ) async {
    final auth = await _openChangePassword(tester);

    await _fill(tester, current: 'Senha123', newPassword: 'NovaSenha456');

    expect(auth.password, 'NovaSenha456');
    expect(find.widgetWithText(AppBar, 'Alterar senha'), findsNothing);
    expect(find.text('Senha alterada.'), findsOneWidget);
    // Still logged in.
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('wrong current password shows under its field', (tester) async {
    final auth = await _openChangePassword(tester);

    await _fill(tester, current: 'Errada123', newPassword: 'NovaSenha456');

    expect(find.text('A senha atual está incorreta.'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Alterar senha'), findsOneWidget);
    expect(auth.password, 'Senha123');
  });

  testWidgets('confirmation must match before sending', (tester) async {
    final auth = await _openChangePassword(tester);

    await _fill(
      tester,
      current: 'Senha123',
      newPassword: 'NovaSenha456',
      confirmation: 'OutraSenha789',
    );

    expect(find.text('As senhas não conferem.'), findsOneWidget);
    expect(auth.password, 'Senha123');
  });

  testWidgets('the eye button shows and hides the three passwords', (
    tester,
  ) async {
    await _openChangePassword(tester);

    bool obscured(String label) => tester
        .widget<EditableText>(
          find.descendant(
            of: find.widgetWithText(TextFormField, label),
            matching: find.byType(EditableText),
          ),
        )
        .obscureText;

    expect(obscured('Confirmar nova senha'), isTrue);
    await tester.tap(find.byTooltip('Mostrar senhas'));
    await tester.pump();
    expect(obscured('Senha atual'), isFalse);
    expect(obscured('Confirmar nova senha'), isFalse);
  });
}
