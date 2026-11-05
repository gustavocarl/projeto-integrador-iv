import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/errors/base_state.dart';
import 'package:univesp_project/core/errors/failure.dart';

class _FormPage extends ConsumerStatefulWidget {
  const _FormPage({required this.action});

  final Future<String> Function() action;

  @override
  ConsumerState<_FormPage> createState() => _FormPageState();
}

class _FormPageState extends BaseState<_FormPage> {
  String? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(
            decoration: InputDecoration(errorText: fieldError('email')),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = await runSafely(widget.action);
              setState(() => result = value);
            },
            child: const Text('Enviar'),
          ),
          if (result != null) Text('ok: $result'),
        ],
      ),
    );
  }
}

Future<void> _pumpAndSubmit(
  WidgetTester tester,
  Future<String> Function() action,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: _FormPage(action: action)),
    ),
  );
  await tester.tap(find.text('Enviar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows general errors in a SnackBar and field errors under the field',
    (tester) async {
      await _pumpAndSubmit(tester, () async {
        throw const Failure(
          'Dados inválidos.',
          statusCode: 400,
          errors: [
            FieldError('', 'Erro geral.'),
            FieldError('email', 'E-mail inválido.'),
          ],
        );
      });

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Erro geral.'),
        ),
        findsOneWidget,
      );
      expect(find.text('E-mail inválido.'), findsOneWidget);
    },
  );

  testWidgets('unexpected exceptions become a generic message', (tester) async {
    await _pumpAndSubmit(tester, () async => throw StateError('boom'));

    expect(find.textContaining('erro inesperado'), findsOneWidget);
  });

  testWidgets('returns the value on success', (tester) async {
    await _pumpAndSubmit(tester, () async => 'feito');

    expect(find.text('ok: feito'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
