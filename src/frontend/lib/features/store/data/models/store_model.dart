import '../../domain/entities/store.dart';

/// JSON of the backend's `StoreMembershipResponse` and `StoreMemberResponse`.
abstract final class StoreModel {
  static StoreMembership membershipFromJson(Map<String, dynamic> json) =>
      StoreMembership(
        id: json['id'] as String,
        name: json['name'] as String,
        role: StoreRole.parse(json['role'] as String?),
        areas: StoreArea.parseAll(json['areas'] as List<dynamic>?),
      );

  static StoreMember memberFromJson(Map<String, dynamic> json) => StoreMember(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    role: StoreRole.parse(json['role'] as String?),
    areas: StoreArea.parseAll(json['areas'] as List<dynamic>?),
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  /// Areas in the menu order, as the backend expects.
  static List<String> areasToJson(Set<StoreArea> areas) => [
    for (final area in StoreArea.values)
      if (areas.contains(area)) area.apiValue,
  ];
}
