import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/requisicao_transferencia.dart';
import '../models/requisicao_transferencia_item.dart';
import '../models/requisicao_transferencia_leitura.dart';

typedef DetalheRequisicaoTransferencia = ({
  RequisicaoTransferencia requisicao,
  List<RequisicaoTransferenciaItem> itens,
});

typedef InicioSeparacaoRequisicao = ({
  String mensagem,
  String statusRequisicao,
  int usuarioSeparacao,
});

typedef ItemSeparacaoRequisicao = ({
  RequisicaoTransferenciaItem item,
  List<RequisicaoTransferenciaLeitura> leituras,
  String mensagem,
});

typedef FinalizacaoSeparacaoRequisicao = ({
  String mensagem,
  String statusRequisicao,
  String statusSeparacao,
});

class RequisicaoTransferenciaService {
  final String baseUrl;
  final int empresaMatriz;
  final int usuarioAtual;

  const RequisicaoTransferenciaService({
    required this.baseUrl,
    required this.empresaMatriz,
    required this.usuarioAtual,
  });

  static Future<RequisicaoTransferenciaService> daConfiguracao() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl =
        prefs.getString('api_base_url') ?? 'http://192.168.0.250:5001';
    final empresaMatriz = prefs.getInt('empresa_id') ?? 1;

    return RequisicaoTransferenciaService(
      baseUrl: baseUrl,
      empresaMatriz: empresaMatriz,
      usuarioAtual: 1,
    );
  }

  Future<List<RequisicaoTransferencia>> listarDisponiveis() async {
    final dados = await _get('/transferencias/requisicoes', {
      'empresa': empresaMatriz.toString(),
      'usuario': usuarioAtual.toString(),
    });
    final lista = dados['requisicoes'];

    if (lista is! List) return const [];

    return lista
        .whereType<Map>()
        .map(
          (item) =>
              RequisicaoTransferencia.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<DetalheRequisicaoTransferencia> consultarDetalhe(
    int requisicao,
  ) async {
    final dados = await _get('/transferencias/requisicoes/detalhe', {
      'empresa': empresaMatriz.toString(),
      'requisicao': requisicao.toString(),
      'usuario': usuarioAtual.toString(),
    });

    final capaJson = dados['requisicao'];
    if (capaJson is! Map) {
      throw Exception('A API não retornou a capa da requisição.');
    }

    final itensJson = dados['itens'];
    final itens = itensJson is List
        ? itensJson
              .whereType<Map>()
              .map(
                (item) => RequisicaoTransferenciaItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : <RequisicaoTransferenciaItem>[];

    return (
      requisicao: RequisicaoTransferencia.fromJson(
        Map<String, dynamic>.from(capaJson),
      ),
      itens: itens,
    );
  }

  Future<InicioSeparacaoRequisicao> assumir(int requisicao) async {
    final dados = await _post('/transferencias/requisicoes/assumir', {
      'empresa': empresaMatriz,
      'requisicao': requisicao,
      'usuario': usuarioAtual,
    });

    return (
      mensagem: (dados['mensagem'] ?? '').toString().trim(),
      statusRequisicao: (dados['status_requisicao'] ?? '').toString().trim(),
      usuarioSeparacao: _comoInt(dados['usuario_separacao']),
    );
  }

  Future<ItemSeparacaoRequisicao> consultarItemSeparacao({
    required int requisicao,
    required int item,
  }) async {
    final dados = await _get('/transferencias/requisicoes/item-separacao', {
      'empresa': empresaMatriz.toString(),
      'requisicao': requisicao.toString(),
      'item': item.toString(),
    });

    return _itemSeparacaoDoJson(dados);
  }

  Future<ItemSeparacaoRequisicao> salvarLeituras({
    required int requisicao,
    required int item,
    required List<String> codigosLidos,
  }) async {
    final dados =
        await _post('/transferencias/requisicoes/item-separacao/salvar', {
          'empresa': empresaMatriz,
          'requisicao': requisicao,
          'item': item,
          'usuario': usuarioAtual,
          'codigos_lidos': codigosLidos,
        });

    return _itemSeparacaoDoJson(dados);
  }

  Future<FinalizacaoSeparacaoRequisicao> finalizarSeparacao({
    required int requisicao,
    String observacao = '',
  }) async {
    final dados =
        await _post('/transferencias/requisicoes/finalizar-separacao', {
          'empresa': empresaMatriz,
          'requisicao': requisicao,
          'usuario': usuarioAtual,
          'observacao': observacao,
        });

    return (
      mensagem: (dados['mensagem'] ?? '').toString().trim(),
      statusRequisicao: (dados['status_requisicao'] ?? '').toString().trim(),
      statusSeparacao: (dados['status_separacao'] ?? '').toString().trim(),
    );
  }

  ItemSeparacaoRequisicao _itemSeparacaoDoJson(Map<String, dynamic> dados) {
    final itemJson = dados['item'];
    if (itemJson is! Map) {
      throw Exception('A API não retornou os dados atualizados do item.');
    }

    final leiturasJson = dados['leituras'];
    final leituras = leiturasJson is List
        ? leiturasJson
              .whereType<Map>()
              .map(
                (leitura) => RequisicaoTransferenciaLeitura.fromJson(
                  Map<String, dynamic>.from(leitura),
                ),
              )
              .toList(growable: false)
        : <RequisicaoTransferenciaLeitura>[];

    return (
      item: RequisicaoTransferenciaItem.fromJson(
        Map<String, dynamic>.from(itemJson),
      ),
      leituras: leituras,
      mensagem: (dados['mensagem'] ?? '').toString().trim(),
    );
  }

  Future<Map<String, dynamic>> _get(
    String caminho,
    Map<String, String> parametros,
  ) async {
    final raiz = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$raiz$caminho').replace(queryParameters: parametros);

    try {
      final resposta = await http.get(uri).timeout(const Duration(seconds: 15));
      final corpo = resposta.bodyBytes.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(resposta.bodyBytes));
      final dados = corpo is Map<String, dynamic>
          ? corpo
          : Map<String, dynamic>.from(corpo as Map);

      if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
        throw Exception(
          (dados['mensagem'] ?? 'Erro HTTP ${resposta.statusCode}.').toString(),
        );
      }

      return dados;
    } on TimeoutException {
      throw Exception('Tempo esgotado ao consultar a API.');
    } on FormatException {
      throw Exception('A API retornou uma resposta inválida.');
    }
  }

  Future<Map<String, dynamic>> _post(
    String caminho,
    Map<String, dynamic> conteudo,
  ) async {
    final raiz = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$raiz$caminho');

    try {
      final resposta = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(conteudo),
          )
          .timeout(const Duration(seconds: 30));
      final corpo = resposta.bodyBytes.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(resposta.bodyBytes));
      final dados = corpo is Map<String, dynamic>
          ? corpo
          : Map<String, dynamic>.from(corpo as Map);

      if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
        throw Exception(
          (dados['mensagem'] ?? 'Erro HTTP ${resposta.statusCode}.').toString(),
        );
      }

      return dados;
    } on TimeoutException {
      throw Exception('Tempo esgotado ao comunicar com a API.');
    } on FormatException {
      throw Exception('A API retornou uma resposta inválida.');
    }
  }
}

int _comoInt(dynamic valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(valor?.toString() ?? '') ?? 0;
}
