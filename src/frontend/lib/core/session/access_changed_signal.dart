import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fired when the backend refuses a request with 403 because of the store access
/// (the user was removed, or an admin changed what they may use).
///
/// Lives in `core` so the network layer can report it without depending on the auth feature;
/// the auth feature listens to it and reloads the profile (store, role and areas).
class AccessChangedSignal extends Notifier<int> {
  @override
  int build() => 0;

  void emit() => state++;
}

final accessChangedSignalProvider = NotifierProvider<AccessChangedSignal, int>(
  AccessChangedSignal.new,
);
