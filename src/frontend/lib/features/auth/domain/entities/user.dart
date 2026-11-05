import '../../../store/domain/entities/store.dart';

/// The logged-in user. Their preferences are in the settings feature (`userSettingsProvider`).
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.store,
  });

  final String id;
  final String name;
  final String email;

  /// Null when the user has no store (removed by an admin).
  final StoreMembership? store;

  /// Approved in a store: the app opens. Otherwise the store access screen.
  bool get hasStoreAccess => store?.hasAccess ?? false;

  bool can(StoreArea area) => store?.can(area) ?? false;
}
