import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/session/access_changed_signal.dart';
import '../../../../core/session/session_expired_signal.dart';
import '../../../store/data/repositories/store_repository_impl.dart';
import '../../../store/domain/repositories/store_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';

/// The logged-in user (null = logged out). Restores the saved session on startup.
class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    ref.listen(
      sessionExpiredSignalProvider,
      (_, _) => state = const AsyncData(null),
    );
    ref.listen(accessChangedSignalProvider, (_, _) => refreshProfile());

    try {
      return await ref.read(authRepositoryProvider).restoreSession();
    } catch (_) {
      // Backend unreachable at startup: show the login screen instead of an error.
      return null;
    }
  }

  /// Throws [Failure] on error, so the screen's [BaseState.runSafely] can show it.
  Future<User> login(String email, String password) async {
    final user = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    state = AsyncData(user);
    return user;
  }

  /// Creates the account and logs in. [storeName]: a new name opens the store, an existing
  /// one asks its admin for access. Throws [Failure] on error.
  Future<User> register(
    String name,
    String email,
    String password, {
    String? storeName,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .register(
          name: name,
          email: email,
          password: password,
          storeName: storeName,
        );
    state = AsyncData(user);
    return user;
  }

  bool _refreshing = false;

  /// Reloads the profile (store, role, areas) without a loading state: the [AuthGate] and the
  /// menu follow what an admin changed. Failures keep the current user.
  Future<void> refreshProfile() async {
    if (_refreshing || state.value == null) return;
    _refreshing = true;
    try {
      state = AsyncData(await ref.read(authRepositoryProvider).currentUser());
    } on Failure {
      // 401 already logs out (SessionExpiredSignal); other errors: keep what we have.
    } finally {
      _refreshing = false;
    }
  }

  /// A new name opens the store (admin); an existing one asks its admin for access.
  /// Throws [Failure] on error.
  Future<User> enterStore(String name) =>
      _storeChange((stores) => stores.enterStore(name));

  /// Admin only. Throws [Failure] on error.
  Future<User> renameStore(String name) =>
      _storeChange((stores) => stores.renameStore(name));

  Future<User> _storeChange(
    Future<User> Function(StoreRepository stores) change,
  ) async {
    final user = await change(ref.read(storeRepositoryProvider));
    state = AsyncData(user);
    return user;
  }

  /// Throws [Failure] on error. Nobody is logged in: the user signs in afterwards.
  Future<void> resetPassword(String email, String newPassword) => ref
      .read(authRepositoryProvider)
      .resetPassword(email: email, newPassword: newPassword);

  /// Throws [Failure] on error. The session stays the same (the token is still valid).
  Future<void> changePassword(String currentPassword, String newPassword) => ref
      .read(authRepositoryProvider)
      .changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);
