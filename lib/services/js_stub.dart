/// Stub for JS interop on non-web platforms.
/// Provides a `context` object with no-op methods so conditional imports compile.
library;

import 'package:flutter/foundation.dart';

class JSContext {
  /// Mock JS global context
  dynamic callMethod(String method, [List<dynamic>? args]) {
    debugPrint('Warning: JS interop method \'$method\' called on non-web platform. This is a stub.');
    // Do not throw an error for 'eval' as it might be part of a check
    if (method != 'eval') {
      throw UnsupportedError('JS interop not supported on this platform for method: $method');
    }
    return null; // Return null for eval to mimic no effect
  }
}

/// The JS global context mock
final JSContext context = JSContext();
