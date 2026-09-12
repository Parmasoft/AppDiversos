class ApiResponse {
  const ApiResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class RawJsonBody {
  const RawJsonBody(this.value);

  final String value;
}

abstract interface class ApiTransport {
  Future<ApiResponse> send({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  });
}
