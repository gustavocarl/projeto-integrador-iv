import '../../domain/entities/user_settings.dart';

/// JSON mapping of the backend's `UserSettingsResponse`.
abstract final class UserSettingsModel {
  static UserSettings fromJson(Map<String, dynamic> json) => UserSettings(
    requireProductImage: json['requireProductImage'] as bool? ?? false,
    createProductsOnImport: json['createProductsOnImport'] as bool? ?? false,
    theme: ThemePreference.parse(json['theme'] as String?),
    notifyRestock: json['notifyRestock'] as bool? ?? true,
  );
}
