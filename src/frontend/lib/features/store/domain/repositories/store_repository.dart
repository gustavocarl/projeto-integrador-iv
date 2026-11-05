import '../../../auth/domain/entities/user.dart';
import '../entities/store.dart';

/// The user's store and, for admins, its users. Methods throw [Failure] on error.
abstract interface class StoreRepository {
  /// A store with this name (accents and casing don't matter) gets an access request and its
  /// admins are notified; a new name opens the store with the user as admin. Error key: `name`.
  Future<User> enterStore(String name);

  /// Admin only. Error key: `name` (409 when another store has the name).
  Future<User> renameStore(String name);

  /// Admin only. Pending requests first.
  Future<List<StoreMember>> listMembers();

  /// Approves a request with the chosen [areas].
  Future<StoreMember> approve(String memberId, Set<StoreArea> areas);

  Future<StoreMember> changeRole(String memberId, StoreRole role);

  /// Areas of a member (admins always have all).
  Future<StoreMember> updateAreas(String memberId, Set<StoreArea> areas);

  /// Removes a user or refuses a request. The last admin can't be removed (409).
  Future<void> remove(String memberId);
}
