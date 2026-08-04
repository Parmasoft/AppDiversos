//import 'dart:convert';
import 'package:cotacao_online/app/app_config.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'incluir_fornecedor_dialog.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
//import 'package:font_awesome_flutter/font_awesome_flutter.dart';

const Color _rowEven = Colors.white;
const Color _rowOdd = Color(0xFFFFF6CC); // amarelo claro padrão grid
const Color _rowDivider = Color(0xFFE0E0E0);

class CotacaoFornecedoresPage extends StatefulWidget {
  final int empresa;
  final int cotacaoId;

  const CotacaoFornecedoresPage({
    super.key,
    required this.empresa,
    required this.cotacaoId,
  });

  @override
  State<CotacaoFornecedoresPage> createState() =>
      _CotacaoFornecedoresPageState();
}

class _CotacaoFornecedoresPageState extends State<CotacaoFornecedoresPage> {
  List<Map<String, dynamic>> fornecedores = [];

  @override
  void initState() {
    super.initState();
    carregarFornecedores();
  }

  Future<void> carregarFornecedores() async {
    final resp = await ApiService.get(
      '${AppConfig.baseUrl}/cotacoes/${widget.cotacaoId}/fornecedores?empresa=${widget.empresa}',
    );

    setState(() {
      fornecedores = List<Map<String, dynamic>>.from(resp as List);
    });
  }

  Future<void> _marcarComoEnviado(Map<String, dynamic> fornecedor) async {
    try {
      await ApiService.post(
        '${AppConfig.baseUrl}/cotacoes/fornecedor/marcar_enviado',
        {
          'empresa': widget.empresa,
          'cotacao': widget.cotacaoId,
          'fornecedor': fornecedor['id'],
        },
      );

      await carregarFornecedores();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fornecedor marcado como enviado'),
        ),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao marcar fornecedor como enviado'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _abrirWhatsAppFornecedor(Map<String, dynamic> f) async {
    try {
      final telefone = f['telefone'];
      final token = f['token'];

      if (telefone == null || token == null) {
        throw Exception('Telefone ou token ausente');
      }

      final mensagem = '''
Olá! 👋

Segue o link para informar os preços da cotação nº ${widget.cotacaoId}:

https://cotacao.parmasoft.com.br/c/$token

Atenciosamente,
Parmasoft
''';

      final uri = Uri.parse(
        'https://wa.me/55$telefone?text=${Uri.encodeComponent(mensagem)}',
      );

      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!ok) {
        throw Exception('Não foi possível abrir o WhatsApp');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao abrir WhatsApp'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _enviarLinkFornecedor(Map<String, dynamic> fornecedor) async {
    try {
      final resp = await ApiService.post(
        '${AppConfig.baseUrl}/cotacoes/fornecedores/gerar_link',
        {
          'empresa': widget.empresa,
          'cotacao': widget.cotacaoId,
          'fornecedor': fornecedor['id'],
        },
      );

      final link = resp['link'];
      final telefone = resp['telefone'];

      final mensagemZap = '''
Olá! 👋

Segue o link para informar os preços da cotação nº ${widget.cotacaoId}:

$link

Atenciosamente,
Parmasoft
''';

      final urlZap = Uri.parse(
        'https://wa.me/55$telefone?text=${Uri.encodeComponent(mensagemZap)}',
      );

      final ok = await launchUrl(
        urlZap,
        mode: LaunchMode.externalApplication,
      );

      if (!ok) {
        throw Exception('Não foi possível abrir o WhatsApp');
      }

      // 🔄 recarrega a lista para trazer token atualizado
      await carregarFornecedores();
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao abrir WhatsApp do fornecedor'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _abrirIncluirFornecedor() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => IncluirFornecedorDialog(
        empresa: widget.empresa,
        cotacaoId: widget.cotacaoId,
        onIncluido: carregarFornecedores,
      ),
    );
  }

