// The browser decides which certificates to trust, so the web build has nothing to do.
export 'dev_certificate_stub.dart'
    if (dart.library.io) 'dev_certificate_io.dart';
