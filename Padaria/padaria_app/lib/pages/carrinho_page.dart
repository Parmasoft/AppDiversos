import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/carrinho_service.dart';
import '../services/pedido_local_service.dart';
import '../services/firebird_service.dart';
import 'editar_quantidade_page.dart';

class CarrinhoPage extends StatefulWidget {
  final Map<String, dynamic> cabecalho;

  const CarrinhoPage({super.key, required this.cabecalho});

  @override
  State<CarrinhoPage> createState() => _CarrinhoPageState();
}

class _CarrinhoPageState extends State<CarrinhoPage> {
  final carrinho = CarrinhoService();

  final moeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  Future<void> finalizarPedido() async {
    if (carrinho.itens.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Carrinho vazio')));
      return;
    }

    final cabecalhoFinal = {
      ...widget.cabecalho,
      'total': double.parse(carrinho.total.toStringAsFixed(2)),
    };

    final itensFinal = carrinho.itens.map((item) {
      final qtd = (item['quantidade'] as num).toDouble();
      final preco = (item['preco_unitario'] as num).toDouble();
      final subtotal = double.parse((qtd * preco).toStringAsFixed(2));

      return {
        ...item,
        'quantidade': double.parse(qtd.toStringAsFixed(3)),
        'preco_unitario': double.parse(preco.toStringAsFixed(2)),
        'subtotal': subtotal,
      };
    }).toList();

    try {
      await PedidoLocalService().salvarPedido(
        cabecalho: cabecalhoFinal,
        itens: itensFinal,
      );

      // 🔁 Envio Firebird permanece como estava
      // await FirebirdService().enviarPedidoPorId(pedidoId);

      carrinho.limpar();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pedido salvo com sucesso')));

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar pedido: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carrinho')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: carrinho.itens.length,
              itemBuilder: (context, index) {
                final item = carrinho.itens[index];

                final recheio1 = (item['descricao2'] ?? '').toString().trim();
                final recheio2 = (item['descricao3'] ?? '').toString().trim();
                final obs = (item['observacao'] ?? '').toString().trim();

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    // ===================================
                    // EDITAR ITEM (QUANTIDADE + RECHEIOS)
                    // ===================================
                    onTap: () async {
                      // 🔐 Garantia de chave no map
                      item['descricao2'] ??= '';
                      item['descricao3'] ??= '';

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditarQuantidadePage(
                            item: {
                              ...item,
                              'cliente': widget.cabecalho['cliente'] ?? '',
                              'pedidoId':
                                  widget.cabecalho['numero_pedido'] ?? 0,
                            },
                            precoKg:
                                (item['preco_unitario'] as num?)?.toDouble() ??
                                0.0,
                          ),
                        ),
                      );

                      if (result != null && mounted) {
                        debugPrint('🔵 CARRINHO RECEBEU RESULT: $result');

                        final novaQuantidade =
                            (result['quantidade'] as num?)?.toDouble() ?? 0.0;

                        final preco =
                            (item['preco_unitario'] as num?)?.toDouble() ?? 0.0;

                        final novoSubtotal = double.parse(
                          (novaQuantidade * preco).toStringAsFixed(2),
                        );

                        setState(() {
                          item['quantidade'] = novaQuantidade;
                          item['subtotal'] = novoSubtotal;
                          item['descricao2'] = result['descricao2'] ?? '';
                          item['descricao3'] = result['descricao3'] ?? '';
                        });

                        // 💾 Persistência no SQLite
                        await PedidoLocalService().atualizarItemBoloQuantidade(
                          itemId: item['id'],
                          novaQuantidade: novaQuantidade,
                          novoSubtotal: novoSubtotal,
                          descricao2: item['descricao2'],
                          descricao3: item['descricao3'],
                        );

                        await PedidoLocalService().recalcularTotalPedido(
                          widget.cabecalho['id'],
                        );
                      }
                    },

                    title: Text(
                      item['descricao1'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['quantidade']} ${item['unidade']}  x  '
                          '${moeda.format(item['preco_unitario'])}',
                        ),

                        if (recheio1.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Recheio 1: $recheio1',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),

                        if (recheio2.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Recheio 2: $recheio2',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),

                        if (obs.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Obs: $obs',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          moeda.format(item['subtotal']),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              carrinho.removerItem(index);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ===============================
          // TOTAL + FINALIZAR
          // ===============================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              border: const Border(top: BorderSide(color: Colors.black12)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      moeda.format(carrinho.total),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: finalizarPedido,
                    child: const Text('Finalizar Pedido'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
