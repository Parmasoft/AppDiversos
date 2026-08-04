import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'rolos_page.dart';

class BuscarProdutoPage extends StatefulWidget {
  final String baseUrl;
  final int empresaId;

  const BuscarProdutoPage({
    super.key,
    required this.baseUrl,
    required this.empresaId,
  });

  @override
  State<BuscarProdutoPage> createState() => _BuscarProdutoPageState();
}

class _BuscarProdutoPageState extends State<BuscarProdutoPage> {
  final _buscaCtrl = TextEditingController();
  final _buscaFocus = FocusNode();

  bool _carregando = false;
  bool _carregandoPendentes = false;

  String _mensagem = "";
  List<Map<String, dynamic>> _produtos = [];
  List<Map<String, dynamic>> _pendentes = [];

  Timer? _debounce;
  final Set<String> _lotesImpressosLocal = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _carregarPendentes();
      }
    });
  }

  Future<String> _carregarTipoCodigoEtiqueta() async {
    final prefs = await SharedPreferences.getInstance();
    final tipo = prefs.getString("tipo_codigo_etiqueta") ?? "CODE128";

    return tipo == "QR" ? "QR" : "CODE128";
  }

  Future<void> _carregarPendentes() async {
    if (_buscaCtrl.text.trim().isNotEmpty) return;

    setState(() {
      _carregandoPendentes = true;
      _mensagem = "";
    });

    try {
      final url = Uri.parse(
        "${widget.baseUrl}/rolos/pendentes?empresa=${widget.empresaId}",
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) {
        setState(() {
          _pendentes = [];
          _mensagem = "Erro ao carregar etiquetas pendentes.";
        });
        return;
      }

      final dados = jsonDecode(resp.body);
      final lista = dados["rolos"] as List? ?? [];

      setState(() {
        _pendentes = lista
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      setState(() {
        _pendentes = [];
        _mensagem = "Erro de conexão ao carregar pendentes.";
      });
    } finally {
      if (mounted) {
        setState(() => _carregandoPendentes = false);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaCtrl.dispose();
    _buscaFocus.dispose();
    super.dispose();
  }

  void _onBuscaAlterada(String valor) {
    _debounce?.cancel();

    final termo = valor.trim();

    if (termo.isEmpty) {
      setState(() {
        _produtos = [];
        _mensagem = "";
      });

      _carregarPendentes();
      return;
    }

    if (termo.length < 3) {
      setState(() {
        _produtos = [];
        _pendentes = [];
        _mensagem = "Digite pelo menos 3 caracteres para buscar.";
      });
      return;
    }

    setState(() {
      _pendentes = [];
      _mensagem = "";
    });

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _buscar();
    });
  }

  Future<void> _buscar() async {
    final termo = _buscaCtrl.text.trim();

    if (termo.length < 3) {
      setState(() {
        _mensagem = "Digite pelo menos 3 caracteres.";
        _produtos = [];
      });
      return;
    }

    setState(() {
      _carregando = true;
      _mensagem = "";
      _produtos = [];
    });

    try {
      final url = Uri.parse(
        "${widget.baseUrl}/produtos/buscar?empresa=${widget.empresaId}&descricao=${Uri.encodeComponent(termo)}",
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) {
        setState(() {
          _mensagem = "Erro ao buscar produtos. Status: ${resp.statusCode}";
        });
        return;
      }

      final dados = jsonDecode(resp.body);

      final lista = dados["produtos"] as List? ?? [];

      setState(() {
        _produtos = lista
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        if (_produtos.isEmpty) {
          _mensagem = "Nenhum produto encontrado.";
        }
      });
    } catch (e) {
      setState(() {
        _mensagem = "Erro de conexão com a API.";
      });
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _abrirRolos(Map<String, dynamic> produto) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RolosPage(
          baseUrl: widget.baseUrl,
          empresaId: widget.empresaId,
          produto: produto,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _buscaCtrl.clear();
      _produtos = [];
      _mensagem = "";
      _carregando = false;
    });

    await _carregarPendentes();

    if (mounted) {
      FocusScope.of(context).unfocus();
    }
  }

  Widget _itemProduto(Map<String, dynamic> produto) {
    final codigo = produto["produto_id"]?.toString() ?? "";
    final descricao = produto["descricao"]?.toString() ?? "";
    final unidade = produto["unidade"]?.toString() ?? "";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: () => _abrirRolos(produto),
        title: Text(
          descricao,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text("Código: $codigo   |   UN: $unidade"),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
      ),
    );
  }

  double _totalPendentes() {
    double total = 0;

    for (final item in _pendentes) {
      total += double.tryParse(item["quantidade"].toString()) ?? 0.0;
    }

    return total;
  }

  String _formatarQtd(dynamic valor) {
    final numero = double.tryParse(valor.toString()) ?? 0.0;
    return numero.toStringAsFixed(2).replaceAll(".", ",");
  }

  void _imprimirPendentes() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Impressão será ligada no próximo passo."),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _painelPendentes() {
    if (_buscaCtrl.text.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }

    if (_carregandoPendentes) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: LinearProgressIndicator(),
      );
    }

    if (_pendentes.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white70,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: const Text(
          "Nenhuma etiqueta pendente.",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      );
    }

    final grupos = _pendentesAgrupadosPorLote();

    return Column(
      children: [
        const SizedBox(height: 16),

        //Container(
        //  width: double.infinity,
        //  padding: const EdgeInsets.all(14),
        //  decoration: BoxDecoration(
        //    color: Colors.black,
        //    borderRadius: BorderRadius.circular(14),
        //    border: Border.all(color: Colors.black),
        //  ),
        //  child: const Text(
        //    "<<< Etiquetas Pendentes >>>",
        //    textAlign: TextAlign.center,
        //    style: TextStyle(
        //      fontSize: 20,
        //      fontWeight: FontWeight.bold,
        //      color: Colors.white,
        //    ),
        //  ),
        //),
        const SizedBox(height: 8),

        Expanded(
          child: ListView.builder(
            itemCount: grupos.length,
            itemBuilder: (_, index) {
              final grupo = grupos[index];

              final lote = grupo["lote"]?.toString() ?? "";
              final produtoId = _formatarProduto7(
                grupo["produto_id"]?.toString() ?? "",
              );

              final qtdEtiquetas = grupo["qtd_etiquetas"] as int;
              final impresso =
                  grupo["impresso"]?.toString().toUpperCase() ?? "N";

              final jaImpresso =
                  impresso == "S" || _lotesImpressosLocal.contains(lote);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                color: jaImpresso ? const Color(0xFFFFF8D6) : null,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _imprimirLotePendente(grupo),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 85,
                          child: Text(
                            "Lote $lote",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),

                        SizedBox(
                          width: 90,
                          child: Text(
                            produtoId,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),

                        Expanded(
                          child: Text(
                            "Qtde ${qtdEtiquetas.toString().padLeft(2, "0")}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),

                        SizedBox(
                          width: 38,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: "Imprimir oficial",
                            icon: const Icon(
                              Icons.print,
                              color: Colors.black87,
                              size: 22,
                            ),
                            onPressed: () => _imprimirLotePendente(grupo),
                          ),
                        ),

                        // TEMPORÁRIO: botão para imprimir QR Code na Elgin i9.
                        SizedBox(
                          width: 44,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(38, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: Colors.blueGrey.shade900,
                            ),
                            onPressed: () => _imprimirLotePendenteI9(grupo),

                            child: const Text(
                              "QR",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _pendentesAgrupadosPorLote() {
    final Map<String, Map<String, dynamic>> agrupado = {};

    for (final item in _pendentes) {
      final lote = item["lote"]?.toString() ?? "";
      if (lote.isEmpty || lote == "null") continue;

      final quantidade = double.tryParse(item["quantidade"].toString()) ?? 0.0;
      final idRolo = int.tryParse(item["id"].toString()) ?? 0;
      final impresso = item["impresso"]?.toString().toUpperCase() ?? "N";

      if (!agrupado.containsKey(lote)) {
        agrupado[lote] = {
          "lote": lote,
          "produto_id": item["produto_id"]?.toString() ?? "",
          "descricao": item["descricao"]?.toString() ?? "",
          "qtd_etiquetas": 0,
          "total_quantidade": 0.0,
          "ultimo_id": idRolo,
          "impresso": "S",
        };
      }

      agrupado[lote]!["qtd_etiquetas"] =
          (agrupado[lote]!["qtd_etiquetas"] as int) + 1;

      agrupado[lote]!["total_quantidade"] =
          (agrupado[lote]!["total_quantidade"] as double) + quantidade;

      final ultimoAtual = agrupado[lote]!["ultimo_id"] as int;
      if (idRolo > ultimoAtual) {
        agrupado[lote]!["ultimo_id"] = idRolo;
      }

      if (impresso != "S") {
        agrupado[lote]!["impresso"] = "N";
      }
    }

    final lista = agrupado.values.toList();

    lista.sort((a, b) {
      final idA = a["ultimo_id"] as int;
      final idB = b["ultimo_id"] as int;
      return idB.compareTo(idA);
    });

    if (lista.length > 10) {
      return lista.take(10).toList();
    }

    return lista;
  }

  List<Map<String, dynamic>> _pendentesAgrupados() {
    final Map<String, Map<String, dynamic>> agrupado = {};

    for (final item in _pendentes) {
      final produtoId = item["produto_id"]?.toString() ?? "";
      if (produtoId.isEmpty) continue;

      final quantidade = double.tryParse(item["quantidade"].toString()) ?? 0.0;
      final idRolo = int.tryParse(item["id"].toString()) ?? 0;

      if (!agrupado.containsKey(produtoId)) {
        agrupado[produtoId] = {
          "produto_id": produtoId,
          "descricao": item["descricao"]?.toString() ?? "",
          "qtd_etiquetas": 0,
          "total_quantidade": 0.0,
          "ultimo_id": idRolo,
        };
      }

      agrupado[produtoId]!["qtd_etiquetas"] =
          (agrupado[produtoId]!["qtd_etiquetas"] as int) + 1;

      agrupado[produtoId]!["total_quantidade"] =
          (agrupado[produtoId]!["total_quantidade"] as double) + quantidade;

      final ultimoAtual = agrupado[produtoId]!["ultimo_id"] as int;
      if (idRolo > ultimoAtual) {
        agrupado[produtoId]!["ultimo_id"] = idRolo;
      }
    }

    final lista = agrupado.values.toList();

    // Mais recentes primeiro
    lista.sort((a, b) {
      final idA = a["ultimo_id"] as int;
      final idB = b["ultimo_id"] as int;
      return idB.compareTo(idA);
    });

    // Mostra somente os últimos 10 lotes/produtos
    if (lista.length > 10) {
      return lista.take(10).toList();
    }

    return lista;
  }

  String _formatarProduto8(String produtoId) {
    final numero = int.tryParse(produtoId) ?? 0;
    return numero.toString().padLeft(8, "0");
  }

  String _formatarProduto7(String produtoId) {
    final numero = int.tryParse(produtoId) ?? 0;
    return numero.toString().padLeft(7, "0");
  }

  Future<void> _imprimirRoloPendente(Map<String, dynamic> item) async {
    final idRolo = int.tryParse(item["id"].toString()) ?? 0;
    final idRoloTxt = idRolo.toString();

    if (idRolo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Rolo inválido para impressão."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final url = Uri.parse("${widget.baseUrl}/rolos/imprimir-rolo");

      final resp = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "empresa": widget.empresaId,
              "pror_id": idRolo,
              "usuario": 1,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final dados = jsonDecode(resp.body);

      if (!mounted) return;

      if (resp.statusCode == 200 && dados["status"] == "ok") {
        setState(() {
          _lotesImpressosLocal.add(idRoloTxt);

          final index = _pendentes.indexWhere(
            (e) => e["id"].toString() == idRoloTxt,
          );

          if (index >= 0) {
            _pendentes[index]["impresso"] = "S";
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dados["mensagem"] ?? "Etiqueta enviada."),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dados["mensagem"] ?? "Erro ao imprimir etiqueta."),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao chamar impressão: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _imprimirLotePendente(Map<String, dynamic> grupo) async {
    final lote = int.tryParse(grupo["lote"].toString()) ?? 0;
    final loteTxt = lote.toString();

    if (lote <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lote inválido para impressão."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final tipoCodigo = await _carregarTipoCodigoEtiqueta();

      final url = Uri.parse("${widget.baseUrl}/rolos/imprimir-lote");

      final resp = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "empresa": widget.empresaId,
              "lote": lote,
              "usuario": 1,
              "tipo_codigo": tipoCodigo,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final dados = jsonDecode(resp.body);

      if (!mounted) return;

      if (resp.statusCode == 200 && dados["status"] == "ok") {
        setState(() {
          _lotesImpressosLocal.add(loteTxt);

          for (final item in _pendentes) {
            if (item["lote"].toString() == loteTxt) {
              item["impresso"] = "S";
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dados["mensagem"] ?? "Lote enviado para impressão."),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dados["mensagem"] ?? "Erro ao imprimir lote."),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao chamar impressão: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // TEMPORÁRIO: impressão de teste na Elgin i9.
  // Não mexe no fluxo oficial da L42/Zebra.
  Future<void> _imprimirLotePendenteI9(Map<String, dynamic> grupo) async {
    final lote = int.tryParse(grupo["lote"].toString()) ?? 0;

    if (lote <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lote inválido para impressão na i9."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final url = Uri.parse("${widget.baseUrl}/rolos/imprimir-lote-i9-qr");

      final resp = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "empresa": widget.empresaId,
              "lote": lote,
              "usuario": 1,
              "impressora": "ELGIN i9(USB)",
            }),
          )
          .timeout(const Duration(seconds: 20));

      dynamic dados;
      try {
        dados = jsonDecode(resp.body);
      } catch (_) {
        dados = null;
      }

      if (!mounted) return;

      if (resp.statusCode == 200 &&
          dados is Map<String, dynamic> &&
          dados["status"] == "ok") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dados["mensagem"]?.toString() ??
                  "Lote enviado em QR Code para a i9.",
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        final msg = dados is Map<String, dynamic>
            ? dados["mensagem"]?.toString() ?? "Erro ao imprimir QR Code na i9."
            : "Erro ao imprimir QR Code na i9.";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao chamar impressão i9: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _imprimirProdutoPendente(Map<String, dynamic> grupo) async {
    final produtoIdFmt = _formatarProduto8(grupo["produto_id"].toString());
    final produtoId = int.tryParse(grupo["produto_id"].toString()) ?? 0;

    if (produtoId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Produto inválido para impressão."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final url = Uri.parse("${widget.baseUrl}/rolos/imprimir-produto");

      final resp = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "empresa": widget.empresaId,
              "produto_id": produtoId,
              "usuario": 1,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final dados = jsonDecode(resp.body);

      if (!mounted) return;

      if (resp.statusCode == 200 && dados["status"] == "ok") {
        setState(() {
          _lotesImpressosLocal.add(produtoIdFmt);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dados["mensagem"] ?? "Impressão enviada."),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dados["mensagem"] ?? "Erro ao imprimir."),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao chamar impressão: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text("Buscar Produto"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),

      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF9E3), Color(0xFFEDEDED)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _buscaCtrl,
                focusNode: _buscaFocus,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: _onBuscaAlterada,
                onSubmitted: (_) => _buscar(),
                decoration: InputDecoration(
                  labelText: "Digite parte da descrição",
                  //hintText: "Ex: CURVIM, TECIDO, PLASTICO...",
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              if (_carregando) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],

              if (_mensagem.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    _mensagem,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              Expanded(
                child: _buscaCtrl.text.trim().isEmpty
                    ? _painelPendentes()
                    : ListView.builder(
                        itemCount: _produtos.length,
                        itemBuilder: (_, index) {
                          return _itemProduto(_produtos[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
