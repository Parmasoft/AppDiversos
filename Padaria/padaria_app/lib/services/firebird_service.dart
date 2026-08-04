import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:padaria_app/services/api_service.dart';
import 'pedido_local_service.dart';

class FirebirdService {
  static Future<void> enviarPedidoPorId(int pedidoId) async {
    final pedidoLocal = PedidoLocalService();

    // 1️⃣ Cabeçalho
    final pedidos = await pedidoLocal.listarPedidosPendentes();
    final pedido = pedidos.firstWhere(
      (p) => p['id'] == pedidoId,
      orElse: () => throw Exception('Pedido não encontrado'),
    );

    // 2️⃣ Itens
    final itens = await pedidoLocal.listarItensDoPedido(pedidoId);

    // 3️⃣ Payload
    final payload = {
      'pedido': {
        'cliente': pedido['cliente'],
        'contato': pedido['contato'],
        'forma_pagamento': pedido['forma_pagamento'],
        'data_entrega': pedido['data_entrega'],
        'hora_entrega': pedido['hora_entrega'],
        'observacoes': pedido['observacoes'],
        'total': pedido['total'],
      },
      'itens': itens,
    };

    // 4️⃣ Envia
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/pedidos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Erro ao enviar pedido: ${response.body}');
    }

    final respJson = jsonDecode(response.body);
    final pedIdServidor = respJson['pedido_id'];

    // 4️⃣2️⃣ Upload foto
    final fotoPath = pedido['foto_bolo_local'];
    if (pedIdServidor != null &&
        fotoPath != null &&
        fotoPath.toString().isNotEmpty) {
      try {
        await ApiService.uploadFotoPedido(
          pedidoId: int.parse(pedIdServidor.toString()),
          fotoPathLocal: fotoPath.toString(),
        );
      } catch (e) {
        print('⚠️ Pedido enviado, mas falhou upload da foto: $e');
      }
    }

    // 5️⃣ Status local
    await pedidoLocal.atualizarStatusPedido(pedidoId, 'ENVIADO');
  }
}
