import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/entities/user_settings.dart';

/// The logged-in user's settings, loaded from the backend. Reloads when another user logs in;
/// logged out = defaults (nothing is asked to the backend), so the login screen is dark.
class UserSettingsController extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    final userId = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    if (userId == null) return UserSettings.defaults;
    return ref.read(settingsRepositoryProvider).get();
  }

  /// Saves the options given. Throws [Failure] on error (the current settings stay).
  Future<UserSettings> save({
    bool? requireProductImage,
    bool? createProductsOnImport,
    ThemePreference? theme,
    bool? notifyRestock,
  }) async {
    final saved = await ref
        .read(settingsRepositoryProvider)
        .update(
          requireProductImage: requireProductImage,
          createProductsOnImport: createProductsOnImport,
          theme: theme,
          notifyRestock: notifyRestock,
        );
    state = AsyncData(saved);
    return saved;
  }
}

/// The theme the app shows: the user's choice, or dark (default) while logged out or loading.
/// While another user's settings load, the previous value is kept (no flash between themes).
final themePreferenceProvider = Provider<ThemePreference>(
  (ref) =>
      ref.watch(userSettingsProvider.select((s) => s.value?.theme)) ??
      ThemePreference.dark,
);

final userSettingsProvider =
    AsyncNotifierProvider<UserSettingsController, UserSettings>(
      UserSettingsController.new,
    );
