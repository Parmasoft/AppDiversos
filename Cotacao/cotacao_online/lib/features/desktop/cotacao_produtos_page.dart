import 'dart:convert';
import 'package:cotacao_online/app/app_config.dart';
import 'package:cotacao_online/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class CotacaoProdutosPage extends StatefulWidget {
  final int empresa;
  final int cotacaoId;

  const CotacaoProdutosPage({
    super.key,
    required this.empresa,
    required this.cotacaoId,
  });

  @override
  State<CotacaoProdutosPage> createState() => _CotacaoProdutosPageState();
}

/* ============================================================
   DIALOG – INCLUIR PRODUTO
============================================================ */
class IncluirProdutoDialog extends StatefulWidget {
  final int empresa;
  final int cotacaoId;
  final VoidCallback onItemIncluido;

  const IncluirProdutoDialog({
    super.key,
    required this.empresa,
    required this.cotacaoId,
    required this.onItemIncluido,
  });

  @override
  State<IncluirProdutoDialog> createState() => _IncluirProdutoDialogState();
}

class _IncluirProdutoDialogState extends State<IncluirProdutoDialog> {
  final buscaCtrl = TextEditingController();
  final qtdCtrl = TextEditingController();
  final unidadeCtrl = TextEditingController();
  final precoCtrl = TextEditingController();

  final FocusNode buscaFocus = FocusNode();
  final FocusNode sugestoesFocus = FocusNode();
  final FocusNode qtdFocus = FocusNode();
  final FocusNode incluirFocus = FocusNode();

  final ScrollController sugestoesScrollCtrl = ScrollController();

  int sugestaoSelecionada = 0;
  List<Map<String, dynamic>> sugestoes = [];
  Map<String, dynamic>? produtoSelecionado;

