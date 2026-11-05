import '../entities/user.dart';

/// Authentication contract. Methods throw [Failure] on error.
abstract interface class AuthRepository {
  /// Signs in and stores the access token.
  Future<User> login({required String email, required String password});

  /// Creates the account and signs in (stores the access token), with no confirmation step.
  /// [storeName]: a new name opens the store (the user is its admin); the name of an existing
  /// store asks its admins for access (pending). Errors come under the keys `name`, `email`
  /// (409 when it is taken), `password` and `storeName`.
  Future<User> register({
    required String name,
    required String email,
    required String password,
    String? storeName,
  });

  /// Simple recovery (prototype): sets [newPassword] on the account of [email], with no
  /// confirmation. Errors under `email` (404 when unknown) and `newPassword`.
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  });

  /// Returns the user of the stored token, or null when there is no valid session.
  Future<User?> restoreSession();

  /// The logged-in user as the backend sees them now (store, role and areas may have changed).
  Future<User> currentUser();

  /// Replaces the logged-in user's password; the backend checks [currentPassword].
  /// Errors come under the keys `currentPassword` and `newPassword`.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Removes the stored token.
  Future<void> logout();
}