  // 🗑️ EXCLUIR FORNECEDOR (IGUAL PRODUTOS)
  Future<void> _excluirFornecedor(Map<String, dynamic> fornecedor) async {
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
                  : const Text(
                      'Deseja realmente excluir este fornecedor da cotação?',
                    ),
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
                              '${AppConfig.baseUrl}/cotacoes/fornecedores/excluir',
                              {
                                'empresa': widget.empresa,
                                'cotacao': widget.cotacaoId,
                                'fornecedor': fornecedor['id'],
                              },
                            );

                            await carregarFornecedores();
                            Navigator.pop(ctx);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Fornecedor excluído com sucesso'),
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
                                content: Text(
                                    'Erro inesperado ao excluir fornecedor'),
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

  @override
  Widget build(BuildContext context) {
    final total = fornecedores.length.toString().padLeft(3, '0');

    return FocusableActionDetector(
      autofocus: true,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.f2): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<Intent>(
          onInvoke: (_) {
            _abrirIncluirFornecedor();
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
                  // 🔝 HEADER PADRÃO
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Voltar'),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Fornecedores',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Text(
                              'Qtde: $total',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Incluir - F2'),
                        onPressed: _abrirIncluirFornecedor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 📋 GRID
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(
                          Colors.grey.shade200,
                        ),
                        dataRowHeight: 42,
                        headingRowHeight: 40,
                        dividerThickness: 0.6,
                        columns: const [
                          DataColumn(label: Text('Código')),
                          DataColumn(label: Text('Razão Social')),
                          DataColumn(label: Text('Fantasia')),
                          DataColumn(label: Text('CNPJ')),
                          DataColumn(label: Text('Telefone')),
                          DataColumn(label: Text('Ações')),
                        ],
                        rows: List.generate(fornecedores.length, (index) {
                          final f = fornecedores[index];

                          final status = f['utilizado'];

                          debugPrint(
                              'STATUS DO FORNECEDOR ${f['id']}: "$status"');

                          return DataRow(
                            color: MaterialStateProperty.all(
                              status == 'E'
                                  ? Colors.green.shade100
                                  : status == 'S'
                                      ? Colors.grey.shade300
                                      : (index.isEven ? _rowOdd : _rowEven),
                            ),
                            cells: [
                              DataCell(Text(f['id'].toString())),
                              DataCell(Text(f['razao'] ?? '')),
                              DataCell(Text(f['fantasia'] ?? '')),
                              DataCell(Text(f['cnpj'] ?? '')),
                              DataCell(Text(f['telefone'] ?? '')),
                              DataCell(
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // 🟢 WHATSAPP
                                    IconButton(
                                      icon: const Icon(Icons.chat,
                                          color: Colors.green),
                                      tooltip: status == 'N'
                                          ? 'Gerar link e abrir WhatsApp'
                                          : status == 'E'
                                              ? 'Reabrir WhatsApp com link já gerado'
                                              : 'Fornecedor já respondeu',
                                      onPressed: status == 'N'
                                          ? () => _enviarLinkFornecedor(f)
                                          : status == 'E'
                                              ? () =>
                                                  _abrirWhatsAppFornecedor(f)
                                              : null,
                                    ),

                                    // ✔️ MARCAR COMO ENVIADO
                                    IconButton(
                                      icon: const Icon(Icons.check_circle,
                                          color: Colors.green),
                                      tooltip: status == 'N'
                                          ? 'Marcar como enviado'
                                          : status == 'E'
                                              ? 'Link já enviado'
                                              : 'Fornecedor já respondeu',
                                      onPressed:
                                          (status == 'N' && f['token'] != null)
                                              ? () => _marcarComoEnviado(f)
                                              : null,
                                    ),

                                    // 🗑️ EXCLUIR
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      tooltip: 'Excluir fornecedor',
                                      onPressed: () => _excluirFornecedor(f),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
