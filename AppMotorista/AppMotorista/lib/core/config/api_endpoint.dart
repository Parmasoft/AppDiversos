class ApiEndpoint {
  const ApiEndpoint(this.baseUri);

  final String baseUri;

  static ApiEndpoint parse(String value, {required bool allowHttp}) {
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty || uri.hasQuery || uri.hasFragment) {
      throw const FormatException('Informe um endereço de API válido.');
    }
    if (uri.scheme != 'https' && !(allowHttp && uri.scheme == 'http')) {
      throw const FormatException(
        'Este ambiente exige um endereço HTTPS seguro.',
      );
    }
    if (uri.path.isNotEmpty && uri.path != '/') {
      throw const FormatException('Informe somente a URL base da API.');
    }
    return ApiEndpoint(
      uri.replace(path: '').toString().replaceFirst(RegExp(r'/$'), ''),
    );
  }
}
