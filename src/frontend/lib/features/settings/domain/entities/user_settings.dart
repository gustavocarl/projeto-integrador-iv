/// The app's color theme chosen by the user (backend values "Dark" and "Light").
enum ThemePreference {
  dark('Dark'),
  light('Light');

  const ThemePreference(this.apiValue);

  final String apiValue;

  /// Unknown or missing values fall back to dark, the default.
  static ThemePreference parse(String? value) =>
      values.firstWhere((t) => t.apiValue == value, orElse: () => dark);
}

/// The logged-in user's preferences (backend table `user_settings`).
/// Options start off, except the restock warnings (on); the theme starts dark.
class UserSettings {
  const UserSettings({
    this.requireProductImage = false,
    this.createProductsOnImport = false,
    this.theme = ThemePreference.dark,
    this.notifyRestock = true,
  });

  /// Nobody logged in, or the user never changed anything.
  static const defaults = UserSettings();

  /// Products this user saves must have an image.
  final bool requireProductImage;

  /// Importing a spreadsheet registers its SKUs that aren't in the catalog yet as products.
  final bool createProductsOnImport;

  /// The app's color theme.
  final ThemePreference theme;

  /// Warn about products at or below their minimum stock (menu badge, after a sale).
  final bool notifyRestock;

  @override
  bool operator ==(Object other) =>
      other is UserSettings &&
      other.requireProductImage == requireProductImage &&
      other.createProductsOnImport == createProductsOnImport &&
      other.theme == theme &&
      other.notifyRestock == notifyRestock;

  @override
  int get hashCode => Object.hash(
    requireProductImage,
    createProductsOnImport,
    theme,
    notifyRestock,
  );
}
