import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pedido_compra_recebimento.dart';
import '../models/pedido_compra_recebimento_detalhe.dart';
import '../models/pedido_compra_leitura_etiqueta.dart';

class PedidoCompraRoloResolvido {
  final String codigoLido;
  final int produto;
  final double quantidade;

  const PedidoCompraRoloResolvido({
    required this.codigoLido,
    required this.produto,
    required this.quantidade,
  });
}

class PedidoCompraRecebimentoService {
  final String baseUrl;
  final int empresaId;

  const PedidoCompraRecebimentoService({
    required this.baseUrl,
    required this.empresaId,
  });

  static Future<PedidoCompraRecebimentoService> daConfiguracao() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl =
        prefs.getString('api_base_url') ?? 'http://192.168.0.250:5001';
    final empresaId = prefs.getInt('empresa_id') ?? 1;

    return PedidoCompraRecebimentoService(
      baseUrl: baseUrl,
      empresaId: empresaId,
    );
  }

  Future<List<PedidoCompraRecebimento>> listarDisponiveis() async {
    final raiz = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$raiz/pedidos-compra/recebimento').replace(
      queryParameters: {'empresa': empresaId.toString()},
    );

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

      final lista = dados['pedidos'];
      if (lista is! List) return const [];

      return lista
          .whereType<Map>()
          .map(
            (item) => PedidoCompraRecebimento.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    } on TimeoutException {
      throw Exception('Tempo esgotado ao consultar a API.');
    } on FormatException {
      throw Exception('A API retornou uma resposta inválida.');
    }
  }

  Future<PedidoCompraRecebimentoDetalhe> consultarDetalhe({
    required int empresa,
    required int pedidoId,
  }) async {
    final raiz = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$raiz/pedidos-compra/recebimento/detalhe').replace(
      queryParameters: {
        'empresa': empresa.toString(),
        'pedido_id': pedidoId.toString(),
      },
    );

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

      final pedido = dados['pedido'];
      if (pedido is! Map) {
        throw Exception('A API não retornou os dados do pedido.');
      }

      return PedidoCompraRecebimentoDetalhe.fromJson(
        Map<String, dynamic>.from(pedido),
      );
    } on TimeoutException {
      throw Exception('Tempo esgotado ao consultar a API.');
    } on FormatException {
      throw Exception('A API retornou uma resposta inválida.');
    }
  }

  Future<PedidoCompraRoloResolvido> consultarRolo({
    required int empresa,
    required String codigo,
  }) async {
    final raiz = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$raiz/rolos/consultar-codigo').replace(
      queryParameters: {
        'empresa': empresa.toString(),
        'codigo': codigo.trim().toUpperCase(),
        'validar_recebimento_pedido_compra': 'S',
      },
    );

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
          (dados['mensagem'] ?? 'Etiqueta R recusada.').toString(),
        );
      }

      final produto = (dados['produto_id'] as num?)?.toInt() ??
          int.tryParse(dados['produto_id']?.toString() ?? '') ??
          0;
      final quantidade = (dados['quantidade'] as num?)?.toDouble() ??
          double.tryParse(dados['quantidade']?.toString() ?? '') ??
          0;
      if (produto <= 0 || quantidade <= 0) {
        throw Exception('A API não retornou um rolo válido.');
      }

      return PedidoCompraRoloResolvido(
        codigoLido: (dados['codigo_lido'] ?? codigo).toString().trim().toUpperCase(),
        produto: produto,
        quantidade: quantidade,
      );
    } on TimeoutException {
      throw Exception('Tempo esgotado ao validar a etiqueta R.');
    } on FormatException {
      throw Exception('A API retornou uma resposta inválida ao validar a etiqueta R.');
    }
  }

  Future<Map<String, dynamic>> confirmarRecebimento({
    required PedidoCompraRecebimentoDetalhe detalhe,
    required Map<int, PedidoCompraLeituraSessao> sessoesPorItem,
    required String operacaoGuid,
    required bool excedenteConfirmado,
  }) async {
    final leituras = <Map<String, dynamic>>[];
    for (final entrada in sessoesPorItem.entries) {
      final item = detalhe.itens.where((atual) => atual.sequencia == entrada.key);
      if (item.isEmpty) continue;
      for (final leitura in entrada.value.leituras) {
        leituras.add({'item': entrada.key, 'produto': item.first.produto, 'tipo': leitura.tipo, 'codigo': leitura.codigo, 'quantidade': leitura.quantidade});
      }
    }
    final raiz = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$raiz/pedidos-compra/recebimento/confirmar');
    try {
      final resposta = await http.post(uri, headers: const {'Content-Type': 'application/json'}, body: jsonEncode({'empresa': detalhe.empresa, 'pedido_id': detalhe.pedidoId, 'usuario': 1, 'operacao_guid': operacaoGuid, 'excedente_confirmado': excedenteConfirmado, 'leituras': leituras})).timeout(const Duration(seconds: 45));
      final corpo = resposta.bodyBytes.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(resposta.bodyBytes));
      final dados = corpo is Map<String, dynamic> ? corpo : Map<String, dynamic>.from(corpo as Map);
      if (resposta.statusCode < 200 || resposta.statusCode >= 300) throw Exception((dados['mensagem'] ?? 'Erro HTTP ${resposta.statusCode}.').toString());
      return dados;
    } on TimeoutException {
      throw Exception('Tempo esgotado ao confirmar. Tente novamente: a mesma operação será recuperada sem duplicidade.');
    } on FormatException {
      throw Exception('A API retornou uma resposta inválida.');
    }
  }
}
