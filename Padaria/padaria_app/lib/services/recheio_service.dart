import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:padaria_app/services/api_service.dart';

class RecheioService {
  //static const String baseUrl = 'http://192.168.1.238:5002'; // ajuste se mudar
  //static const String baseUrl = 'http://192.168.0.250:5002'; // ajuste se mudar
  //static const String baseUrl = 'http://192.168.1.174:5002'; // ajuste se mudar
  static Future<bool> testarConexao() async {
    final url = Uri.parse('${ApiService.baseUrl}/ping');
    final resp = await http.get(url);
    return resp.statusCode == 200;
  }

  static Future<List<Map<String, dynamic>>> buscar(String descricao) async {
    if (descricao.length < 3) return [];

    final uri = Uri.parse(
      '${ApiService.baseUrl}/recheios/busca?descricao=$descricao',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) return [];

    final List dados = json.decode(response.body);

    return dados
        .map<Map<String, dynamic>>(
          (e) => {
            'id': e['id'],
            'descricao': e['descricao'],
            'preco_kg': (e['preco_kg'] as num).toDouble(),
          },
        )
        .toList();
  }
}
