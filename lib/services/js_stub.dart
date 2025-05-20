/// Stub for JS interop on non-web platforms.
/// Provides a `context` object with no-op methods so conditional imports compile.
class _JSContext {
  /// Mock JS global context
  dynamic callMethod(String method, [List<dynamic>? args]) {
    print('Warning: JS interop method \'$method\' called on non-web platform. This is a stub.');
    throw UnsupportedError('JS interop not supported on this platform for method: $method');
  }
}

/// The JS global context mock
final _JSContext context = _JSContext(); 