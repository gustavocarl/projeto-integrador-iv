import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../data/repositories/store_repository_impl.dart';
import '../../domain/entities/store.dart';

/// What the logged-in user may use (empty when logged out or without access).
final storeAreasProvider = Provider<Set<StoreArea>>((ref) {
  final store = ref.watch(authControllerProvider.select((s) => s.value?.store));
  return store != null && store.hasAccess ? store.areas : const {};
});

/// The admin's list of users (pending requests first). Reloads when the user changes.
class StoreMembersController extends AsyncNotifier<List<StoreMember>> {
  @override
  Future<List<StoreMember>> build() {
    ref.watch(authControllerProvider.select((s) => s.value?.id));
    return ref.read(storeRepositoryProvider).listMembers();
  }

  /// All the methods throw [Failure] on error (the list stays as it was).
  /// The request's notification is resolved by the backend: the bell follows.
  Future<StoreMember> approve(String id, Set<StoreArea> areas) async {
    final approved = _replace(
      await ref.read(storeRepositoryProvider).approve(id, areas),
    );
    _refreshNotifications();
    return approved;
  }

  /// Saves the role and, for members, the areas; only what changed is sent.
  Future<StoreMember> save(
    StoreMember member, {
    required StoreRole role,
    required Set<StoreArea> areas,
  }) async {
    final repository = ref.read(storeRepositoryProvider);
    var saved = member;
    if (role != member.role) {
      saved = _replace(await repository.changeRole(member.id, role));
    }
    if (role == StoreRole.member && !_sameAreas(saved.areas, areas)) {
      saved = _replace(await repository.updateAreas(member.id, areas));
    }
    return saved;
  }

  Future<void> remove(String id) async {
    await ref.read(storeRepositoryProvider).remove(id);
    final wasPending =
        state.value?.any((m) => m.id == id && m.isPending) ?? false;
    state = AsyncData([
      for (final m in state.value ?? const <StoreMember>[])
        if (m.id != id) m,
    ]);
    if (wasPending) _refreshNotifications();
  }

  void _refreshNotifications() =>
      ref.read(notificationsProvider.notifier).poll();

  StoreMember _replace(StoreMember updated) {
    state = AsyncData([
      for (final m in state.value ?? const <StoreMember>[])
        m.id == updated.id ? updated : m,
    ]);
    // The admin changed their own role: the menu and the gate must follow.
    if (updated.id == ref.read(authControllerProvider).value?.id) {
      ref.read(authControllerProvider.notifier).refreshProfile();
    }
    return updated;
  }

  static bool _sameAreas(Set<StoreArea> a, Set<StoreArea> b) =>
      a.length == b.length && a.containsAll(b);
}

final storeMembersProvider =
    AsyncNotifierProvider.autoDispose<
      StoreMembersController,
      List<StoreMember>
    >(StoreMembersController.new);
