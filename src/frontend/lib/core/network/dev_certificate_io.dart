import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Hosts that reach the backend on the development machine.
const _devHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

/// Debug builds only: accepts the ASP.NET development certificate (self-signed, issued to
/// "localhost") when calling the local backend. The Android emulator reaches it as 10.0.2.2,
/// so the certificate can't be trusted the normal way.
///
/// Release builds, and any other host, keep the normal certificate validation.
void allowDevCertificate(Dio dio) {
  final apiHost = _devApiHost;
  if (apiHost == null) return;

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () =>
        HttpClient()
          ..badCertificateCallback = (cert, host, port) => host == apiHost,
  );
}

/// Same rule for `Image.network` (product photos uploaded to the API), which doesn't use Dio.
void allowDevCertificateForImages() {
  if (_devApiHost != null) HttpOverrides.global = _DevCertificateOverrides();
}

/// The API host when it is a development one in a debug build; null otherwise.
String? get _devApiHost {
  final apiHost = Uri.parse(Env.apiBaseUrl).host;
  return kDebugMode && _devHosts.contains(apiHost) ? apiHost : null;
}

class _DevCertificateOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final apiHost = _devApiHost;
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => host == apiHost;
  }
}
