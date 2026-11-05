import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/network/dev_certificate.dart';

void main() {
  // Debug builds against the local backend: lets product photos load over its dev certificate.
  allowDevCertificateForImages();
  runApp(const ProviderScope(child: App()));
}
