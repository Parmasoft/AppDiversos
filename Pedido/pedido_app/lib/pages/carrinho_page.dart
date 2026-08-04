import 'package:flutter/material.dart';
import 'package:pedido/core/image_utils.dart';
import 'package:pedido/pages/home_page.dart';
import 'package:pedido/services/server_config.dart';
import '../models/item_carrinho.dart';
import '../core/app_colors.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class CarrinhoPage extends StatefulWidget {
  final List<ItemCarrinho> itens;
  final int comanda;
  final String imagemVersao;

  const CarrinhoPage({
    super.key,
    required this.itens,
    required this.comanda,
    required this.imagemVersao,
  });

  @override
  State<CarrinhoPage> createState() => _CarrinhoPageState();
}

class _CarrinhoPageState extends State<CarrinhoPage> {
  double get totalGeral {
    return widget.itens.fold(0, (sum, item) => sum + item.total);
  }

  int get totalItens {
    return widget.itens.fold(0, (sum, item) => sum + item.quantidade);
  }

  Future<void> finalizarPedido() async {
    // 🔎 verifica se existe item novo no carrinho
    final itensNovos = widget.itens
        .where((item) => item.existente == false)
        .toList();

    // se não houver item novo, apenas volta para a tela anterior
    if (itensNovos.isEmpty) {
      Navigator.pop(context);
      Navigator.pop(context);
      return;
    }

    final url = Uri.parse("${ServerConfig.baseUrl}/pdv/finalizar");

    final body = {
      "empresa": 1,
      "comanda": widget.comanda,
      "usuario": 1,
      "itens": itensNovos.where((item) => item.existente == false).map((item) {
        return {"produto_id": item.id, "quantidade": item.quantidade};
      }).toList(),
    };

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["sucesso"] == true) {
        final aviso = data["aviso"];

        setState(() {
          widget.itens.clear();
        });

        if (aviso != null && aviso.toString().trim().isNotEmpty) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Atenção"),
              content: Text(aviso),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else {
        mostrarErro(data["erro"] ?? "Erro ao finalizar pedido");
      }
    } on TimeoutException {
      mostrarErro(
        "Comanda ${widget.comanda} está sendo utilizada no balcão.\n"
        "Aguarde alguns segundos e tente novamente.",
      );
    } catch (e) {
      mostrarErro("Erro de conexão com servidor");
    }
  }

  void mostrarErro(String mensagem) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Erro"),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void removerItem(ItemCarrinho item) {
    final itemRemovido = item;
    final index = widget.itens.indexOf(item);

    setState(() {
      widget.itens.remove(item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Resumo da Comanda")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.itens.length,
              itemBuilder: (context, index) {
                final item = widget.itens[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // IMAGEM
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: item.fotoUrl.isNotEmpty
                              ? Image.network(
                                  montarUrlImagemComVersao(
                                    item.fotoUrl,
                                    widget.imagemVersao,
                                  ),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    return Container(
                                      width: 56,
                                      height: 56,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.image),
                                    );
                                  },
                                )
                              : Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.image),
                                ),
                        ),

                        const SizedBox(width: 12),

                        // INFORMAÇÕES
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.descricao,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text("R\$ ${item.preco.toStringAsFixed(2)}"),
                            ],
                          ),
                        ),

                        // AÇÕES
                        Column(
                          children: [
                            Row(
                              children: [
                                // BOTÃO DINÂMICO (remove ou delete)
                                IconButton(
                                  onPressed: () {
                                    if (item.quantidade > 1) {
                                      setState(() {
                                        item.quantidade--;
                                      });
                                    } else {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          title: const Text(
                                            "Remover item",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Text(
                                            "Deseja remover ${item.descricao}?",
                                          ),
                                          actionsPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text(
                                                "Cancelar",
                                                style: TextStyle(
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors
                                                    .primary, // seu amarelo Parma
                                                foregroundColor: Colors.black,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              onPressed: () {
                                                Navigator.pop(context);
                                                setState(() {
                                                  widget.itens.remove(item);
                                                });
                                              },
                                              child: const Text("Remover"),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                  icon: Icon(
                                    item.quantidade > 1
                                        ? Icons.remove
                                        : Icons.delete,
                                    color: item.quantidade > 1
                                        ? Colors.black
                                        : Colors.red,
                                  ),
                                ),

                                Text(
                                  item.quantidade.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      item.quantidade++;
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Text(
                  "${widget.itens.length} itens • R\$ ${totalGeral.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    // MAIS ITENS
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary, width: 2),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Mais Itens",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // FINALIZAR
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          await finalizarPedido();
                        },
                        child: const Text(
                          "Finalizar Pedido",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
