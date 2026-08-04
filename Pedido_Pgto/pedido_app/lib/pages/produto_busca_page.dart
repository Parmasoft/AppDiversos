import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pedido/core/image_utils.dart';
import 'package:pedido/services/api_services.dart';

class ProdutoBuscaPage extends StatefulWidget {
  final int empresa;
  final String imagemVersao;
  final bool modoConsulta;

  const ProdutoBuscaPage({
    super.key,
    required this.empresa,
    required this.imagemVersao,
    this.modoConsulta = false,
  });

  @override
  State<ProdutoBuscaPage> createState() => _ProdutoBuscaPageState();
}

class _ProdutoBuscaPageState extends State<ProdutoBuscaPage> {
  final TextEditingController _controller = TextEditingController();

  List produtos = [];
  Timer? _debounce;
  bool carregando = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  double _precoProduto(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '0') ?? 0.0;
  }

  bool _produtoEhFracionado(Map p) {
    return (p["fracionado"]?.toString().trim().toUpperCase() ?? "N") == "S";
  }

  String _unidadeProduto(Map p) {
    final unidade = p["unidade_venda"]?.toString().trim() ?? "";
    return unidade.isEmpty ? "UN" : unidade;
  }

  dynamic _normalizarQuantidadeParaRetorno(double quantidade) {
    if (quantidade == quantidade.truncateToDouble()) {
      return quantidade.toInt();
    }
    return quantidade;
  }

  double? _parseQuantidadeDigitada(String texto) {
    var valor = texto.trim();

    if (valor.isEmpty) return null;

    if (valor.contains(',') && valor.contains('.')) {
      valor = valor.replaceAll('.', '').replaceAll(',', '.');
    } else if (valor.contains(',')) {
      valor = valor.replaceAll(',', '.');
    }

    return double.tryParse(valor);
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

  Future<double?> _abrirDialogAlteracaoPreco({
    required double precoAtual,
    required double precoOriginal,
  }) async {
    final controller = TextEditingController(
      text: _formatarValorDigitacao(precoAtual),
    );

    final resultado = await showDialog<double>(
      context: context,
      builder: (_) {
        String? erroTexto;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                      labelText: "Novo preço unitário",
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
                  onPressed: () {
                    final novoPreco = _parseValorDigitacao(controller.text);

                    if (novoPreco == null || novoPreco <= 0) {
                      setStateDialog(() {
                        erroTexto = "Informe um preço válido";
                      });
                      return;
                    }

                    Navigator.pop(context, novoPreco);
                  },
                  child: const Text("CONFIRMAR"),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return resultado;
  }

  void buscar(String texto) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (texto.trim().length < 3) {
        if (!mounted) return;
        setState(() {
          produtos = [];
          carregando = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        carregando = true;
      });

      final resultado = await ApiService.buscarProdutos(widget.empresa, texto);

      if (!mounted) return;
      setState(() {
        produtos = resultado;
        carregando = false;
      });
    });
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _buscarCodigoLido(String codigo) async {
    final texto = codigo.trim();

    if (texto.isEmpty) {
      _mostrarMensagem("Código de barras inválido.");
      return;
    }

    _debounce?.cancel();

    setState(() {
      _controller.text = texto;
      carregando = true;
      produtos = [];
    });

    try {
      final resultado = await ApiService.buscarProdutos(widget.empresa, texto);

      if (!mounted) return;

      setState(() {
        produtos = resultado;
        carregando = false;
      });

      if (resultado.isEmpty) {
        _mostrarMensagem("Produto não encontrado para este código de barras.");
        return;
      }

      if (resultado.length == 1) {
        final produto = Map<String, dynamic>.from(resultado.first as Map);

        if (widget.modoConsulta) {
          await _abrirConsultaProduto(produto);
        } else {
          await _selecionarProdutoParaInclusao(produto);
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      _mostrarMensagem("Erro ao buscar produto pelo código: $e");
    }
  }

  Future<void> _abrirLeitorCodigoBarras() async {
    FocusScope.of(context).unfocus();

    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );

    String? codigoLido;

    try {
      codigoLido = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          bool processando = false;

          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return Dialog(
                insetPadding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 420,
                    height: 520,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          color: Colors.amber,
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  "Ler código de barras",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              MobileScanner(
                                controller: controller,
                                onDetect: (capture) {
                                  if (processando) return;

                                  final barcodes = capture.barcodes;
                                  if (barcodes.isEmpty) return;

                                  final codigo = barcodes.first.rawValue
                                      ?.trim();

                                  if (codigo == null || codigo.isEmpty) return;

                                  processando = true;
                                  setStateDialog(() {});
                                  Navigator.pop(dialogContext, codigo);
                                },
                              ),
                              Center(
                                child: Container(
                                  width: 300,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.amber,
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 18,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.70),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    processando
                                        ? "Código lido. Aguarde..."
                                        : "Aponte a câmera para o código de barras do produto.",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    } finally {
      controller.dispose();
    }

    if (codigoLido == null || !mounted) return;

    await _buscarCodigoLido(codigoLido);
  }

  Future<void> _abrirConsultaProduto(Map p) async {
    final preco = _precoProduto(p["preco"]);
    final fotoUrl = montarUrlImagemComVersao(
      p["foto_url"]?.toString(),
      widget.imagemVersao,
    );

    await showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((p["foto_url"]?.toString().trim().isNotEmpty ?? false))
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      fotoUrl,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.fastfood,
                          size: 80,
                          color: Colors.grey,
                        );
                      },
                    ),
                  )
                else
                  const Icon(Icons.fastfood, size: 80, color: Colors.grey),

                const SizedBox(height: 14),

                Text(
                  p["descricao"]?.toString() ?? "",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  "R\$ ${preco.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                if ((p["codigo"] ?? p["id"] ?? "").toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Código: ${(p["codigo"] ?? p["id"]).toString()}",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                if (_produtoEhFracionado(p)) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Produto fracionado • Unidade: ${_unidadeProduto(p)}",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("FECHAR"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _selecionarQuantidadeInteira(
    Map p,
    double preco,
  ) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        int qtd = 1;
        double precoEditavel = preco;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final total = precoEditavel * qtd;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((p["foto_url"]?.toString().trim().isNotEmpty ?? false))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          montarUrlImagemComVersao(
                            p["foto_url"]?.toString(),
                            widget.imagemVersao,
                          ),
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
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
                      p["descricao"]?.toString() ?? "",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "Preço original: R\$ ${preco.toStringAsFixed(2)}",
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () async {
                        final novoPreco = await _abrirDialogAlteracaoPreco(
                          precoAtual: precoEditavel,
                          precoOriginal: preco,
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

                    const SizedBox(height: 18),

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
                            border: Border.all(color: Colors.amber),
                            borderRadius: BorderRadius.circular(8),
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

                    Text(
                      "Total: R\$ ${total.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                      ),
                      onPressed: () {
                        Navigator.pop(context, {
                          "quantidade": qtd.toDouble(),
                          "preco_unitario": precoEditavel,
                        });
                      },
                      child: Text(
                        "ADICIONAR R\$ ${total.toStringAsFixed(2)}",
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _selecionarQuantidadeFracionada(
    Map p,
    double preco,
  ) async {
    final controller = TextEditingController();
    final unidade = _unidadeProduto(p);

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        String? erroTexto;
        double precoEditavel = preco;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final tecladoAberto = MediaQuery.of(context).viewInsets.bottom > 0;
            final quantidadeAtual =
                _parseQuantidadeDigitada(controller.text) ?? 0.0;
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
                      if ((p["foto_url"]?.toString().trim().isNotEmpty ??
                              false) &&
                          !tecladoAberto)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            montarUrlImagemComVersao(
                              p["foto_url"]?.toString(),
                              widget.imagemVersao,
                            ),
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
                      if ((p["foto_url"]?.toString().trim().isNotEmpty ??
                              false) &&
                          !tecladoAberto)
                        const SizedBox(height: 10),

                      Text(
                        p["descricao"]?.toString() ?? "",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        "Preço original: R\$ ${preco.toStringAsFixed(2)}",
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
                        ),
                      ),

                      const SizedBox(height: 10),

                      OutlinedButton.icon(
                        onPressed: () async {
                          final novoPreco = await _abrirDialogAlteracaoPreco(
                            precoAtual: precoEditavel,
                            precoOriginal: preco,
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
                                final quantidade = _parseQuantidadeDigitada(
                                  controller.text,
                                );

                                if (quantidade == null || quantidade <= 0) {
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

    controller.dispose();
    return resultado;
  }

  Future<void> _selecionarProdutoParaInclusao(Map p) async {
    final preco = _precoProduto(p["preco"]);
    final ehFracionado = _produtoEhFracionado(p);

    final resultado = ehFracionado
        ? await _selecionarQuantidadeFracionada(p, preco)
        : await _selecionarQuantidadeInteira(p, preco);

    if (resultado != null) {
      final quantidade = (resultado["quantidade"] as num).toDouble();
      final precoUnitario =
          (resultado["preco_unitario"] as num?)?.toDouble() ?? preco;

      Navigator.pop(context, {
        ...p,
        "quantidade": _normalizarQuantidadeParaRetorno(quantidade),
        "preco_unitario": precoUnitario,
        "preco_original": preco,
        "foto_url": montarUrlImagemComVersao(
          p["foto_url"]?.toString(),
          widget.imagemVersao,
        ),
      });
    }
  }

  Widget _buildConteudo() {
    final texto = _controller.text.trim();

    if (texto.length < 3) {
      return const Center(
        child: Text(
          "Digite pelo menos 3 letras para pesquisar.",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      );
    }

    if (carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (produtos.isEmpty) {
      return const Center(
        child: Text(
          "Nenhum produto encontrado.",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: produtos.length,
      itemBuilder: (context, index) {
        final p = produtos[index];
        final preco = _precoProduto(p["preco"]);
        final ehFracionado = _produtoEhFracionado(p);
        final unidade = _unidadeProduto(p);

        return ListTile(
          leading: const Icon(Icons.shopping_bag_outlined),
          title: Text(p["descricao"]?.toString() ?? ""),
          subtitle: Text(
            ehFracionado
                ? "R\$ ${preco.toStringAsFixed(2)} • $unidade • fracionado"
                : "R\$ ${preco.toStringAsFixed(2)}",
          ),
          trailing: widget.modoConsulta
              ? const Icon(Icons.visibility_outlined)
              : Icon(
                  ehFracionado
                      ? Icons.straighten_outlined
                      : Icons.add_circle_outline,
                ),
          onTap: () async {
            if (widget.modoConsulta) {
              await _abrirConsultaProduto(p);
            } else {
              await _selecionarProdutoParaInclusao(p);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.modoConsulta ? "Pesquisa de preço" : "Buscar produto",
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.modoConsulta
                    ? "Digite descrição, código ou leia o código de barras..."
                    : "Digite descrição, código ou leia o código de barras...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: "Ler código de barras",
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _abrirLeitorCodigoBarras,
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: buscar,
            ),
          ),
          Expanded(child: _buildConteudo()),
        ],
      ),
    );
  }
}
