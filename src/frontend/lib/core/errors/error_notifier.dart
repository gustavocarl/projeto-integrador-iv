import 'package:flutter/widgets.dart';

import 'failure.dart';

/// Shows a [Failure] to the user. Screens depend on this interface,
/// so the way errors are displayed can change in a single place.
abstract interface class ErrorNotifier {
  void notify(BuildContext context, Failure failure);
}
