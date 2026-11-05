import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Override with: flutter run --dart-define=API_BASE_URL=https://host:port
abstract final class Env {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Backend URL. Defaults: `localhost` on web, `10.0.2.2` (the host machine) on the Android emulator.
  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    return kIsWeb ? 'https://localhost:7077' : 'https://10.0.2.2:7077';
  }

  /// Full address of [url]: paths on the API (an uploaded image, "/uploads/…") get the
  /// backend address in front; external links are returned as they are.
  static String resolveUrl(String url) =>
      url.startsWith('/') && !url.startsWith('//') ? '$apiBaseUrl$url' : url;
}
