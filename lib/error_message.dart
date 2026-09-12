/// Turns a thrown error into something worth showing the user.
///
/// Falls back to [fallback] when the error carries nothing readable — an empty
/// message, or a long dump of internals that would only confuse.
String friendlyError(Object error, String fallback) {
  final message = error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('DioException', '')
      .trim();

  if (message.isEmpty || message.length > 160) return fallback;

  return message;
}
