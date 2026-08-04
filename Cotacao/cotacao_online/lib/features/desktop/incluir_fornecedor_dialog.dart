import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import 'package:flutter/services.dart';
import 'package:cotacao_online/app/app_config.dart';

class IncluirFornecedorDialog extends StatefulWidget {
  final int empresa;
  final int cotacaoId;
  final VoidCallback onIncluido;

  const IncluirFornecedorDialog({
    super.key,
    required this.empresa,
    required this.cotacaoId,
    required this.onIncluido,
  });

  @override
  State<IncluirFornecedorDialog> createState() =>
      _IncluirFornecedorDialogState();
}

class _IncluirFornecedorDialogState extends State<IncluirFornecedorDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _itemKeys = [];
  final FocusNode _focusLista = FocusNode();
  final FocusNode _focusIncluir = FocusNode();

  int _indexSelecionado = 0;

  List<Map<String, dynamic>> fornecedores = [];
  List<Map<String, dynamic>> filtrados = [];

  Map<String, dynamic>? selecionado;

  @override
  void initState() {
    super.initState();
    carregarFornecedores();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focus.requestFocus();
    });
  }

  void _ajustarScroll() {
    const itemHeight = 56.0;
    final position = _indexSelecionado * itemHeight;

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> carregarFornecedores() async {
    final resp = await http.get(
      Uri.parse(
        '${AppConfig.baseUrl}/fornecedores?empresa=${widget.empresa}',
      ),
    );

    ApiService.validarResposta(resp);

    setState(() {
      fornecedores = List<Map<String, dynamic>>.from(jsonDecode(resp.body));
      filtrados = [];
    });
  }

  void _selecionarFornecedor(Map<String, dynamic> f) {
    setState(() {
      selecionado = f;
      _controller.text = f['razao'];
      filtrados = [];
    });

    _focusIncluir.requestFocus();
  }

  void _garantirVisivel({required bool descendo}) {
    if (_indexSelecionado < 0 || _indexSelecionado >= _itemKeys.length) return;

    final context = _itemKeys[_indexSelecionado].currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        alignment: descendo ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
      );
    }
  }

  void filtrar(String texto) {
    if (texto.trim().length < 3) {
      setState(() {
        filtrados = [];
        _indexSelecionado = 0;
        _itemKeys.clear();
      });
      return;
    }

    final t = texto.toLowerCase();

    setState(() {
      filtrados = fornecedores.where((f) {
        return (f['razao'] ?? '').toString().toLowerCase().contains(t);
      }).toList();

      _indexSelecionado = 0;

      _itemKeys
        ..clear()
        ..addAll(List.generate(filtrados.length, (_) => GlobalKey()));
    });
  }

  Future<void> incluir() async {
    if (selecionado == null) return;

    try {
      await ApiService.post(
        '${AppConfig.baseUrl}/cotacoes/fornecedores/incluir',
        {
          'empresa': widget.empresa,
          'cotacao': widget.cotacaoId,
          'fornecedor': selecionado!['id'],
        },
      );

      widget.onIncluido();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fornecedor incluído com sucesso'),
        ),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Incluir Fornecedor'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              focusNode: _focus,
              decoration: const InputDecoration(
                labelText: 'Fornecedor',
                hintText: 'Digite ao menos 3 letras',
              ),
              onChanged: filtrar,
              onSubmitted: (_) {
                if (filtrados.isNotEmpty) {
                  _focusLista.requestFocus();
                }
              },
            ),
            if (filtrados.isNotEmpty)
              Focus(
                focusNode: _focusLista,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      setState(() {
                        _indexSelecionado =
                            (_indexSelecionado + 1) % filtrados.length;
                      });
                      _garantirVisivel(descendo: true);
                      return KeyEventResult.handled;
                    }

                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      setState(() {
                        _indexSelecionado =
                            (_indexSelecionado - 1 + filtrados.length) %
                                filtrados.length;
                      });
                      _garantirVisivel(descendo: false);
                      return KeyEventResult.handled;
                    }

                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      final f = filtrados[_indexSelecionado];
                      _selecionarFornecedor(f);
                      return KeyEventResult.handled;
                    }
                  }

                  return KeyEventResult.ignored;
                },
                child: SizedBox(
                  height: 220,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: filtrados.length,
                    itemBuilder: (_, i) {
                      final f = filtrados[i];
                      final selecionadoLinha = i == _indexSelecionado;

                      return Container(
                        key: _itemKeys[i],
                        color: selecionadoLinha
                            ? Colors.yellow.shade300
                            : Colors.white,
                        child: ListTile(
                          title: Text(f['razao']),
                          onTap: () => _selecionarFornecedor(f),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          focusNode: _focusIncluir,
          onPressed: incluir,
          child: const Text('Incluir'),
        ),
      ],
    );
  }
}
