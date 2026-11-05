import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_notifier.dart';
import 'failure.dart';
import 'snackbar_error_notifier.dart';

/// Base for every screen state. Screens inherit it instead of handling errors themselves:
///
/// ```dart
/// class LoginPage extends ConsumerStatefulWidget { ... }
///
/// class _LoginPageState extends BaseState<LoginPage> {
///   Future<void> _submit() async {
///     final user = await runSafely(() => ref.read(authControllerProvider.notifier).login(email, password));
///     if (user != null) { /* success */ }
///   }
///
///   // In the form: TextField(decoration: InputDecoration(errorText: fieldError('email')))
/// }
/// ```
abstract class BaseState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  /// How errors are shown. Override to use a different [ErrorNotifier] on a specific screen.
  ErrorNotifier get errorNotifier => const SnackBarErrorNotifier();

  Failure? _failure;
  bool _isLoading = false;

  /// Last failure, kept so the form can show messages under each field.
  Failure? get failure => _failure;

  /// True while an action started by [runSafely] is running.
  bool get isLoading => _isLoading;

  /// Error message for a form field, to use as `InputDecoration.errorText`.
  String? fieldError(String key) => _failure?.messageFor(key);

  /// Runs [action], handling loading state and errors.
  ///
  /// Returns the result, or null when it failed — in that case the error has already
  /// been shown to the user through [errorNotifier].
  Future<R?> runSafely<R>(Future<R> Function() action) async {
    setState(() {
      _failure = null;
      _isLoading = true;
    });

    try {
      return await action();
    } on Failure catch (failure) {
      showFailure(failure);
    } catch (_) {
      showFailure(Failure.unexpected());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    return null;
  }

  /// Shows [failure] and keeps it for [fieldError].
  void showFailure(Failure failure) {
    if (!mounted) return;
    setState(() => _failure = failure);
    errorNotifier.notify(context, failure);
  }

  /// Clears the field messages (e.g. when the user edits the form again).
  void clearFailure() {
    if (_failure != null) setState(() => _failure = null);
  }
}
