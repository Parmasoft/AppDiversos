import 'cotacao_fornecedores_page.dart';
import 'cotacao_produtos_page.dart';
import 'cotacao_nova_desktop_page.dart';
import 'package:flutter/material.dart';
import '../../services/cotacao_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cotacao_online/app/app_config.dart';

class CotacoesListDesktopPage extends StatefulWidget {
  const CotacoesListDesktopPage({super.key});

  @override
  State<CotacoesListDesktopPage> createState() =>
      _CotacoesListDesktopPageState();
}

class _CotacoesListDesktopPageState extends State<CotacoesListDesktopPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _cotacoes = [];

  @override
  void initState() {
    super.initState();
    _carregarCotacoes();
  }

  Future<void> _gerarLinksVendedores(int cotacaoId) async {
    try {
      final resp = await http.post(
        Uri.parse(
          '${AppConfig.baseUrl}/cotacoes/fornecedores/gerar_links',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'empresa': 1,
          'cotacao': cotacaoId,
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('Erro ao gerar links');
      }

      final data = jsonDecode(resp.body);

      if (data['ok'] != true) {
        throw Exception(data['erro'] ?? 'Erro desconhecido');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Links para vendedores gerados com sucesso'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar links: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _carregarCotacoes() async {
    setState(() => _loading = true);

    try {
      final lista = await CotacaoService.listarCotacoes(
        empresa: 1,
      );

      setState(() {
        _cotacoes = lista;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar cotações: $e')),
      );
    }
  }

  Future<void> _novaCotacao() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CotacaoNovaDesktopModal(),
    );

    if (result == true) {
      _carregarCotacoes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: const Text('Cotações'),
        actions: [
          ElevatedButton.icon(
            onPressed: _novaCotacao,
            icon: const Icon(Icons.add),
            label: const Text('Nova cotação'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cotacoes.isEmpty
              ? const Center(child: Text('Nenhuma cotação encontrada'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Nº')),
                        DataColumn(label: Text('Abertura')),
                        DataColumn(label: Text('Fechamento')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Descrição')),
                        DataColumn(label: Text('Ações')),
                      ],
                      rows: List.generate(_cotacoes.length, (index) {
                        final c = _cotacoes[index];
                        final bool linhaPar = index.isEven;

                        return DataRow(
                          color: MaterialStateProperty.all(
                            linhaPar ? const Color(0xFFFFF3C4) : Colors.white,
                          ),
                          cells: [
                            DataCell(
                              Text(
                                c['cot_id'].toString().padLeft(6, '0'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataCell(Text(c['data_abertura'] ?? '')),
                            DataCell(Text(c['data_fechamento'] ?? '')),
                            DataCell(Text(c['status'] ?? '')),
                            DataCell(
                              SizedBox(
                                width: 260,
                                child: Text(
                                  c['descricao'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Produtos da Cotação',
                                    icon: const Icon(Icons.playlist_add),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CotacaoProdutosPage(
                                            empresa: 1,
                                            cotacaoId: c['cot_id'],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Fornecedores da Cotação',
                                    icon: const Icon(Icons.store),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              CotacaoFornecedoresPage(
                                            empresa: 1,
                                            cotacaoId: c['cot_id'],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Enviar link para vendedores',
                                    icon: const Icon(
                                      Icons.send,
                                      color: Colors.green,
                                    ),
                                    onPressed: () {
                                      _gerarLinksVendedores(c['cot_id']);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
    );
  }
}
