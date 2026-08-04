import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pedido/core/image_utils.dart';
import 'package:pedido/models/item_carrinho.dart';
import 'package:pedido/services/server_config.dart';

class ProdutosPage extends StatefulWidget {
  final String comanda;
  final int grupoId;
  final String grupoDescricao;
  final Function(ItemCarrinho) onAdicionar;
  final String imagemVersao;

  const ProdutosPage({
    super.key,
    required this.comanda,
    required this.grupoId,
    required this.grupoDescricao,
    required this.onAdicionar,
    required this.imagemVersao,
  });

  @override
  State<ProdutosPage> createState() => _ProdutosPageState();
}

class _ProdutosPageState extends State<ProdutosPage> {
  List produtos = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregarProdutos();
  }

  Future<void> carregarProdutos() async {
    final url = Uri.parse(
      "${ServerConfig.baseUrl}/pdv/produtos?empresa=1&grupo=${widget.grupoId}",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        produtos = data["dados"];
        carregando = false;
      });
    } else {
      setState(() {
        carregando = false;
      });
    }
  }

  void abrirModalQuantidade(Map produto) {
    double quantidadeSelecionada = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // IMAGEM
                  if (produto["foto_url"] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        montarUrlImagemComVersao(
                          produto["foto_url"]?.toString(),
                          widget.imagemVersao,
                        ),
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // NOME
                  Text(
                    produto["descricao"],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 6),

                  // PREÇO
                  Text(
                    "R\$ ${produto["preco"].toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.green, fontSize: 16),
                  ),

                  const SizedBox(height: 16),

                  const Text("Quantos deseja?"),

                  const SizedBox(height: 10),

                  // CONTROLE BONITO CENTRALIZADO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // BOTÃO -
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE0E0E0),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: quantidadeSelecionada > 1
                              ? () {
                                  setStateModal(() {
                                    quantidadeSelecionada--;
                                  });
                                }
                              : null,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // QUANTIDADE COM BORDA AMARELA
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.amber, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          quantidadeSelecionada.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // BOTÃO +
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE0E0E0),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setStateModal(() {
                              quantidadeSelecionada++;
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // BOTÃO ÚNICO (SEM DUPLICAÇÃO)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        widget.onAdicionar(
                          ItemCarrinho(
                            id: produto["id"],
                            descricao: produto["descricao"],
                            preco: (produto["preco"] as num).toDouble(),
                            fotoUrl: montarUrlImagemComVersao(
                              produto["foto_url"]?.toString(),
                              widget.imagemVersao,
                            ),
                            quantidade: quantidadeSelecionada,
                            existente: false,
                          ),
                        );

                        Navigator.pop(context); // fecha modal
                        Navigator.pop(context); // volta para Menu
                      },
                      child: Text(
                        "ADICIONAR R\$ ${(produto["preco"] * quantidadeSelecionada).toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.grupoDescricao)),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: produtos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                final produto = produtos[index];

                return GestureDetector(
                  onTap: () {
                    abrirModalQuantidade(produto);
                  },
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: produto["foto_url"] != null
                              ? ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: Image.network(
                                    montarUrlImagemComVersao(
                                      produto["foto_url"]?.toString(),
                                      widget.imagemVersao,
                                    ),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                )
                              : const Icon(Icons.image, size: 60),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text(
                                produto["descricao"],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "R\$ ${produto["preco"].toStringAsFixed(2)}",
                                style: const TextStyle(color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
