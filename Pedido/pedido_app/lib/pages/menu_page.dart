import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pedido/core/image_utils.dart';
import 'package:pedido/models/item_carrinho.dart';
import 'package:pedido/pages/carrinho_page.dart';
import 'package:pedido/pages/produto_busca_page.dart';
import 'package:pedido/pages/produtos_page.dart';
import 'package:pedido/services/server_config.dart';
import '../core/app_colors.dart';

class Grupo {
  final int id;
  final String descricao;
  final String? fotoUrl;

  Grupo({required this.id, required this.descricao, this.fotoUrl});

  factory Grupo.fromJson(Map<String, dynamic> json) {
    return Grupo(
      id: json['id'],
      descricao: json['descricao'],
      fotoUrl: json['foto_url'],
    );
  }
}

class MenuPage extends StatefulWidget {
  final String comanda;

  const MenuPage({super.key, required this.comanda});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<Grupo> grupos = [];
  List<ItemCarrinho> carrinho = [];
  bool carregando = true;
  late String imagemVersao;

  @override
  void initState() {
    super.initState();
    imagemVersao = DateTime.now().millisecondsSinceEpoch.toString();
    carregarGrupos();
    buscarComandaExistente();
  }

  Future<void> carregarGrupos() async {
    try {
      final url = Uri.parse('${ServerConfig.baseUrl}/pdv/grupos?empresa=1');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final lista = (data['dados'] as List)
            .map((e) => Grupo.fromJson(e))
            .toList();

        setState(() {
          grupos = lista;
          carregando = false;
        });
      } else {
        setState(() {
          carregando = false;
        });
      }
    } catch (e) {
      print("Erro ao carregar grupos: $e");
      setState(() {
        carregando = false;
      });
    }
  }

  Future<bool> _confirmarSaida() async {
    if (carrinho.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Pedido em andamento"),
          content: const Text(
            "Finalize ou limpe o carrinho antes de sair da comanda.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> buscarComandaExistente() async {
    final url = Uri.parse(
      "${ServerConfig.baseUrl}/pdv/comanda?empresa=1&comanda=${widget.comanda}",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final lista = data["itens"] as List;

      if (lista.isNotEmpty) {
        setState(() {
          carrinho = lista.map((item) {
            return ItemCarrinho(
              id: item["produto_id"],
              descricao: item["descricao"] ?? "",
              preco: (item["valor_unitario"] as num).toDouble(),
              fotoUrl: "", // temporário (já explico abaixo)
              quantidade: (item["quantidade"] as num).toInt(),
              existente: true,
            );
          }).toList();
        });
      }
    }
  }

  void adicionarItemCarrinho(ItemCarrinho item) {
    final index = carrinho.indexWhere(
      (e) => e.id == item.id && e.existente == false,
    );

    setState(() {
      if (index >= 0) {
        carrinho[index].quantidade += item.quantidade;
      } else {
        carrinho.add(item);
      }
    });
  }

  double totalGeral() {
    return carrinho.fold(0, (sum, item) => sum + item.total);
  }

  int totalItens() {
    return carrinho.length;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmarSaida,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _confirmarSaida()) {
                Navigator.pop(context);
              }
            },
          ),
          centerTitle: true,
          title: Text(
            "Comanda ${widget.comanda}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                final produto = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProdutoBuscaPage(
                      empresa: 1,
                      imagemVersao: imagemVersao,
                    ),
                  ),
                );

                if (produto != null) {
                  adicionarItemCarrinho(
                    ItemCarrinho(
                      id: produto["id"],
                      descricao: produto["descricao"],
                      preco: (produto["preco"] as num).toDouble(),
                      fotoUrl: produto["foto_url"] ?? "",
                      quantidade: produto["quantidade"] ?? 1,
                      existente: false,
                    ),
                  );
                }
              },
            ),
          ],
        ),
        body: carregando
            ? const Center(child: CircularProgressIndicator())
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: grupos.length,
                itemBuilder: (context, index) {
                  final grupo = grupos[index];

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProdutosPage(
                            comanda: widget.comanda,
                            grupoId: grupo.id,
                            grupoDescricao: grupo.descricao,
                            imagemVersao: imagemVersao,
                            onAdicionar: adicionarItemCarrinho,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: grupo.fotoUrl != null
                                ? ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: Image.network(
                                      montarUrlImagemComVersao(
                                        grupo.fotoUrl,
                                        imagemVersao,
                                      ),
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            print(
                                              "Erro na imagem: ${grupo.fotoUrl}",
                                            );
                                            print(error);
                                            return const Icon(
                                              Icons.error,
                                              size: 50,
                                              color: Colors.red,
                                            );
                                          },
                                    ),
                                  )
                                : const Icon(
                                    Icons.fastfood,
                                    size: 60,
                                    color: Colors.grey,
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              grupo.descricao,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

        bottomNavigationBar: carrinho.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CarrinhoPage(
                        itens: carrinho,
                        comanda: int.parse(widget.comanda),
                        imagemVersao: imagemVersao,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_cart),
                          const SizedBox(width: 8),
                          Text("${carrinho.length} itens"),
                        ],
                      ),
                      Text(
                        "R\$ ${totalGeral().toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
