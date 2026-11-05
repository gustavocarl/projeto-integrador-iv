import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/errors/failure.dart';

void main() {
  test('reads the backend error format', () {
    final failure = Failure.fromResponse(400, {
      'title': 'Dados inválidos.',
      'status': 400,
      'errors': [
        {'key': 'email', 'message': 'O e-mail informado é inválido.'},
        {'key': 'password', 'message': 'Mínimo 8 caracteres.'},
        {'key': 'password', 'message': 'Precisa de um número.'},
      ],
    });

    expect(failure.statusCode, 400);
    expect(failure.messageFor('email'), 'O e-mail informado é inválido.');
    expect(
      failure.messageFor('password'),
      'Mínimo 8 caracteres.\nPrecisa de um número.',
    );
    expect(failure.messageFor('name'), isNull);
    // No general error: falls back to the title.
    expect(failure.generalMessages, ['Dados inválidos.']);
  });

  test('general errors have an empty key', () {
    final failure = Failure.fromResponse(401, {
      'title': 'Não autorizado.',
      'errors': [
        {'key': '', 'message': 'E-mail ou senha inválidos.'},
      ],
    });

    expect(failure.isUnauthorized, isTrue);
    expect(failure.generalMessages, ['E-mail ou senha inválidos.']);
  });

  test('unknown body becomes an unexpected failure', () {
    final failure = Failure.fromResponse(502, '<html>Bad Gateway</html>');

    expect(failure.statusCode, 502);
    expect(failure.message, contains('erro inesperado'));
  });
}
