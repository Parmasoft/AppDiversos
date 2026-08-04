import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class VincularCodigoPage extends StatefulWidget {
  final String codigoBarras;
  final String baseUrl;

  const VincularCodigoPage({
    super.key,
    required this.codigoBarras,
    required this.baseUrl,
  });

  @override
  State<VincularCodigoPage> createState() => _VincularCodigoPageState();
}

class _VincularCodigoPageState extends State<VincularCodigoPage> {
  final TextEditingController _buscaCtrl = TextEditingController();

  bool _carregando = false;
  bool _gravando = false;
  bool _buscandoFoto = false;
  String _mensagem = "";
  String _textoFotoLido = "";
  List<dynamic> _produtos = [];
  Map<String, dynamic>? _selecionado;
  Timer? _debounceBusca;

  @override
  void dispose() {
    _debounceBusca?.cancel();
    _buscaCtrl.dispose();
    super.dispose();
  }

  String _limparTextoFoto(String texto) {
    var t = texto.toUpperCase();

    const acentos = {
      'Á': 'A',
      'À': 'A',
      'Â': 'A',
      'Ã': 'A',
      'É': 'E',
      'Ê': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ô': 'O',
      'Õ': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ç': 'C',
    };

    acentos.forEach((de, para) {
      t = t.replaceAll(de, para);
    });

    for (final ch in ['.', ',', '-', '_', '/', '\\', '(', ')', '%', ':', ';']) {
      t = t.replaceAll(ch, ' ');
    }

    final ignorar = <String>{
      'DE',
      'DA',
      'DO',
      'DAS',
      'DOS',
      'COM',
      'PARA',
      'POR',
      'EM',
      'PRODUTO',
      'USO',
      'ANTES',
      'LEIA',
      'INSTRUCOES',
      'ROTULO',
      'ATENCAO',
      'PERIGO',
      'MANTENHA',
      'FORA',
      'ALCANCE',
      'CRIANCA',
      'CRIANÇAS',
      'INTEGRAL',
      'ORIGINAL',
      'REGISTRO',
      'VALIDADE',
      'LOTE',
      'FABRICACAO',
      'FABRICAÇÃO',
    };

    final palavras = t
        .split(RegExp(r'\s+'))
        .map((p) => p.trim())
        .where((p) => p.length >= 2)
        .where((p) => !ignorar.contains(p))
        .toList();

    final unicas = <String>[];

    for (final p in palavras) {
      if (!unicas.contains(p)) {
        unicas.add(p);
      }
    }

    return unicas.take(10).join(' ');
  }

  void _aoDigitarBusca(String valor) {
    _debounceBusca?.cancel();

    final termo = valor.trim();

    if (termo.length < 3) {
      setState(() {
        _mensagem = "Digite pelo menos 3 caracteres para buscar.";
        _produtos = [];
        _selecionado = null;
      });
      return;
    }

    _debounceBusca = Timer(const Duration(milliseconds: 600), () {
      _buscar();
    });
  }

  String _formatarPreco(dynamic valor) {
    final numero = double.tryParse(valor.toString()) ?? 0.0;
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    return formatter.format(numero);
  }