  void _scrollParaSelecionado() {
    if (!sugestoesScrollCtrl.hasClients) return;

    const double itemHeight = 48;
    final viewport = sugestoesScrollCtrl.position.viewportDimension;

    final itemTop = sugestaoSelecionada * itemHeight;
    final itemBottom = itemTop + itemHeight;

    final scrollTop = sugestoesScrollCtrl.offset;
    final scrollBottom = scrollTop + viewport;

    if (itemTop < scrollTop) {
      sugestoesScrollCtrl.animateTo(
        itemTop,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    } else if (itemBottom > scrollBottom) {
      sugestoesScrollCtrl.animateTo(
        itemBottom - viewport,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  void _selecionarProduto(Map<String, dynamic> p) {
    setState(() {
      produtoSelecionado = p;
      sugestoes.clear();
      buscaCtrl.text = p['descricao'];
      unidadeCtrl.text = p['unidade'];
      precoCtrl.text = p['preco'].toString();
    });

    Future.delayed(const Duration(milliseconds: 50), () {
      qtdFocus.requestFocus();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      buscaFocus.requestFocus();
    });
  }

  Future<void> buscarProdutos(String termo) async {
    if (termo.length < 3) {
      setState(() => sugestoes = []);
      return;
    }

    final resp = await ApiService.get(
      '${AppConfig.baseUrl}/produtos/busca?empresa=${widget.empresa}&descricao=$termo',
    );

    setState(() {
      sugestoes = List<Map<String, dynamic>>.from(resp as List);
      sugestaoSelecionada = 0;
    });
  }

  Future<void> salvar() async {
    if (produtoSelecionado == null || qtdCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o produto e a quantidade'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final qtd = int.tryParse(qtdCtrl.text);
    if (qtd == null || qtd <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantidade inválida'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await ApiService.post(
        '${AppConfig.baseUrl}/cotacoes/itens/incluir',
        {
          'empresa': widget.empresa,
          'cotacao': widget.cotacaoId,
          'produto': produtoSelecionado!['id'],
          'descricao': produtoSelecionado!['descricao'],
          'unidade': produtoSelecionado!['unidade'],
          'quantidade': qtd,
        },
      );

      // ✅ SUCESSO REAL
      widget.onItemIncluido();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item incluído com sucesso'),
        ),
      );
    } on ApiException catch (e) {
      // ❌ erro controlado da API
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // ❌ erro inesperado
      debugPrint('ERRO INESPERADO incluir item: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro inesperado ao incluir item'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Incluir Produto'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              focusNode: buscaFocus,
              controller: buscaCtrl,
              decoration: const InputDecoration(
                labelText: 'Buscar produto (mín. 3 letras)',
              ),
              onChanged: buscarProdutos,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(sugestoesFocus),
            ),
            if (sugestoes.isNotEmpty)
              Focus(
                focusNode: sugestoesFocus,
                onKey: (node, event) {
                  if (event is RawKeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      setState(() {
                        if (sugestaoSelecionada < sugestoes.length - 1) {
                          sugestaoSelecionada++;
                          _scrollParaSelecionado();
                        }
                      });
                      return KeyEventResult.handled;
                    }

                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      setState(() {
                        if (sugestaoSelecionada > 0) {
                          sugestaoSelecionada--;
                          _scrollParaSelecionado();
                        }
                      });
                      return KeyEventResult.handled;
                    }

                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      _selecionarProduto(sugestoes[sugestaoSelecionada]);
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.handled;
                },
                child: Container(
                  height: 180,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                  ),
                  child: ListView.builder(
                    controller: sugestoesScrollCtrl,
                    itemExtent: 48,
                    itemCount: sugestoes.length,
                    itemBuilder: (context, index) {
                      final p = sugestoes[index];
                      final selecionado = index == sugestaoSelecionada;

                      return Container(
                        color: selecionado
                            ? const Color(0xFFFFF3C4)
                            : Colors.transparent,
                        child: ListTile(
                          dense: true,
                          title: Text(
                            p['descricao'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: unidadeCtrl,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Unidade'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: precoCtrl,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Preço'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: qtdCtrl,
                    focusNode: qtdFocus,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                    onSubmitted: (_) => incluirFocus.requestFocus(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        ElevatedButton(
          focusNode: incluirFocus,
          onPressed: salvar,
          child: const Text('Incluir'),
        ),
      ],
    );
  }
}

/* ============================================================
   TELA PRINCIPAL – GRID
============================================================ */
class _CotacaoProdutosPageState extends State<CotacaoProdutosPage> {
  List<Map<String, dynamic>> itens = [];

  @override
  void initState() {
    super.initState();
    carregarItens();
  }

  Future<void> carregarItens() async {
    final resp = await ApiService.get(
      '${AppConfig.baseUrl}/cotacoes/${widget.cotacaoId}/itens?empresa=${widget.empresa}',
    );

    setState(() {
      itens = List<Map<String, dynamic>>.from(resp as List);
    });
  }

  String get contadorItens => itens.length.toString().padLeft(3, '0');

  Future<void> _editarQuantidade(Map<String, dynamic> item) async {
    final TextEditingController ctrl =
        TextEditingController(text: item['quantidade'].toString());

    final FocusNode quantidadeFocus = FocusNode();
    final FocusNode salvarFocus = FocusNode();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Editar Quantidade'),
          content: TextField(
            controller: ctrl,
            focusNode: quantidadeFocus,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,

            // ENTER → vai para o botão Salvar
            onSubmitted: (_) => salvarFocus.requestFocus(),

            decoration: const InputDecoration(
              labelText: 'Quantidade',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              focusNode: salvarFocus,
              child: const Text('Salvar'),
              onPressed: () async {
                final novaQtd = int.tryParse(ctrl.text);
                if (novaQtd == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Quantidade inválida'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  await ApiService.post(
                    '${AppConfig.baseUrl}/cotacoes/itens/alterar_quantidade',
                    {
                      'empresa': widget.empresa,
                      'cotacao': widget.cotacaoId,
                      'sequencia': item['sequencia'],
                      'quantidade': novaQtd,
                    },
                  );

                  // ✅ SUCESSO REAL
                  await carregarItens();
                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Quantidade alterada com sucesso'),
                    ),
                  );
                } on ApiException catch (e) {
                  // 🔴 ERRO CONTROLADO DA API
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                } catch (e) {
                  // 🔴 ERRO INESPERADO
                  debugPrint('ERRO INESPERADO: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erro inesperado ao alterar quantidade'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _excluirItem(Map<String, dynamic> item) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool carregando = false;

        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Confirmar exclusão'),
              content: carregando
                  ? const SizedBox(
                      height: 48,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const Text('Deseja realmente excluir este item?'),
              actions: [
                TextButton(
                  onPressed: carregando ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: carregando
                      ? null
                      : () async {
                          setState(() => carregando = true);

                          try {
                            await ApiService.post(
                              '${AppConfig.baseUrl}/cotacoes/itens/excluir',
                              {
                                'empresa': widget.empresa,
                                'cotacao': widget.cotacaoId,
                                'sequencia': item['sequencia'],
                              },
                            );

                            await carregarItens();

                            Navigator.pop(ctx);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Item excluído com sucesso'),
                              ),
                            );
                          } on ApiException catch (e) {
                            setState(() => carregando = false);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.message),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } catch (e) {
                            setState(() => carregando = false);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Erro inesperado ao excluir item'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: const Text('Excluir'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _abrirIncluirProduto() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => IncluirProdutoDialog(
        empresa: widget.empresa,
        cotacaoId: widget.cotacaoId,
        onItemIncluido: carregarItens,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: true,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.f2): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<Intent>(
          onInvoke: (_) {
            _abrirIncluirProduto();
            return null;
          },
        ),
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F2),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // 🔙 Voltar (lado esquerdo)
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Voltar'),
                      ),

                      // 🧠 Centro real
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Produtos',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Text(
                              'Qtde: $contadorItens',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ➕ Incluir (lado direito)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Incluir - F2'),
                        onPressed: _abrirIncluirProduto,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Código')),
                        DataColumn(label: Text('Produto')),
                        DataColumn(label: Text('Unidade')),
                        DataColumn(label: Text('Preço')),
                        DataColumn(label: Text('Qtd')),
                        DataColumn(label: Text('Ações')),
                      ],
                      rows: List.generate(itens.length, (index) {
                        final item = itens[index];
                        final linhaPar = index.isEven;

                        return DataRow(
                          color: MaterialStateProperty.all(
                            linhaPar ? const Color(0xFFFFF3C4) : Colors.white,
                          ),
                          cells: [
                            DataCell(Text(item['produto'].toString())),
                            DataCell(Text(item['descricao'] ?? '')),
                            DataCell(Text(item['unidade'] ?? '')),
                            DataCell(Text((item['preco_unitario'] ?? 0)
                                .toStringAsFixed(2))),
                            DataCell(Text(item['quantidade'].toString())),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => _editarQuantidade(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _excluirItem(item),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
