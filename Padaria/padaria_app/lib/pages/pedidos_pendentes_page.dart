import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:padaria_app/pages/editar_quantidade_page.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pedido_local_service.dart';
import '../services/firebird_service.dart';
import '../services/pedido_pdf_service.dart';

class PedidosPendentesPage extends StatefulWidget {
  const PedidosPendentesPage({super.key});

  @override
  State<PedidosPendentesPage> createState() => _PedidosPendentesPageState();
}

class _PedidosPendentesPageState extends State<PedidosPendentesPage> {
  late Future<List<Map<String, dynamic>>> _pedidosFuture;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _carregarPedidos();
  }

  void _carregarPedidos() {
    _pedidosFuture = PedidoLocalService().listarPedidosPendentes();
  }

  // =========================
  // GERAR PDF
  // =========================
  Future<File> _gerarArquivoPdfDoPedido(Map<String, dynamic> pedido) async {
    final cabecalho = <String, String>{
      'Cliente': (pedido['cliente'] ?? '').toString(),
      'Contato': (pedido['contato'] ?? '').toString(),
      'Pagamento': (pedido['forma_pagamento'] ?? '').toString(),
      'Entrega':
          '${(pedido['data_entrega'] ?? '')} ${(pedido['hora_entrega'] ?? '')}',
      'Observações': (pedido['observacoes'] ?? '-').toString(),
      'foto_bolo_local': (pedido['foto_bolo_local'] ?? '').toString(),
    };

    final int pedidoId = (pedido['id'] as num).toInt();
    final itensDb = await PedidoLocalService().listarItensDoPedido(pedidoId);

    final itensProdutos = <Map<String, String>>[];
    final itensBolos = <Map<String, String>>[];

    for (final it in itensDb) {
      final tipo = (it['item_tipo'] ?? '').toString().trim().toUpperCase();

      final map = <String, String>{
        'ITEM_TIPO': tipo,
        'ITEM_DESC1': (it['descricao1'] ?? '').toString(),
        'ITEM_DESC2': (it['descricao2'] ?? '').toString(),
        'ITEM_DESC3': (it['descricao3'] ?? '').toString(),
        'ITEM_OBS': (it['observacao'] ?? '').toString(),
        'qtd': (it['quantidade'] ?? '').toString(),
        'unit': (it['preco_unitario'] ?? '').toString(),
        'sub': (it['subtotal'] ?? '').toString(),
      };

      if (tipo == 'B') {
        itensBolos.add(map);
      } else {
        itensProdutos.add(map);
      }
    }

    final int numeroPedido =
        (pedido['numero_pedido'] as num?)?.toInt() ?? pedidoId;

    return PedidoPdfService.gerarPedidoPdf(
      titulo: 'Pedido #${numeroPedido.toString().padLeft(4, '0')}',
      cabecalho: cabecalho,
      itensProdutos: itensProdutos,
      itensBolos: itensBolos,
    );
  }

  Future<void> _verPdf(Map<String, dynamic> pedido) async {
    final file = await _gerarArquivoPdfDoPedido(pedido);
    final Uint8List bytes = await file.readAsBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _enviarPdfZap(Map<String, dynamic> pedido) async {
    final file = await _gerarArquivoPdfDoPedido(pedido);
    await Share.shareXFiles([XFile(file.path)]);
  }

  // =========================
  // EDITAR BOLO (VERSÃO FINAL)
  // =========================
  Future<void> _editarQuantidadePedido(Map<String, dynamic> pedido) async {
    final int pedidoId = (pedido['id'] as num).toInt();

    // 🔵 BUSCA SEMPRE FRESCO DO SQLITE
    final itens = await PedidoLocalService().listarItensDoPedido(pedidoId);

    final itemBolo = itens.firstWhere(
      (it) => (it['item_tipo'] ?? '').toString().toUpperCase() == 'B',
      orElse: () => {},
    );

    if (itemBolo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido não possui bolo para edição')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditarQuantidadePage(
          item: {
            'id': itemBolo['id'],
            'descricao1': itemBolo['descricao1'],
            'descricao2': itemBolo['descricao2'],
            'descricao3': itemBolo['descricao3'],
            'quantidade': itemBolo['quantidade'],
            'subtotal': itemBolo['subtotal'], // 🔥 IMPORTANTE
            'cliente': (pedido['cliente'] ?? '').toString(),
            'pedidoId': pedidoId,
          },
          precoKg: (itemBolo['preco_unitario'] as num?)?.toDouble() ?? 0.0,
        ),
      ),
    );

    if (result == null) return;

    // 🔴 AQUI ESTAVA O ERRO ANTIGO — AGORA CORRETO
    await PedidoLocalService().atualizarItemBoloQuantidade(
      itemId: (itemBolo['id'] as num).toInt(),
      novaQuantidade: (result['quantidade'] as num).toDouble(),
      novoSubtotal: (result['subtotal'] as num).toDouble(), // ✅ VALOR FINAL
      descricao2: result['descricao2'],
      descricao3: result['descricao3'],
    );

    await PedidoLocalService().recalcularTotalPedido(pedidoId);

    _carregarPedidos();
    setState(() {});
  }

  // =========================
  // ENVIAR PEDIDO
  // =========================
  Future<void> _enviarPedido(Map<String, dynamic> pedido) async {
    if (_enviando) return;

    setState(() => _enviando = true);
    final int pedidoId = (pedido['id'] as num).toInt();

    try {
      await FirebirdService.enviarPedidoPorId(pedidoId);
      await PedidoLocalService().atualizarStatusPedido(pedidoId, 'FATURADO');
      _carregarPedidos();
      setState(() {});
    } finally {
      setState(() => _enviando = false);
    }
  }

  // =========================
  // IMPRIMIR TÉRMICO 79mm
  // =========================
  Future<void> _imprimirTermico(Map<String, dynamic> pedido) async {
    final int pedidoId = (pedido['id'] as num).toInt();

    final cabecalho = {
      'cliente': (pedido['cliente'] ?? '').toString(),
      'contato': (pedido['contato'] ?? '').toString(),
      'forma_pagamento': (pedido['forma_pagamento'] ?? '').toString(),
      'data_entrega': (pedido['data_entrega'] ?? '').toString(),
      'hora_entrega': (pedido['hora_entrega'] ?? '').toString(),
      'observacoes': (pedido['observacoes'] ?? '').toString(),
    };

    final itens = await PedidoLocalService().listarItensDoPedido(pedidoId);

    final ok = await PedidoLocalService.imprimirTermico79mm(
      cabecalho: cabecalho,
      itens: itens,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Pedido enviado para impressão' : 'Erro ao imprimir pedido',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos Pendentes')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _pedidosFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pedidos = snapshot.data!;
          if (pedidos.isEmpty) {
            return const Center(child: Text('Nenhum pedido encontrado'));
          }

          return ListView.builder(
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final pedido = pedidos[index];

              final String status = pedido['status'] == 'PENDENTE'
                  ? 'ENVIAR'
                  : 'FATURADO';

              final bool podeEditar = status == 'ENVIAR';

              final String dataEntregaFormatada =
                  pedido['data_entrega'] != null &&
                      pedido['data_entrega'].toString().isNotEmpty
                  ? DateFormat(
                      'dd/MM/yyyy',
                    ).format(DateTime.parse(pedido['data_entrega']))
                  : '';

              final int numeroPedido =
                  (pedido['numero_pedido'] as num?)?.toInt() ??
                  (pedido['id'] as num).toInt();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (pedido['cliente'] ?? '').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PEDIDO: ${numeroPedido.toString().padLeft(4, '0')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text('ENTREGA: $dataEntregaFormatada'),
                          ),
                          Text(
                            'HORA: ${(pedido['hora_entrega'] ?? '').toString()}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PAGAMENTO: ${(pedido['forma_pagamento'] ?? '').toString()}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf),
                            onPressed: () async => _verPdf(pedido),
                          ),
                          if (podeEditar)
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async =>
                                  _editarQuantidadePedido(pedido),
                            ),
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.green),
                            onPressed: () async => _enviarPdfZap(pedido),
                          ),

                          IconButton(
                            icon: const Icon(Icons.print, color: Colors.black),
                            tooltip: 'Imprimir 79mm',
                            onPressed: () async => _imprimirTermico(pedido),
                          ),

                          const Spacer(),
                          ElevatedButton(
                            onPressed: _enviando
                                ? null
                                : () => _enviarPedido(pedido),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: status == 'ENVIAR'
                                    ? Colors.amber
                                    : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
