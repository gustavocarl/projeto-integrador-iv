import 'package:flutter/material.dart';

import 'error_notifier.dart';
import 'failure.dart';

/// Shows every message in a scrollable dialog. Use it on screens where one action
/// can produce a long list of errors (e.g. one per spreadsheet row).
class DialogErrorNotifier implements ErrorNotifier {
  const DialogErrorNotifier({this.title});

  final String? title;

  @override
  void notify(BuildContext context, Failure failure) {
    final messages = failure.errors.isEmpty
        ? [failure.message]
        : failure.errors.map((e) => e.message).toList();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(title ?? failure.message),
        content: SizedBox(
          width: 480,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: messages.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(messages[i]),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}
