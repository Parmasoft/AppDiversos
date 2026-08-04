import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pedido/core/image_utils.dart';
import 'package:pedido/services/api_services.dart';

class ProdutoBuscaPage extends StatefulWidget {
  final int empresa;
  final String imagemVersao;

  const ProdutoBuscaPage({
    super.key,
    required this.empresa,
    required this.imagemVersao,
  });

  @override
  State<ProdutoBuscaPage> createState() => _ProdutoBuscaPageState();
}

class _ProdutoBuscaPageState extends State<ProdutoBuscaPage> {
  final TextEditingController _controller = TextEditingController();

  List produtos = [];
  Timer? _debounce;

  void buscar(String texto) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (texto.length < 3) {
        setState(() {
          produtos = [];
        });
        return;
      }

      final resultado = await ApiService.buscarProdutos(widget.empresa, texto);

      setState(() {
        produtos = resultado;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buscar produto")),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "Digite pelo menos 3 letras...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: buscar,
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: produtos.length,
              itemBuilder: (context, index) {
                final p = produtos[index];

                return ListTile(
                  title: Text(p["descricao"]),
                  subtitle: Text("R\$ ${p["preco"].toStringAsFixed(2)}"),
                  onTap: () async {
                    final quantidade = await showDialog<int>(
                      context: context,
                      builder: (_) {
                        int qtd = 1;

                        return StatefulBuilder(
                          builder: (context, setStateDialog) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (p["foto_url"] != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        montarUrlImagemComVersao(
                                          p["foto_url"]?.toString(),
                                          widget.imagemVersao,
                                        ),
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.fastfood,
                                                size: 80,
                                                color: Colors.grey,
                                              );
                                            },
                                      ),
                                    ),

                                  const SizedBox(height: 10),

                                  Text(
                                    p["descricao"],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  const Text("Quantos deseja?"),

                                  const SizedBox(height: 10),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove),
                                        onPressed: () {
                                          if (qtd > 1) {
                                            setStateDialog(() => qtd--);
                                          }
                                        },
                                      ),

                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.amber,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          "$qtd",
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ),

                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed: () {
                                          setStateDialog(() => qtd++);
                                        },
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),

                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context, qtd);
                                    },
                                    child: Text(
                                      "ADICIONAR R\$ ${(p["preco"] * qtd).toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        color: Colors.black,
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

                    if (quantidade != null) {
                      Navigator.pop(context, {
                        ...p,
                        "quantidade": quantidade,
                        "foto_url": montarUrlImagemComVersao(
                          p["foto_url"]?.toString(),
                          widget.imagemVersao,
                        ),
                      });
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
