/// An error message tied to a form field (`key`), or general when `key` is empty.
class FieldError {
  const FieldError(this.key, this.message);

  final String key;
  final String message;

  bool get isGeneral => key.isEmpty;
}

/// The single error type used by the app.
///
/// Repositories throw it; screens never build error messages themselves —
/// they let [BaseState] catch it and hand it to an [ErrorNotifier].
class Failure implements Exception {
  const Failure(this.message, {this.statusCode, this.errors = const []});

  /// Builds a failure from the backend's standard error body:
  /// `{ "status": 400, "title": "...", "errors": [ { "key": "email", "message": "..." } ] }`.
  factory Failure.fromResponse(int statusCode, Object? body) {
    if (body is! Map<String, dynamic>) {
      return Failure.unexpected(statusCode: statusCode);
    }

    final errors = (body['errors'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => FieldError(
            e['key'] as String? ?? '',
            e['message'] as String? ?? '',
          ),
        )
        .where((e) => e.message.isNotEmpty)
        .toList();

    return Failure(
      body['title'] as String? ?? _unexpectedMessage,
      statusCode: statusCode,
      errors: errors,
    );
  }

  factory Failure.connection() => const Failure(
    'Não foi possível conectar ao servidor. Verifique sua internet.',
  );

  factory Failure.unexpected({int? statusCode}) =>
      Failure(_unexpectedMessage, statusCode: statusCode);

  static const _unexpectedMessage =
      'Ocorreu um erro inesperado. Tente novamente mais tarde.';

  final String message;
  final int? statusCode;
  final List<FieldError> errors;

  bool get isUnauthorized => statusCode == 401;

  /// Messages not tied to a field, or [message] when there are none.
  List<String> get generalMessages {
    final general = errors
        .where((e) => e.isGeneral)
        .map((e) => e.message)
        .toList();
    return general.isEmpty ? [message] : general;
  }

  /// Messages for one form field, joined by line breaks; null when the field has no errors.
  String? messageFor(String key) {
    final messages = errors.where((e) => e.key == key).map((e) => e.message);
    return messages.isEmpty ? null : messages.join('\n');
  }

  @override
  String toString() => 'Failure($statusCode): $message';
}
