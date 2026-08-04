import 'package:http/http.dart' as http;
import 'server_config.dart';
import 'dart:convert';

class ApiService {
  static Future<http.Response> buscarComanda({
    required int empresa,
    required String comanda,
  }) {
    final url = Uri.parse(
      "${ServerConfig.baseUrl}/pdv/comanda?empresa=$empresa&comanda=$comanda",
    );

    return http.get(url);
  }

  static Future<List> buscarProdutos(int empresa, String termo) async {
    final url = Uri.parse(
      "${ServerConfig.baseUrl}/pdv/produtos/buscar?empresa=$empresa&q=$termo",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return data["dados"] ?? [];
    }

    return [];
  }
}
