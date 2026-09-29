/// One exception type for the whole app; `kind` drives the UI state.
enum ApiErrorKind {
  network, // no internet / DNS failure
  timeout,
  unauthorized, // 401: missing/invalid/expired token
  forbidden, // 403
  notFound, // 404
  validation, // 400 with field errors
  conflict, // 409 duplicates
  server, // 5xx / upstream failure
  unknown,
}

class ApiException implements Exception {
  ApiException(
    this.message, {
    this.kind = ApiErrorKind.unknown,
    this.status,
    this.fieldErrors = const {},
  });

  final String message;
  final ApiErrorKind kind;
  final int? status;

  /// Per-field messages from the server's `errors` object (e.g. {email: "..."}).
  final Map<String, String> fieldErrors;

  bool get isOffline => kind == ApiErrorKind.network;

  @override
  String toString() => message;
}
