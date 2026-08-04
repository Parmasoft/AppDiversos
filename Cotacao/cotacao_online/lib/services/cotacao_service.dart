import 'package:cotacao_online/app/app_config.dart';
import 'package:cotacao_online/services/api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class CotacaoService {
  // =======================================================
  // ABRIR COTAÇÃO
  // =======================================================
  //static Future<Map<String, dynamic>> abrirCotacao({
  static Future<dynamic> abrirCotacao({
    required int empresa,
    required int usuario,
  }) async {
    return ApiService.post(
      '${AppConfig.baseUrl}/cotacoes/abrir',
      {
        'empresa': empresa,
        'usuario': usuario,
      },
    );
  }

  Future<void> abrirEmail(String email, String assunto, String corpo) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': assunto,
        'body': corpo,
      },
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Não foi possível abrir o e-mail');
    }
  }

  Future<void> abrirWhatsApp(String telefone, String mensagem) async {
    final url = Uri.parse(
      'https://wa.me/55$telefone?text=${Uri.encodeComponent(mensagem)}',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Não foi possível abrir o WhatsApp');
    }
  }

  Future<Map<String, dynamic>> gerarLinkFornecedor({
    required int empresa,
    required int cotacao,
    required int fornecedor,
  }) async {
    final response = await http.post(
      Uri.parse('http://SEU_IP:5000/cotacoes/fornecedores/gerar_link'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'empresa': empresa,
        'cotacao': cotacao,
        'fornecedor': fornecedor,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['message'] ?? 'Erro ao gerar link');
    }

    return data;
  }

  // =======================================================
  // ATUALIZAR DATAS / DESCRIÇÃO
  // =======================================================
  static Future<void> atualizarDatas({
    required int empresa,
    required int cotId,
    required String dataAbertura,
    required String dataFechamento,
    String? descricao,
  }) async {
    await ApiService.post(
      '${AppConfig.baseUrl}/cotacoes/atualizar-datas',
      {
        'empresa': empresa,
        'cot_id': cotId,
        'data_abertura': dataAbertura,
        'data_fechamento': dataFechamento,
        'descricao': descricao,
      },
    );
  }

  // =======================================================
  // LISTAR COTAÇÕES
  // =======================================================
  static Future<List<Map<String, dynamic>>> listarCotacoes({
    required int empresa,
  }) async {
    final resp = await ApiService.get(
      '${AppConfig.baseUrl}/cotacoes?empresa=$empresa',
    );

    //final List lista = resp['dados'] as List;
    final List lista = resp as List;

    return lista
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // =======================================================
  // ITENS DA COTAÇÃO
  // =======================================================
  static Future<List<Map<String, dynamic>>> listarItensCotacao({
    required int empresa,
    required int cotId,
  }) async {
    final resp = await ApiService.get(
      '${AppConfig.baseUrl}/cotacoes/$cotId/itens?empresa=$empresa',
    );

    //final List lista = resp['dados'] as List;
    final List lista = resp as List;

    return lista
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> incluirItemCotacao({
    required int empresa,
    required int cotId,
    required int produto,
    required String descricao,
    required String unidade,
    required int quantidade,
  }) async {
    await ApiService.post(
      '${AppConfig.baseUrl}/cotacoes/itens/incluir',
      {
        'empresa': empresa,
        'cotacao': cotId,
        'produto': produto,
        'descricao': descricao,
        'unidade': unidade,
        'quantidade': quantidade,
      },
    );
  }

  static Future<void> excluirItemCotacao({
    required int empresa,
    required int cotId,
    required int sequencia,
  }) async {
    await ApiService.post(
      '${AppConfig.baseUrl}/cotacoes/itens/excluir',
      {
        'empresa': empresa,
        'cotacao': cotId,
        'sequencia': sequencia,
      },
    );
  }

  // =======================================================
  // PRODUTOS
  // =======================================================
  static Future<List<Map<String, dynamic>>> buscarProdutos({
    required int empresa,
    required String termo,
  }) async {
    if (termo.length < 3) return [];

    final resp = await ApiService.get(
      '${AppConfig.baseUrl}/produtos/busca?empresa=$empresa&q=$termo',
    );

    //final List lista = resp['dados'] as List;
    final List lista = resp as List;

    return lista
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // =======================================================
  // FECHAMENTO
  // =======================================================
  static Future<void> atualizarDataFechamento({
    required int empresa,
    required int cotId,
    required String dataFechamento,
  }) async {
    await ApiService.post(
      '${AppConfig.baseUrl}/cotacoes/fechamento',
      {
        'empresa': empresa,
        'cot_id': cotId,
        'data_fechamento': dataFechamento,
      },
    );
  }
}
