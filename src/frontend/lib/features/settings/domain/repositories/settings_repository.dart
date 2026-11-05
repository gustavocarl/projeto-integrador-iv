import '../entities/user_settings.dart';

/// The logged-in user's settings. Methods throw [Failure] on error.
abstract interface class SettingsRepository {
  Future<UserSettings> get();

  /// Changes only the options given (null keeps the saved value); returns every setting as saved.
  Future<UserSettings> update({
    bool? requireProductImage,
    bool? createProductsOnImport,
    ThemePreference? theme,
    bool? notifyRestock,
  });
}
