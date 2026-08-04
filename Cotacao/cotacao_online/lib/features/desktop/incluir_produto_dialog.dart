import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cotacao_online/app/app_config.dart';

class IncluirProdutoDialog extends StatefulWidget {
  final int empresa;
  final int cotacaoId;

  const IncluirProdutoDialog({
    super.key,
    required this.empresa,
    required this.cotacaoId,
  });

  @override
  State<IncluirProdutoDialog> createState() => _IncluirProdutoDialogState();
}

class _IncluirProdutoDialogState extends State<IncluirProdutoDialog> {
  final TextEditingController buscaCtrl = TextEditingController();
  final TextEditingController qtdCtrl = TextEditingController();

  List<Map<String, dynamic>> sugestoes = [];
  Map<String, dynamic>? produtoSelecionado;

  Future<void> buscarProdutos(String termo) async {
    if (termo.length < 3) return;

    final resp = await http.get(
      Uri.parse(
        '${AppConfig.baseUrl}/produtos/busca'
        '?descricao=$termo'
        '&empresa=${widget.empresa}',
      ),
    );

    if (resp.statusCode == 200) {
      setState(() {
        sugestoes = List<Map<String, dynamic>>.from(jsonDecode(resp.body));
      });
    }
  }

  Future<void> salvar() async {
    if (produtoSelecionado == null || qtdCtrl.text.isEmpty) return;

    await http.post(
      Uri.parse('${AppConfig.baseUrl}/cotacoes/itens/incluir'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'empresa': widget.empresa,
        'cotacao': widget.cotacaoId,
        'produto': produtoSelecionado!['produto'],
        'descricao': produtoSelecionado!['descricao'],
        'unidade': produtoSelecionado!['unidade'],
        'quantidade': int.parse(qtdCtrl.text),
      }),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Incluir Produto'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: buscaCtrl,
              decoration: const InputDecoration(labelText: 'Buscar produto'),
              onChanged: buscarProdutos,
            ),
            if (sugestoes.isNotEmpty)
              SizedBox(
                height: 150,
                child: ListView(
                  children: sugestoes.map((p) {
                    return ListTile(
                      title: Text(p['descricao']),
                      onTap: () {
                        setState(() {
                          produtoSelecionado = p;
                          sugestoes.clear();
                          buscaCtrl.text = p['descricao'];
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: qtdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantidade'),
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
          onPressed: salvar,
          child: const Text('Incluir'),
        ),
      ],
    );
  }
}
