import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pedido/core/image_utils.dart';
import 'package:pedido/models/item_carrinho.dart';
import 'package:pedido/pages/carrinho_page.dart';
import 'package:pedido/pages/produto_busca_page.dart';
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
  final String? comanda;

  const MenuPage({super.key, this.comanda});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<Grupo> grupos = [];
  List<ItemCarrinho> carrinho = [];
  List produtos = [];

  bool carregando = true;
  bool carregandoProdutos = false;

  late String imagemVersao;
  int? grupoSelecionadoId;
  int? orcIdAtual;

  double _parseDouble(dynamic valor) {
    if (valor == null) return 0;
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();

    final texto = valor.toString().replaceAll(',', '.');
    return double.tryParse(texto) ?? 0;
  }

  bool _parseBoolFracionado(dynamic valor) {
    final texto = (valor ?? '').toString().trim().toUpperCase();
    return texto == 'S' || texto == 'TRUE' || texto == '1';
  }

  String _parseUnidade(dynamic valor) {
    final texto = (valor ?? '').toString().trim();
    return texto.isEmpty ? 'UN' : texto;
  }

  String _formatarQuantidade(double valor) {
    final texto = valor.toStringAsFixed(3).replaceAll('.', ',');
    return texto.replaceFirst(RegExp(r',?0+$'), '');
  }

  String _formatarValorDigitacao(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  double? _parseValorDigitacao(String texto) {
    var valor = texto.trim();

    if (valor.isEmpty) return null;

    valor = valor.replaceAll('R\$', '').replaceAll(' ', '');

    if (valor.contains(',') && valor.contains('.')) {
      valor = valor.replaceAll('.', '').replaceAll(',', '.');
    } else if (valor.contains(',')) {
      valor = valor.replaceAll(',', '.');
    }

    return double.tryParse(valor);
  }

  @override
  void initState() {
    super.initState();
    imagemVersao = DateTime.now().millisecondsSinceEpoch.toString();
    iniciarTela();
  }

  Future<void> iniciarTela() async {
    await ServerConfig.carregar();

    if (ServerConfig.ecfIdInt <= 0) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Configuração"),
          content: const Text(
            "ECF ID do aparelho não configurado. Abra a configuração e informe o aparelho.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );

      setState(() {
        carregando = false;
      });
      return;
    }

    await abrirVendaNaApi();
    await carregarGrupos();
  }

  Future<void> carregarVendaAtualDaApi() async {
    if (orcIdAtual == null || orcIdAtual! <= 0) return;

    try {
      final url = Uri.parse(
        "${ServerConfig.baseUrl}/pdv/tablet/venda"
        "?empresa=1&ecf_id=${ServerConfig.ecfIdInt}&orc_id=$orcIdAtual",
      );

      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["sucesso"] == true) {
        final itensApi = (data["itens"] as List? ?? []);

        setState(() {
          carrinho = itensApi.map<ItemCarrinho>((item) {
            final produtoId =
                (item["produto_id"] as num?)?.toInt() ??
                int.tryParse(item["produto_id"]?.toString() ?? "0") ??
                0;

            final valorUnitario =
                (item["valor_unitario"] as num?)?.toDouble() ??
                double.tryParse(item["valor_unitario"]?.toString() ?? "0") ??
                0.0;

            final quantidade = _parseDouble(item["quantidade"]);

            return ItemCarrinho(
              id: produtoId,
              descricao: item["descricao"]?.toString() ?? "",
              preco: valorUnitario,
              fotoUrl: item["foto_url"]?.toString() ?? "",
              quantidade: quantidade,
              existente: true,
              sequencialItem:
                  (item["sequencial"] as num?)?.toInt() ??
                  int.tryParse(item["sequencial"]?.toString() ?? ""),
              unidadeVenda: _parseUnidade(item["unidade_venda"]),
              fracionado: _parseBoolFracionado(item["fracionado"]),
            );
          }).toList();
        });
      } else {
        throw Exception(data["erro"] ?? "Erro ao carregar venda");
      }
    } catch (e) {
      debugPrint("Erro ao carregar venda atual: $e");
    }
  }

  Future<void> adicionarItemNaApi(
    Map produto,
    double quantidade, {
    double? valorUnitario,
  }) async {
    if (orcIdAtual == null || orcIdAtual! <= 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Venda ainda não foi aberta na API.")),
      );
      return;
    }

    try {
      final url = Uri.parse(
        "${ServerConfig.baseUrl}/pdv/tablet/venda/item/adicionar",
      );

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "empresa": 1,
          "ecf_id": ServerConfig.ecfIdInt,
          "orc_id": orcIdAtual,
          "produto_id": produto["id"],
          "quantidade": quantidade,
          "valor_unitario": valorUnitario,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["sucesso"] == true) {
        await carregarVendaAtualDaApi();

        if (!mounted) return;

        final aviso = data["aviso"]?.toString() ?? "";
        if (aviso.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(aviso)));
        }
      } else {
        throw Exception(data["erro"] ?? "Erro ao adicionar item");
      }
    } catch (e) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Erro"),
          content: Text("Não foi possível adicionar o item.\n\n$e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
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
          if (lista.isNotEmpty) {
            grupoSelecionadoId = lista.first.id;
          }
          carregando = false;
        });

        if (lista.isNotEmpty) {
          await carregarProdutosDoGrupo(lista.first.id);
        }
      } else {
        setState(() {
          carregando = false;
          grupos = [];
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar grupos: $e");
      setState(() {
        carregando = false;
        grupos = [];
      });
    }
  }

  Future<void> abrirPesquisaProdutos() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProdutoBuscaPage(
          empresa: 1,
          imagemVersao: imagemVersao,
          modoConsulta: false,
        ),
      ),
    );

    if (resultado != null && resultado is Map) {
      final item = Map<String, dynamic>.from(resultado);

      final quantidade =
          (item["quantidade"] as num?)?.toDouble() ??
          double.tryParse(
            item["quantidade"]?.toString().replaceAll(',', '.') ?? "1",
          ) ??
          1.0;

      final precoUnitario =
          (item["preco_unitario"] as num?)?.toDouble() ??
          double.tryParse(item["preco_unitario"]?.toString() ?? "") ??
          (item["preco"] as num?)?.toDouble() ??
          double.tryParse(item["preco"]?.toString() ?? "0") ??
          0.0;

      await adicionarItemNaApi(item, quantidade, valorUnitario: precoUnitario);
    }
  }

  Future<void> abrirCarrinho() async {
    if (orcIdAtual == null || orcIdAtual! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Venda ainda não foi aberta na API.")),
      );
      return;
    }

    await carregarVendaAtualDaApi();
    if (!mounted) return;

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarrinhoPage(
          itens: carrinho,
          comanda: orcIdAtual!,
          imagemVersao: imagemVersao,
        ),
      ),
    );

    if (resultado != null &&
        resultado is Map<String, dynamic> &&
        resultado["acao"] == "venda_finalizada") {
      Navigator.pop(context, resultado);
      return;
    }

    await carregarVendaAtualDaApi();
    if (!mounted) return;

    setState(() {});
  }

  Future<void> abrirVendaNaApi() async {
    try {
      final url = Uri.parse("${ServerConfig.baseUrl}/pdv/tablet/venda/abrir");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "empresa": 1,
          "usuario": 1,
          "ecf_id": ServerConfig.ecfIdInt,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["sucesso"] == true) {
        final novoOrcId =
            (data["orc_id"] as num?)?.toInt() ??
            int.tryParse(data["orc_id"]?.toString() ?? "0") ??
            0;

        setState(() {
          orcIdAtual = novoOrcId;
        });

        await carregarVendaAtualDaApi();
      } else {
        throw Exception(data["erro"] ?? "Erro ao abrir venda");
      }
    } catch (e) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Erro"),
          content: Text("Não foi possível abrir a venda na API.\n\n$e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> carregarProdutosDoGrupo(int grupoId) async {
    setState(() {
      carregandoProdutos = true;
      produtos = [];
    });

    try {
      final url = Uri.parse(
        "${ServerConfig.baseUrl}/pdv/produtos?empresa=1&grupo=$grupoId",
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          produtos = data["dados"] as List;
          carregandoProdutos = false;
        });
      } else {
        setState(() {
          produtos = [];
          carregandoProdutos = false;
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar produtos do grupo: $e");
      setState(() {
        produtos = [];
        carregandoProdutos = false;
      });
    }
  }

  Future<bool> _confirmarSaida() async {
    if (carrinho.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Venda em andamento"),
          content: const Text(
            "Finalize ou limpe o carrinho antes de sair da venda.",
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
    return carrinho.fold(0.0, (sum, item) => sum + item.total);
  }

  int totalItens() {
    return carrinho.length;
  }

  double totalQuantidade() {
    return carrinho.fold(0.0, (sum, item) => sum + item.quantidade);
  }

  String nomeCategoriaSelecionada() {
    for (final grupo in grupos) {
      if (grupo.id == grupoSelecionadoId) {
        return grupo.descricao;
      }
    }
    return 'Produtos';
  }

  void abrirModalQuantidade(Map produto) {
    int quantidadeSelecionada = 1;
    final fotoUrl = produto["foto_url"]?.toString();
    final precoOriginal = (produto["preco"] as num?)?.toDouble() ?? 0.0;
    final descricao = produto["descricao"] ?? "";

    final precoController = TextEditingController();

    double precoEditavel = precoOriginal;
    bool exibindoEditorPreco = false;
    bool precoPendenteConfirmacao = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setStateModal) {
            final bottomInset = MediaQuery.of(modalContext).viewInsets.bottom;
            final tecladoAberto = bottomInset > 0;
            final totalAtual = precoEditavel * quantidadeSelecionada;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: EdgeInsets.zero,
                    child: Container(
                      width: 360,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EFF7),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!tecladoAberto)
                            Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: fotoUrl != null && fotoUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        montarUrlImagemComVersao(
                                          fotoUrl,
                                          imagemVersao,
                                        ),
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) {
                                          return const Icon(
                                            Icons.fastfood,
                                            size: 40,
                                            color: Colors.black38,
                                          );
                                        },
                                      ),
                                    )
                                  : const Icon(
                                      Icons.fastfood,
                                      size: 40,
                                      color: Colors.black38,
                                    ),
                            ),
                          SizedBox(height: tecladoAberto ? 8 : 18),
                          Text(
                            descricao,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Preço original: R\$ ${precoOriginal.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Preço atual: R\$ ${precoEditavel.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setStateModal(() {
                                exibindoEditorPreco = !exibindoEditorPreco;

                                if (exibindoEditorPreco) {
                                  precoController.clear();
                                  precoPendenteConfirmacao = true;
                                } else {
                                  precoPendenteConfirmacao = false;
                                }
                              });
                            },
                            icon: const Icon(Icons.price_change_outlined),
                            label: const Text("ALTERAR PREÇO"),
                          ),
                          if (exibindoEditorPreco) ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: precoController,
                              autofocus: true,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: "Digite o novo preço",
                                hintText: "",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () {
                                  final novoPreco = _parseValorDigitacao(
                                    precoController.text,
                                  );

                                  if (novoPreco == null || novoPreco <= 0) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Informe um preço válido.",
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setStateModal(() {
                                    precoEditavel = novoPreco;
                                    exibindoEditorPreco = false;
                                    precoPendenteConfirmacao = false;
                                    precoController.clear();
                                  });
                                },
                                child: const Text("CONFIRMAR PREÇO"),
                              ),
                            ),
                          ],
                          SizedBox(height: tecladoAberto ? 12 : 18),
                          const Text(
                            "Quantos deseja?",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: tecladoAberto ? 10 : 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFE5E5E5),
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
                              const SizedBox(width: 14),
                              Container(
                                width: 56,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.amber,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  quantidadeSelecionada.toString(),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                width: 46,
                                height: 46,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFE5E5E5),
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
                          SizedBox(height: tecladoAberto ? 12 : 18),
                          Text(
                            "Total: R\$ ${totalAtual.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: tecladoAberto ? 14 : 22),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed:
                                  (exibindoEditorPreco ||
                                      precoPendenteConfirmacao)
                                  ? null
                                  : () async {
                                      Navigator.of(dialogContext).pop();
                                      await adicionarItemNaApi(
                                        produto,
                                        quantidadeSelecionada.toDouble(),
                                        valorUnitario: precoEditavel,
                                      );
                                    },
                              child: Text(
                                "ADICIONAR R\$ ${totalAtual.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<double?> _abrirDialogAlteracaoPrecoMenu({
    required double precoAtual,
    required double precoOriginal,
  }) async {
    final controller = TextEditingController();

    final resultado = await showDialog<double>(
      context: context,
      builder: (_) {
        String? erroTexto;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final tecladoAberto = MediaQuery.of(context).viewInsets.bottom > 0;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text("Alterar preço"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Preço original: R\$ ${precoOriginal.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: "Digite o novo preço",
                      hintText: "",
                      errorText: erroTexto,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) {
                      setStateDialog(() {
                        erroTexto = null;
                      });
                    },
                    onSubmitted: (_) {
                      FocusScope.of(context).unfocus();
                      setStateDialog(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCELAR"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: tecladoAberto
                      ? null
                      : () async {
                          final novoPreco = _parseValorDigitacao(
                            controller.text,
                          );

                          if (novoPreco == null || novoPreco <= 0) {
                            setStateDialog(() {
                              erroTexto = "Informe um preço válido";
                            });
                            return;
                          }

                          FocusScope.of(context).unfocus();

                          await Future.delayed(
                            const Duration(milliseconds: 150),
                          );

                          if (!context.mounted) return;

                          Navigator.of(context).pop(novoPreco);
                        },
                  child: const Text("CONFIRMAR"),
                ),
              ],
            );
          },
        );
      },
    );

    return resultado;
  }

  Future<Map<String, dynamic>?> abrirModalQuantidadeFracionada(
    Map produto,
  ) async {
    final controller = TextEditingController();
    final unidade = _parseUnidade(produto["unidade_venda"]);
    final fotoUrl = produto["foto_url"]?.toString();
    final precoOriginal = (produto["preco"] as num?)?.toDouble() ?? 0.0;
    final descricao = produto["descricao"]?.toString() ?? "";

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        String? erroTexto;
        double precoEditavel = precoOriginal;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final tecladoAberto = MediaQuery.of(context).viewInsets.bottom > 0;
            final quantidadeAtual = _parseDouble(controller.text);
            final totalAtual = precoEditavel * quantidadeAtual;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((fotoUrl?.trim().isNotEmpty ?? false) &&
                          !tecladoAberto)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            montarUrlImagemComVersao(fotoUrl, imagemVersao),
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.fastfood,
                                size: 64,
                                color: Colors.grey,
                              );
                            },
                          ),
                        ),
                      if ((fotoUrl?.trim().isNotEmpty ?? false) &&
                          !tecladoAberto)
                        const SizedBox(height: 10),

                      Text(
                        descricao,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "Unidade: $unidade",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        "Preço original: R\$ ${precoOriginal.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        "Preço atual: R\$ ${precoEditavel.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(height: 10),

                      OutlinedButton.icon(
                        onPressed: () async {
                          final novoPreco =
                              await _abrirDialogAlteracaoPrecoMenu(
                                precoAtual: precoEditavel,
                                precoOriginal: precoOriginal,
                              );

                          if (novoPreco != null) {
                            setStateDialog(() {
                              precoEditavel = novoPreco;
                            });
                          }
                        },
                        icon: const Icon(Icons.price_change_outlined),
                        label: const Text("ALTERAR PREÇO"),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        "Informe a quantidade em $unidade",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),

                      const SizedBox(height: 10),

                      TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: "Ex.: 1,250",
                          errorText: erroTexto,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.amber,
                              width: 2,
                            ),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) {
                          setStateDialog(() {
                            erroTexto = null;
                          });
                        },
                      ),

                      const SizedBox(height: 12),

                      Text(
                        "Total: R\$ ${totalAtual.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("CANCELAR"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () {
                                final quantidade = _parseDouble(
                                  controller.text,
                                );

                                if (quantidade <= 0) {
                                  setStateDialog(() {
                                    erroTexto = "Informe uma quantidade válida";
                                  });
                                  return;
                                }

                                Navigator.pop(context, {
                                  "quantidade": quantidade,
                                  "preco_unitario": precoEditavel,
                                });
                              },
                              child: const Text("ADICIONAR"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return resultado;
  }

  Widget _buildCardProduto(Map produto) {
    final fotoUrl = produto["foto_url"]?.toString();
    final preco = (produto["preco"] as num?)?.toDouble() ?? 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final fracionado = _parseBoolFracionado(produto["fracionado"]);

        if (fracionado) {
          final resultado = await abrirModalQuantidadeFracionada(produto);

          if (!mounted) return;

          if (resultado != null) {
            final quantidade =
                (resultado["quantidade"] as num?)?.toDouble() ?? 0.0;

            final precoUnitario =
                (resultado["preco_unitario"] as num?)?.toDouble() ??
                (produto["preco"] as num?)?.toDouble() ??
                0.0;

            if (quantidade > 0) {
              await Future.delayed(const Duration(milliseconds: 200));

              if (!mounted) return;

              await adicionarItemNaApi(
                produto,
                quantidade,
                valorUnitario: precoUnitario,
              );
            }
          }
        } else {
          abrirModalQuantidade(produto);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: fotoUrl != null && fotoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Image.network(
                          montarUrlImagemComVersao(fotoUrl, imagemVersao),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.fastfood,
                                size: 30,
                                color: Colors.black38,
                              ),
                            );
                          },
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.fastfood,
                          size: 30,
                          color: Colors.black38,
                        ),
                      ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      produto["descricao"] ?? "",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'R\$ ${preco.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _quantidadeColunasProdutos() {
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final totalColunas = _quantidadeColunasProdutos();

    return WillPopScope(
      onWillPop: _confirmarSaida,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: carregando
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.20,
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      if (await _confirmarSaida()) {
                                        Navigator.pop(context);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: const Padding(
                                      padding: EdgeInsets.only(
                                        left: 4,
                                        right: 4,
                                        bottom: 10,
                                        top: 2,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.arrow_back,
                                            color: Colors.black,
                                            size: 24,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Categorias',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: grupos.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'Nenhuma categoria encontrada.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          )
                                        : ListView.separated(
                                            itemCount: grupos.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(height: 10),
                                            itemBuilder: (context, index) {
                                              final grupo = grupos[index];
                                              final selecionado =
                                                  grupo.id ==
                                                  grupoSelecionadoId;

                                              return InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                onTap: () async {
                                                  setState(() {
                                                    grupoSelecionadoId =
                                                        grupo.id;
                                                  });

                                                  await carregarProdutosDoGrupo(
                                                    grupo.id,
                                                  );
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 18,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: selecionado
                                                        ? const Color(
                                                            0xFFFACC15,
                                                          )
                                                        : Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: selecionado
                                                          ? Colors.amber
                                                          : Colors.black12,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    grupo.descricao,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: selecionado
                                                          ? Colors.black
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(6, 12, 12, 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.black12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          nomeCategoriaSelecionada(),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: abrirPesquisaProdutos,
                                        icon: const Icon(Icons.search),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      IconButton(
                                        onPressed: () {},
                                        icon: const Icon(Icons.more_vert),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: carregandoProdutos
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : produtos.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'Nenhum produto encontrado nesta categoria.',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black54,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          )
                                        : GridView.builder(
                                            itemCount: produtos.length,
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: totalColunas,
                                                  crossAxisSpacing: 10,
                                                  mainAxisSpacing: 10,
                                                  childAspectRatio: 0.92,
                                                ),
                                            itemBuilder: (context, index) {
                                              final produto = produtos[index];
                                              return _buildCardProduto(produto);
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: abrirCarrinho,
                      child: Container(
                        height: 78,
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 6),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.shopping_cart_outlined,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: carrinho.isEmpty
                                  ? const Text(
                                      'Seu carrinho está vazio',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Total: R\$ ${totalGeral().toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${totalItens()} item${totalItens() == 1 ? '' : 's'}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: abrirCarrinho,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black87,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Ver carrinho',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
