String montarUrlImagemComVersao(String? url, String versao) {
  if (url == null || url.trim().isEmpty) return "";

  final uri = Uri.parse(url);
  final novosParametros = Map<String, String>.from(uri.queryParameters);

  novosParametros["v"] = versao;

  final novoUri = uri.replace(queryParameters: novosParametros);
  return novoUri.toString();
}
