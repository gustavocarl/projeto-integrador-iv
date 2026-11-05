import 'package:flutter/material.dart';

import '../../domain/entities/app_notification.dart';

/// How each kind of notification looks.
extension NotificationKindView on NotificationKind {
  IconData get icon => switch (this) {
    NotificationKind.accessRequested => Icons.how_to_reg_outlined,
    NotificationKind.accessApproved => Icons.verified_outlined,
    NotificationKind.other => Icons.notifications_outlined,
  };
}
