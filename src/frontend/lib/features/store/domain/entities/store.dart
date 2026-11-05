/// Parts of the app an admin gives to each member. Admins always have all of them.
enum StoreArea {
  products('Products'),
  checkout('Checkout'),
  imports('Imports'),
  exports('Exports'),
  comparison('Comparison'),
  analytics('Analytics');

  const StoreArea(this.apiValue);

  /// Name used by the backend.
  final String apiValue;

  static StoreArea? parse(String value) {
    for (final area in values) {
      if (area.apiValue.toLowerCase() == value.toLowerCase()) return area;
    }
    return null;
  }

  /// Unknown names are ignored (an older app talking to a newer backend).
  static Set<StoreArea> parseAll(Iterable<dynamic>? names) => {
    for (final name in names ?? const [])
      if (name is String) ?parse(name),
  };
}

enum StoreRole {
  admin('Admin'),
  member('Member'),
  pending('Pending');

  const StoreRole(this.apiValue);

  final String apiValue;

  /// Unknown → [pending]: never gives more access than the backend did.
  static StoreRole parse(String? value) => values.firstWhere(
    (role) => role.apiValue.toLowerCase() == value?.toLowerCase(),
    orElse: () => pending,
  );
}

/// The logged-in user's store.
class StoreMembership {
  const StoreMembership({
    required this.id,
    required this.name,
    required this.role,
    required this.areas,
  });

  final String id;
  final String name;
  final StoreRole role;

  /// What the user may use (all of them for admins).
  final Set<StoreArea> areas;

  bool get isAdmin => role == StoreRole.admin;
  bool get isPending => role == StoreRole.pending;
  bool get hasAccess => !isPending;

  bool can(StoreArea area) => hasAccess && areas.contains(area);
}

/// A user of the admin's store (pending requests too).
class StoreMember {
  const StoreMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.areas,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final StoreRole role;
  final Set<StoreArea> areas;
  final DateTime createdAt;

  bool get isPending => role == StoreRole.pending;
  bool get isAdmin => role == StoreRole.admin;
}
