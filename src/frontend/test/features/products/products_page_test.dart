import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/core/files/file_service.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:univesp_project/features/products/data/repositories/product_repository_impl.dart';
import 'package:univesp_project/features/products/presentation/pages/products_page.dart';

import 'package:univesp_project/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:univesp_project/features/settings/domain/entities/user_settings.dart';

import '../../helpers/fakes.dart';

Future<FakeProductRepository> _pump(
  WidgetTester tester, [
  FakeProductRepository? repository,
]) async {
  tester.view.physicalSize = const Size(500, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo =
      repository ??
      FakeProductRepository([
        fakeCatalogProduct(),
        fakeCatalogProduct(
          id: 'p-2',
          name: 'Notebook Pro 14',
          sku: 'NB-14',
          category: 'Notebooks',
          salePrice: 6000,
          costPrice: null,
          stock: 1,
          minimumStock: 2,
        ),
        fakeCatalogProduct(id: 'p-3', name: 'Cabo VGA', sku: 'VGA', stock: 0),
        fakeCatalogProduct(
          id: 'p-4',
          name: 'Webcam antiga',
          sku: 'CAM-1',
          isActive: false,
        ),
      ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [productRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: ProductsPage()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  testWidgets('lists active products with their stock situation', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('3 produtos · 2 precisam de reposição'), findsOneWidget);
    expect(find.text('Estoque: 10'), findsOneWidget);
    expect(find.text('Estoque baixo: 1'), findsOneWidget);
    expect(find.text('Sem estoque'), findsOneWidget);
    expect(find.text('margem 50,0%'), findsNWidgets(2));
    expect(find.text('Webcam antiga'), findsNothing);

    await tester.tap(find.text('Mostrar inativos'));
    await tester.pumpAndSettle();
    expect(find.text('Webcam antiga'), findsOneWidget);
    expect(find.text('CAM-1 · Periféricos · Inativo'), findsOneWidget);
  });

  testWidgets('searches and filters by category', (tester) async {
    final repo = await _pump(tester);

    await tester.enterText(find.byType(TextField), 'nb');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(repo.filters.last.search, 'nb');
    expect(find.text('Notebook Pro 14'), findsOneWidget);
    expect(find.text('Mouse sem fio'), findsNothing);

    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notebooks').last);
    await tester.pumpAndSettle();

    expect(repo.filters.last.category, 'Notebooks');
    expect(find.text('1 produto · 1 precisa de reposição'), findsOneWidget);
  });

  testWidgets(
    'a cost above the sale price warns while typing and the backend error shows on the cost',
    (tester) async {
      final repo = await _pump(tester, FakeProductRepository());
      repo.saveFailure = const Failure(
        'Dados inválidos.',
        statusCode: 400,
        errors: [
          FieldError(
            'costPrice',
            'O preço de custo não pode ser maior que o preço de venda: cada venda daria prejuízo.',
          ),
        ],
      );

      await tester.tap(find.text('Novo produto'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Nome'), 'Teclado mecânico');
      await tester.enterText(_field('SKU'), 'tec-01');
      await tester.enterText(_field('Preço de venda'), '100');
      await tester.enterText(_field('Custo (opcional)'), '120');
      await tester.pump();

      final warning = find.text(
        'O custo não pode ser maior que o preço de venda: cada venda daria '
        'prejuízo de ${brl('20,00')}.',
      );
      expect(warning, findsOneWidget);
      final context = tester.element(warning);
      expect(
        tester.widget<Text>(warning).style?.color,
        Theme.of(context).colorScheme.error,
      );

      await tester.enterText(_field('Em estoque'), '1');
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'O preço de custo não pode ser maior que o preço de venda: cada venda daria prejuízo.',
        ),
        findsOneWidget,
      );

      await tester.enterText(_field('Custo (opcional)'), '100');
      await tester.pump();
      expect(
        find.text('Margem de 0,0%: lucro de ${brl('0,00')} por unidade.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('creates a product and shows the margin while typing', (
    tester,
  ) async {
    final repo = await _pump(tester, FakeProductRepository());
    expect(find.text('Nenhum produto cadastrado.'), findsOneWidget);

    await tester.tap(find.text('Novo produto'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Nome'), 'Teclado mecânico');
    await tester.enterText(_field('SKU'), 'tec-01');
    await tester.enterText(_field('Preço de venda'), '250,00');
    await tester.enterText(_field('Custo (opcional)'), '150');
    await tester.pump();
    expect(
      find.text('Margem de 40,0%: lucro de ${brl('100,00')} por unidade.'),
      findsOneWidget,
    );
    await tester.enterText(_field('Em estoque'), '12');
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    final input = repo.saved.single;
    expect(
      (
        input.name,
        input.sku,
        input.salePrice,
        input.costPrice,
        input.stockQuantity,
        input.isActive,
      ),
      ('Teclado mecânico', 'tec-01', 250.0, 150.0, 12, true),
    );
    expect(find.text('Produto "Teclado mecânico" cadastrado.'), findsOneWidget);
    expect(find.text('Teclado mecânico'), findsOneWidget);
  });

  testWidgets('shows backend errors under each field', (tester) async {
    final repo = await _pump(tester, FakeProductRepository())
      ..saveFailure = Failure.fromResponse(409, {
        'errors': [
          {'key': 'sku', 'message': 'Já existe um produto com o SKU TEC-01.'},
        ],
      });

    await tester.tap(find.text('Novo produto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(repo.saved, hasLength(1));
    expect(find.text('Já existe um produto com o SKU TEC-01.'), findsWidgets);
    expect(find.text('Novo produto'), findsWidgets); // still on the form
  });

  testWidgets('a sold product can be deactivated but not deleted', (
    tester,
  ) async {
    final repo = await _pump(tester)
      ..deleteFailure = Failure.fromResponse(409, {
        'errors': [
          {
            'key': '',
            'message': 'Este produto já tem vendas e não pode ser excluído.',
          },
        ],
      });

    await tester.tap(find.text('Mouse sem fio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir produto'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(
      find.text('Este produto já tem vendas e não pode ser excluído.'),
      findsOneWidget,
    );

    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(repo.saved.single.isActive, isFalse);
    expect(find.text('Produto atualizado.'), findsOneWidget);
    expect(find.text('Mouse sem fio'), findsNothing); // inactive: hidden
  });

  testWidgets(
    'the image link is optional by default and is sent with the product',
    (tester) async {
      final repo = await _pump(tester, FakeProductRepository());

      await tester.tap(find.text('Novo produto'));
      await tester.pumpAndSettle();
      expect(_field('Imagem (opcional)'), findsOneWidget);
      await tester.enterText(
        _field('Imagem (opcional)'),
        ' https://cdn.test/mouse.png ',
      );
      await tester.enterText(_field('Nome'), 'Mouse');
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();

      expect(repo.saved.single.imageUrl, 'https://cdn.test/mouse.png');
    },
  );

  testWidgets('the form says the image is required by the user setting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeProductRepository()
      ..saveFailure = Failure.fromResponse(400, {
        'errors': [
          {
            'key': 'imageUrl',
            'message': 'A imagem do produto é obrigatória (definido nas suas configurações).',
          },
        ],
      });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(repo),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(sessionUser: FakeAuthRepository.maria),
          ),
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(
              const UserSettings(requireProductImage: true),
            ),
          ),
        ],
        child: const MaterialApp(home: ProductsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Novo produto'));
    await tester.pumpAndSettle();
    expect(_field('Imagem (obrigatória)'), findsOneWidget);
    expect(
      find.text('Suas configurações exigem imagem nos produtos.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'A imagem do produto é obrigatória (definido nas suas configurações).',
      ),
      findsWidgets,
    );
  });

  testWidgets('a photo file is uploaded and its path goes with the product', (
    tester,
  ) async {
    final repo = FakeProductRepository();
    final files = FakeFileService()
      ..fileToPick = PickedFile(
        name: 'mouse.png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
    await _pumpWithFiles(tester, repo, files);

    await tester.tap(find.text('Novo produto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar arquivo'));
    await tester.pumpAndSettle();

    expect(repo.uploaded, ['mouse.png']);
    expect(find.text('/uploads/products/1.png'), findsOneWidget);

    await tester.enterText(_field('Nome'), 'Mouse');
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();
    expect(repo.saved.single.imageUrl, '/uploads/products/1.png');
  });

  testWidgets(
    'a refused photo file shows the backend message under the field',
    (tester) async {
      final repo = FakeProductRepository()
        ..uploadFailure = Failure.fromResponse(400, {
          'errors': [
            {
              'key': 'file',
              'message': 'Formato não suportado. Envie uma imagem PNG, JPEG, WebP ou GIF.',
            },
          ],
        });
      final files = FakeFileService()
        ..fileToPick = PickedFile(
          name: 'planilha.xlsx',
          bytes: Uint8List.fromList([1]),
        );
      await _pumpWithFiles(tester, repo, files);

      await tester.tap(find.text('Novo produto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar arquivo'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Formato não suportado. Envie uma imagem PNG, JPEG, WebP ou GIF.',
        ),
        findsWidgets,
      );
      expect(repo.saved, isEmpty);
    },
  );
}

Future<void> _pumpWithFiles(
  WidgetTester tester,
  FakeProductRepository repo,
  FakeFileService files,
) async {
  tester.view.physicalSize = const Size(500, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWithValue(repo),
        fileServiceProvider.overrideWithValue(files),
      ],
      child: const MaterialApp(home: ProductsPage()),
    ),
  );
  await tester.pumpAndSettle();
}
