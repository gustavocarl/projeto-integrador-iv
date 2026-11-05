import '../../../store/data/models/store_model.dart';
import '../../domain/entities/user.dart';

/// JSON representation of the backend's `UserResponse`.
abstract final class UserModel {
  static User fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    store: switch (json['store']) {
      final Map<String, dynamic> store => StoreModel.membershipFromJson(store),
      _ => null,
    },
  );
}
