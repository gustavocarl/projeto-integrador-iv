import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fired when the backend rejects the stored token (HTTP 401).
///
/// Lives in `core` so the network layer can report it without depending on the auth feature;
/// the auth feature listens to it and logs the user out.
class SessionExpiredSignal extends Notifier<int> {
  @override
  int build() => 0;

  void emit() => state++;
}

final sessionExpiredSignalProvider =
    NotifierProvider<SessionExpiredSignal, int>(SessionExpiredSignal.new);