  Future<void> _buscarPorFoto() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _buscandoFoto = true;
      _mensagem = "";
      _textoFotoLido = "";
      _produtos = [];
      _selecionado = null;
    });

    try {
      final picker = ImagePicker();

      final foto = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1400,
      );

      if (foto == null) {
        if (!mounted) return;
        setState(() {
          _buscandoFoto = false;
        });
        return;
      }

      final inputImage = InputImage.fromFilePath(foto.path);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final textoLido = recognizedText.text.trim();
      final termoBusca = _limparTextoFoto(textoLido);

      if (!mounted) return;

      if (termoBusca.length < 3) {
        setState(() {
          _buscandoFoto = false;
          _textoFotoLido = textoLido;
          _mensagem = "Não consegui identificar texto suficiente na foto.";
        });
        return;
      }

      setState(() {
        _buscandoFoto = false;
        _textoFotoLido = textoLido;
        _buscaCtrl.text = termoBusca;
      });

      await _buscar();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _buscandoFoto = false;
        _mensagem = "Erro ao ler a foto do produto.";
      });
    }
  }

  Future<void> _buscar() async {
    final termo = _buscaCtrl.text.trim();

    if (termo.length < 3) {
      setState(() {
        _mensagem = "Digite pelo menos 3 caracteres para buscar.";
        _produtos = [];
        _selecionado = null;
      });
      return;
    }

    setState(() {
      _carregando = true;
      _mensagem = "";
      _produtos = [];
      _selecionado = null;
    });

    try {
      final url = Uri.parse(
        "${widget.baseUrl}/produto/buscar-descricao?empresa=1&termo=${Uri.encodeComponent(termo)}",
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (resp.statusCode != 200) {
        setState(() {
          _mensagem = "Erro ao buscar produtos.";
        });
        return;
      }

      final json = jsonDecode(resp.body);

      final produtos = List<dynamic>.from(json["produtos"] ?? []);

      produtos.sort((a, b) {
        final descA = (a["descricao"] ?? "").toString().toUpperCase();
        final descB = (b["descricao"] ?? "").toString().toUpperCase();
        return descA.compareTo(descB);
      });

      setState(() {
        _produtos = produtos;
        _mensagem = produtos.isEmpty
            ? "Nenhum produto encontrado com essa busca."
            : "";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mensagem = "Erro de conexão com o servidor.";
      });
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _confirmarVinculo() async {
    if (_selecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Selecione um produto primeiro."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final produtoId = _selecionado!["produto_id"];
    final descricao = _selecionado!["descricao"] ?? "";

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmar vínculo"),
        content: Text(
          "Deseja vincular o código:\n\n"
          "${widget.codigoBarras}\n\n"
          "ao produto:\n\n"
          "$produtoId - $descricao ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Não"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sim, vincular"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _gravando = true);

    try {
      final resp = await http
          .post(
            Uri.parse("${widget.baseUrl}/produto/vincular-codigo"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "empresa": 1,
              "produto_id": produtoId,
              "codigo_barras": widget.codigoBarras,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final json = jsonDecode(resp.body);

      if (!mounted) return;

      if (resp.statusCode == 200 && json["status"] == "ok") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(json["mensagem"] ?? "Código vinculado com sucesso."),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(json["mensagem"] ?? "Erro ao vincular código."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro de conexão ao vincular código."),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _gravando = false);
      }
    }
  }

  Widget _mensagemOperacional() {
    if (_mensagem.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.orange.shade100,
      child: Text(
        _mensagem,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _listaProdutos() {
    if (_produtos.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      itemCount: _produtos.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final p = _produtos[index];
        final selecionado = _selecionado?["produto_id"] == p["produto_id"];

        return InkWell(
          onTap: () {
            FocusScope.of(context).unfocus();
            setState(() => _selecionado = p);
          },
          child: Container(
            color: selecionado ? Colors.green.shade100 : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  child: Text(
                    "${p["score"] ?? 0}%",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${p["produto_id"]} - ${p["descricao"] ?? ""}",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "UN: ${p["unidade"] ?? ""}   ${_formatarPreco(p["preco"])}",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selecionado)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,

        appBar: AppBar(
          title: Text(
            widget.codigoBarras,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.black,
            tabs: [
              Tab(icon: Icon(Icons.camera_alt), text: "Foto"),
              Tab(icon: Icon(Icons.search), text: "Busca"),
            ],
          ),
        ),

        bottomNavigationBar: Container(
          height: 68,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _gravando ? null : _confirmarVinculo,
                  child: Container(
                    color: _selecionado == null
                        ? Colors.grey.shade300
                        : Colors.green.shade600,
                    child: Center(
                      child: _gravando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Vincular código ao produto selecionado",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        body: TabBarView(
          children: [
            // ================================================================
            // ABA FOTO
            // ================================================================
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade100,
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _buscandoFoto ? null : _buscarPorFoto,
                      icon: _buscandoFoto
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt),
                      label: Text(
                        _buscandoFoto ? "Lendo foto..." : "Buscar por Foto",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                _mensagemOperacional(),
                Expanded(child: _listaProdutos()),
              ],
            ),

            // ================================================================
            // ABA BUSCA
            // ================================================================
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade100,
                  child: TextField(
                    controller: _buscaCtrl,
                    textInputAction: TextInputAction.search,
                    onChanged: _aoDigitarBusca,
                    onSubmitted: (_) => _buscar(),
                    decoration: InputDecoration(
                      labelText: "Buscar produto",
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: _carregando
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                _mensagemOperacional(),
                Expanded(child: _listaProdutos()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
