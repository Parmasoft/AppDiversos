import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:padaria_app/services/api_service.dart';

class ProdutoPadariaService {
  //static const String baseUrl = 'http://192.168.1.238:5002';
  //static const String baseUrl = 'http://192.168.0.250:5002';
  //static const String baseUrl = 'http://192.168.1.174:5002';
  static Future<bool> testarConexao() async {
    final url = Uri.parse('${ApiService.baseUrl}/ping');
    final resp = await http.get(url);
    return resp.statusCode == 200;
  }

  static Future<List<Map<String, dynamic>>> buscarProdutos(
    String descricao,
  ) async {
    if (descricao.length < 3) return [];

    //final url = Uri.parse('$baseUrl/produtos/busca?descricao=$descricao');
    final url = Uri.parse(
      '${ApiService.baseUrl}/produtos/busca?descricao=$descricao',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Erro ao buscar produtos');
    }
  }
}
