import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/app/app.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/core/files/file_service.dart';
import 'package:univesp_project/features/analytics/data/repositories/analytics_repository_impl.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:univesp_project/features/auth/domain/entities/user.dart';
import 'package:univesp_project/features/products/data/repositories/product_repository_impl.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_export_repository_impl.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:univesp_project/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:univesp_project/features/notifications/domain/entities/app_notification.dart';
import 'package:univesp_project/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:univesp_project/features/store/data/repositories/store_repository_impl.dart';
import 'package:univesp_project/features/store/domain/entities/store.dart';
import 'package:univesp_project/features/store/presentation/pages/store_users_page.dart';

import '../../helpers/fakes.dart';

User _member(Set<StoreArea> areas, {StoreRole role = StoreRole.member}) => User(
  id: '2',
  name: 'João Souza',
  email: 'joao@exemplo.com',
  store: StoreMembership(
    id: 's1',
    name: 'Marcelo Eletrônicos',
    role: role,
    areas: areas,
  ),
);

/// The whole app (AuthGate) with [user] logged in.
Future<(FakeAuthRepository, FakeStoreRepository, FakeSalesRepository)> _pumpApp(
  WidgetTester tester,
  User? user, {
  FakeStoreRepository? stores,
  FakeNotificationRepository? notifications,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository(sessionUser: user);
  final storeRepository = stores ?? FakeStoreRepository();
  final sales = FakeSalesRepository([fakeImport()]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        storeRepositoryProvider.overrideWithValue(storeRepository),
        notificationRepositoryProvider.overrideWithValue(
          notifications ?? FakeNotificationRepository(),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        productRepositoryProvider.overrideWithValue(
          FakeProductRepository([fakeCatalogProduct()]),
        ),
        salesRepositoryProvider.overrideWithValue(sales),
        salesExportRepositoryProvider.overrideWithValue(
          FakeSalesExportRepository(),
        ),
        analyticsRepositoryProvider.overrideWithValue(
          FakeAnalyticsRepository(),
        ),
        fileServiceProvider.overrideWithValue(FakeFileService()),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
  return (auth, storeRepository, sales);
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  group('Main menu by area', () {
    testWidgets('a member sees only the parts the admin gave', (tester) async {
      await _pumpApp(tester, _member({StoreArea.checkout, StoreArea.imports}));

      final bar = find.byType(NavigationBar);
      expect(bar, findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.byType(NavigationDestination)),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: bar, matching: find.text('Vender')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('Produtos')),
        findsNothing,
      );
      // The first part left opens.
      expect(find.widgetWithText(AppBar, 'Venda de produtos'), findsOneWidget);
    });

    testWidgets('a single part opens without a menu', (tester) async {
      final (_, _, sales) = await _pumpApp(
        tester,
        _member({StoreArea.checkout}),
      );

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.widgetWithText(AppBar, 'Venda de produtos'), findsOneWidget);
      // The checkout never asks for the batches (Importar is not given).
      expect(sales.listCalls, 0);
    });

    testWidgets('no part given: a clear message', (tester) async {
      await _pumpApp(tester, _member({}));

      expect(find.byKey(const Key('noAreas')), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('only admins have "Loja e usuários", with pending requests', (
      tester,
    ) async {
      final stores = FakeStoreRepository(
        members: [
          fakeMember(id: '1', name: 'Maria Silva', role: StoreRole.admin),
          fakeMember(
            id: 'p1',
            name: 'Zeca Lima',
            role: StoreRole.pending,
            areas: {},
          ),
        ],
      );
      await _pumpApp(tester, FakeAuthRepository.maria, stores: stores);

      await tester.tap(find.byTooltip('Conta'));
      await tester.pumpAndSettle();
      expect(find.text('Loja e usuários'), findsOneWidget);
      expect(find.byKey(const Key('pendingBadge')), findsOneWidget);
      expect(find.text('Marcelo Eletrônicos · Admin'), findsOneWidget);
    });

    testWidgets('members have no store management', (tester) async {
      await _pumpApp(tester, _member({StoreArea.checkout, StoreArea.imports}));

      await tester.tap(find.byTooltip('Conta'));
      await tester.pumpAndSettle();
      expect(find.text('Loja e usuários'), findsNothing);
      expect(find.text('Marcelo Eletrônicos · Usuário'), findsOneWidget);
    });
  });

  group('Store access', () {
    testWidgets('without a store, the user opens their own', (tester) async {
      const removed = User(
        id: '2',
        name: 'João Souza',
        email: 'joao@exemplo.com',
      );
      final stores = FakeStoreRepository()
        ..onUserChange = (_, name) => User(
          id: '2',
          name: 'João Souza',
          email: 'joao@exemplo.com',
          store: StoreMembership(
            id: 's2',
            name: name,
            role: StoreRole.admin,
            areas: {...StoreArea.values},
          ),
        );
      await _pumpApp(tester, removed, stores: stores);

      expect(
        find.textContaining('não faz parte de nenhuma loja'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Informe o nome da loja.'), findsOneWidget);

      await tester.enterText(_field('Nome da loja'), ' Loja do João ');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();

      expect(stores.calls, ['enter:Loja do João']);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('an existing store name waits for its admin', (tester) async {
      const removed = User(
        id: '2',
        name: 'João Souza',
        email: 'joao@exemplo.com',
      );
      final stores = FakeStoreRepository()
        ..onUserChange = (_, _) => _member({}, role: StoreRole.pending);
      await _pumpApp(tester, removed, stores: stores);

      await tester.enterText(_field('Nome da loja'), 'marcelo eletronicos');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();

      expect(stores.calls, ['enter:marcelo eletronicos']);
      expect(find.byKey(const Key('pendingCard')), findsOneWidget);
      expect(
        find.textContaining('o admin recebeu uma notificação'),
        findsOneWidget,
      );
    });

    testWidgets('a refused name shows under the field', (tester) async {
      const removed = User(
        id: '2',
        name: 'João Souza',
        email: 'joao@exemplo.com',
      );
      final stores = FakeStoreRepository()
        ..failure = const Failure(
          'Dados inválidos.',
          statusCode: 400,
          errors: [
            FieldError(
              'name',
              'O nome da loja deve ter no máximo 100 caracteres.',
            ),
          ],
        );
      await _pumpApp(tester, removed, stores: stores);

      await tester.enterText(_field('Nome da loja'), 'L' * 101);
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: _field('Nome da loja'),
          matching: find.text(
            'O nome da loja deve ter no máximo 100 caracteres.',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('waiting: "Verificar agora" opens the app once approved', (
      tester,
    ) async {
      final (auth, _, _) = await _pumpApp(
        tester,
        _member({}, role: StoreRole.pending),
      );
      expect(find.byKey(const Key('pendingCard')), findsOneWidget);

      await tester.tap(find.text('Verificar agora'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pendingCard')), findsOneWidget);

      auth.serverUser = _member({StoreArea.checkout});
      await tester.tap(find.text('Verificar agora'));
      await tester.pumpAndSettle();

      expect(auth.currentUserCalls, 2);
      expect(find.widgetWithText(AppBar, 'Venda de produtos'), findsOneWidget);
    });
  });

  group('Loja e usuários', () {
    Future<FakeStoreRepository> pumpUsers(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final stores = FakeStoreRepository(
        members: [
          fakeMember(
            id: '1',
            name: 'Maria Silva',
            role: StoreRole.admin,
            areas: {...StoreArea.values},
          ),
          fakeMember(id: 'm1', name: 'João Souza'),
          fakeMember(
            id: 'p1',
            name: 'Zeca Lima',
            role: StoreRole.pending,
            areas: {},
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(sessionUser: FakeAuthRepository.maria),
            ),
            storeRepositoryProvider.overrideWithValue(stores),
            notificationRepositoryProvider.overrideWithValue(
              FakeNotificationRepository(),
            ),
          ],
          child: const MaterialApp(home: StoreUsersPage()),
        ),
      );
      await tester.pumpAndSettle();
      return stores;
    }

    testWidgets('shows the pending requests first', (tester) async {
      await pumpUsers(tester);

      expect(find.text('Marcelo Eletrônicos'), findsOneWidget);
      expect(find.text('Pedidos de acesso (1)'), findsOneWidget);
      expect(find.text('Usuários (2)'), findsOneWidget);
      expect(find.text('Maria Silva (você)'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Zeca Lima')).dy,
        lessThan(tester.getTopLeft(find.text('João Souza')).dy),
      );
    });

    testWidgets('approving lets the admin untick parts', (tester) async {
      final stores = await pumpUsers(tester);

      await tester.tap(find.text('Zeca Lima'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('area_imports')));
      await tester.tap(find.byKey(const Key('area_analytics')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveMember')));
      await tester.pumpAndSettle();

      expect(stores.calls, ['approve:p1:Products,Checkout,Exports,Comparison']);
      expect(find.text('Acesso de Zeca Lima aprovado.'), findsOneWidget);
      expect(find.text('Pedidos de acesso (1)'), findsNothing);
    });

    testWidgets(
      'changes the parts of a member, and only what changed is sent',
      (tester) async {
        final stores = await pumpUsers(tester);

        await tester.tap(find.text('João Souza'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('area_imports')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('saveMember')));
        await tester.pumpAndSettle();

        expect(stores.calls, ['areas:m1:Checkout,Imports']);
        expect(find.textContaining('Vender, Importar'), findsOneWidget);
      },
    );

    testWidgets('promoting to admin gives every part', (tester) async {
      final stores = await pumpUsers(tester);

      await tester.tap(find.text('João Souza'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Admin').last);
      await tester.pumpAndSettle();
      // Admins use everything: the parts can't be changed.
      final checkbox = tester.widget<CheckboxListTile>(
        find.byKey(const Key('area_products')),
      );
      expect(checkbox.value, isTrue);
      expect(checkbox.onChanged, isNull);
      await tester.tap(find.byKey(const Key('saveMember')));
      await tester.pumpAndSettle();

      expect(stores.calls, ['role:m1:Admin']);
      expect(find.textContaining('Admin · Todas as partes'), findsNWidgets(2));
    });

    testWidgets('removes a user after confirming', (tester) async {
      final stores = await pumpUsers(tester);

      await tester.tap(find.text('João Souza'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('removeMember')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();

      expect(stores.calls, ['remove:m1']);
      expect(find.text('João Souza foi removido da loja.'), findsOneWidget);
      expect(find.text('Usuários (1)'), findsOneWidget);
    });

    testWidgets('the backend refusal (last admin) is shown', (tester) async {
      final stores = await pumpUsers(tester);
      stores.failure = const Failure(
        'Conflito.',
        statusCode: 409,
        errors: [FieldError('', 'A loja precisa de pelo menos um admin.')],
      );

      await tester.tap(find.text('Maria Silva (você)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('removeMember')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
      await tester.pumpAndSettle();

      expect(
        find.text('A loja precisa de pelo menos um admin.'),
        findsOneWidget,
      );
      // Still on the member page.
      expect(find.byKey(const Key('removeMember')), findsOneWidget);
    });
  });

  group('Notificações', () {
    FakeStoreRepository storesWithRequest() => FakeStoreRepository(
      members: [
        fakeMember(
          id: '1',
          name: 'Maria Silva',
          role: StoreRole.admin,
          areas: {...StoreArea.values},
        ),
        fakeMember(
          id: 'm1',
          name: 'Zeca Lima',
          role: StoreRole.pending,
          areas: {},
        ),
      ],
    );

    Future<void> openBell(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('notificationsButton')));
      await tester.pumpAndSettle();
    }

    testWidgets('the bell counts the unread ones; a request opens to approve', (
      tester,
    ) async {
      final stores = storesWithRequest();
      final notifications = FakeNotificationRepository(
        items: [
          fakeNotification(
            message: 'Zeca Lima (zeca@exemplo.com) pediu acesso à loja.',
          ),
          fakeNotification(
            id: 'n0',
            kind: NotificationKind.accessApproved,
            message: 'Aviso antigo.',
            relatedUserId: null,
            read: true,
          ),
        ],
      );
      await _pumpApp(
        tester,
        FakeAuthRepository.maria,
        stores: stores,
        notifications: notifications,
      );

      expect(find.byTooltip('Notificações (1 não lida)'), findsOneWidget);
      await openBell(tester);
      expect(find.text('Toque para aprovar ou recusar'), findsNothing);
      expect(
        find.textContaining('Toque para aprovar ou recusar'),
        findsOneWidget,
      );

      await tester.tap(find.textContaining('pediu acesso'));
      await tester.pumpAndSettle();
      expect(notifications.calls, ['read:n1']);
      expect(
        find.widgetWithText(FilledButton, 'Aprovar acesso'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('saveMember')));
      await tester.pumpAndSettle();
      expect(stores.calls.single, startsWith('approve:m1:'));
      expect(find.text('Acesso de Zeca Lima aprovado.'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Notificações'), findsOneWidget);
      // Approving asks the bell again.
      expect(notifications.listCalls, greaterThanOrEqualTo(2));
    });

    testWidgets('a request already answered just says so', (tester) async {
      final notifications = FakeNotificationRepository(
        items: [fakeNotification(relatedUserId: 'gone')],
      );
      await _pumpApp(
        tester,
        FakeAuthRepository.maria,
        stores: storesWithRequest(),
        notifications: notifications,
      );

      await openBell(tester);
      await tester.tap(find.textContaining('pediu acesso'));
      await tester.pumpAndSettle();

      expect(find.text('Este pedido já foi respondido.'), findsOneWidget);
      expect(find.byKey(const Key('saveMember')), findsNothing);
    });

    testWidgets('"Marcar todas como lidas" clears the counter', (tester) async {
      final notifications = FakeNotificationRepository(
        items: [
          fakeNotification(),
          fakeNotification(id: 'n2', relatedUserId: 'm2'),
        ],
      );
      await _pumpApp(
        tester,
        FakeAuthRepository.maria,
        stores: storesWithRequest(),
        notifications: notifications,
      );
      expect(find.byTooltip('Notificações (2 não lidas)'), findsOneWidget);

      await openBell(tester);
      await tester.tap(find.byKey(const Key('markAllRead')));
      await tester.pumpAndSettle();

      expect(notifications.calls, ['readAll']);
      expect(find.byKey(const Key('markAllRead')), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notificações'), findsOneWidget);
    });

    testWidgets('empty center', (tester) async {
      await _pumpApp(tester, FakeAuthRepository.maria);

      await openBell(tester);

      expect(find.byKey(const Key('noNotifications')), findsOneWidget);
    });

    testWidgets('a new notification on the next check shows a message', (
      tester,
    ) async {
      final notifications = FakeNotificationRepository();
      final stores = storesWithRequest();
      await _pumpApp(
        tester,
        FakeAuthRepository.maria,
        stores: stores,
        notifications: notifications,
      );
      expect(find.byTooltip('Notificações'), findsOneWidget);

      notifications.items = [
        fakeNotification(message: 'Zeca Lima pediu acesso à loja.'),
      ];
      await tester.pump(NotificationsController.pollInterval);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Notificações (1 não lida)'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Zeca Lima pediu acesso à loja.'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(SnackBarAction, 'Ver'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Notificações'), findsOneWidget);
    });
  });
}
