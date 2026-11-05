import 'package:flutter/material.dart';

import 'error_notifier.dart';
import 'failure.dart';

/// Default [ErrorNotifier]: shows the general messages in a SnackBar.
/// Field messages are shown by the form itself, under each field.
class SnackBarErrorNotifier implements ErrorNotifier {
  const SnackBarErrorNotifier();

  @override
  void notify(BuildContext context, Failure failure) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final colors = Theme.of(context).colorScheme;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failure.generalMessages.join('\n'),
            style: TextStyle(color: colors.onError),
          ),
          backgroundColor: colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
