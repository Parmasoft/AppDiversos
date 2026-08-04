import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pedido/pages/cliente_busca_page.dart';
import 'package:pedido/services/server_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';

class ParcelaPrazo {
  final int numero;
  final String documento;
  final String emissao;
  final String vencimento;
  final double valor;

  ParcelaPrazo({
    required this.numero,
    required this.documento,
    required this.emissao,
    required this.vencimento,
    required this.valor,
  });

  factory ParcelaPrazo.fromJson(Map<String, dynamic> json) {
    return ParcelaPrazo(
      numero: json['parcela'] ?? 0,
      documento: (json['documento'] ?? '').toString(),
      emissao: (json['emissao'] ?? '').toString(),
      vencimento: (json['vencimento'] ?? '').toString(),
      valor: (json['valor'] ?? 0).toDouble(),
    );
  }
}

class PagamentoPrazoPage extends StatefulWidget {
  final int orcId;
  final double valorTotal;
  final int empresa;
  final int vendedorId;
  final String vendedorDescricao;

  const PagamentoPrazoPage({
    super.key,
    required this.orcId,
    required this.valorTotal,
    this.empresa = 1,
    required this.vendedorId,
    required this.vendedorDescricao,
  });

  @override
  State<PagamentoPrazoPage> createState() => _PagamentoPrazoPageState();
}

class _PagamentoPrazoPageState extends State<PagamentoPrazoPage> {
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _parcelasController = TextEditingController(
    text: '1',
  );
  final TextEditingController _intervaloController = TextEditingController(
    text: '30',
  );

  String _clienteNome = '';

  bool _carregandoSimulacao = false;
  bool _finalizando = false;

  List<ParcelaPrazo> _parcelasGeradas = [];

  int get _clienteId => int.tryParse(_clienteController.text.trim()) ?? 0;
  int get _qtParcelas => int.tryParse(_parcelasController.text.trim()) ?? 0;
  int get _intervaloDias => int.tryParse(_intervaloController.text.trim()) ?? 0;

  Future<void> _simularPrazo() async {
    FocusScope.of(context).unfocus();

    if (_clienteId <= 0) {
      _mostrarMensagem('Informe o código do cliente.');
      return;
    }

    if (_qtParcelas <= 0) {
      _mostrarMensagem('Informe a quantidade de parcelas.');
      return;
    }

    if (_intervaloDias <= 0) {
      _mostrarMensagem('Informe o intervalo em dias.');
      return;
    }

    setState(() {
      _carregandoSimulacao = true;
      _parcelasGeradas = [];
    });

    try {
      final url = Uri.parse(
        '${ServerConfig.baseUrl}/pdv/tablet/pagamento/prazo/simular',
      );

      final ecfId = await _obterEcfId();

      if (ecfId == null) {
        _mostrarMensagem(
          'ECF do tablet não configurado. Verifique a configuração do aparelho.',
        );
        return;
      }

      final body = {
        'empresa': widget.empresa,
        'ecf_id': ecfId,
        'orc_id': widget.orcId,
        'cliente_id': _clienteId,
        'quantidade_parcelas': _qtParcelas,
        'intervalo_dias': _intervaloDias,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        _mostrarMensagem(data['erro'] ?? 'Erro ao simular prazo.');
        return;
      }

      final lista = (data['parcelas'] as List? ?? [])
          .map((e) => ParcelaPrazo.fromJson(e))
          .toList();

      setState(() {
        _parcelasGeradas = lista;
      });
    } catch (e) {
      _mostrarMensagem('Erro ao simular prazo: $e');
    } finally {
      if (mounted) {
        setState(() {
          _carregandoSimulacao = false;
        });
      }
    }
  }

  Future<void> _abrirBuscaCliente() async {
    FocusScope.of(context).unfocus();

    final cliente = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ClienteBuscaPage(empresa: widget.empresa),
      ),
    );

    if (cliente == null || !mounted) return;

    setState(() {
      _clienteController.text = (cliente['id'] ?? '').toString();
      _clienteNome = (cliente['descricao'] ?? cliente['nome'] ?? '').toString();
      _parcelasGeradas = [];
    });
  }

  Future<int?> _obterEcfId() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final valorInt = prefs.getInt('ecf_id');
      if (valorInt != null && valorInt > 0) {
        return valorInt;
      }
    } catch (_) {}

    try {
      final valorString = prefs.getString('ecf_id');
      if (valorString != null && valorString.trim().isNotEmpty) {
        final ecfConvertido = int.tryParse(valorString.trim());
        if (ecfConvertido != null && ecfConvertido > 0) {
          return ecfConvertido;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> _finalizarPrazo() async {
    FocusScope.of(context).unfocus();

    if (_clienteId <= 0) {
      _mostrarMensagem('Informe o código do cliente.');
      return;
    }

    if (_qtParcelas <= 0) {
      _mostrarMensagem('Informe a quantidade de parcelas.');
      return;
    }

    if (_intervaloDias <= 0) {
      _mostrarMensagem('Informe o intervalo em dias.');
      return;
    }

    if (_parcelasGeradas.isEmpty) {
      _mostrarMensagem('Gere as parcelas antes de confirmar.');
      return;
    }

    setState(() {
      _finalizando = true;
    });

    try {
      final url = Uri.parse(
        '${ServerConfig.baseUrl}/pdv/tablet/pagamento/prazo/finalizar',
      );

      final ecfId = await _obterEcfId();

      if (ecfId == null) {
        _mostrarMensagem(
          'ECF do tablet não configurado. Verifique a configuração do aparelho.',
        );
        return;
      }

      final body = {
        "empresa": widget.empresa,
        "ecf_id": ecfId,
        "orc_id": widget.orcId,
        "usuario": 1,
        "vendedor_id": widget.vendedorId,
        "cliente_id": _clienteId,
        "quantidade_parcelas": _qtParcelas,
        "intervalo_dias": _intervaloDias,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        _mostrarMensagem(data['erro'] ?? 'Erro ao finalizar prazo.');
        return;
      }

      if (!mounted) return;

      Navigator.pop(context, {
        "acao": "venda_finalizada",
        "orc_id": widget.orcId,
        "forma_pagamento_id": 5,
        "forma_pagamento_descricao": "PRAZO",
        "valor_total": widget.valorTotal,
        "valor_pago": 0.0,
        "troco": 0.0,
        "status": data["status"],
        "status_descricao": data["status_descricao"],
        "cliente_id": _clienteId,
        "a_prazo": true,
        "quantidade_pagamentos":
            data["quantidade_parcelas"] ?? _parcelasGeradas.length,
        "parcelas": data["parcelas"] ?? [],
      });
    } catch (e) {
      _mostrarMensagem('Erro ao finalizar prazo: $e');
    } finally {
      if (mounted) {
        setState(() {
          _finalizando = false;
        });
      }
    }
  }

  void _mostrarMensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  void _onClienteAlterado(String _) {
    if (_clienteNome.isEmpty && _parcelasGeradas.isEmpty) return;

    setState(() {
      _clienteNome = '';
      _parcelasGeradas = [];
    });
  }

  Widget _buildCampo({
    required String label,
    required TextEditingController controller,
    double largura = 140,
  }) {
    return SizedBox(
      width: largura,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildCampoCliente() {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: _clienteController,
        keyboardType: TextInputType.number,
        onChanged: _onClienteAlterado,
        decoration: InputDecoration(
          labelText: 'Cliente',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
          suffixIcon: IconButton(
            onPressed: _abrirBuscaCliente,
            icon: const Icon(Icons.search),
          ),
        ),
      ),
    );
  }

  Widget _buildResumoSuperior() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Venda: ${widget.orcId}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            'Total: R\$ ${widget.valorTotal.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildCampoCliente(),
            _buildCampo(
              label: 'Parcelas',
              controller: _parcelasController,
              largura: 120,
            ),
            _buildCampo(
              label: 'Intervalo (dias)',
              controller: _intervaloController,
              largura: 150,
            ),
            ElevatedButton.icon(
              onPressed: _carregandoSimulacao ? null : _simularPrazo,
              icon: const Icon(Icons.auto_awesome),
              label: Text(_carregandoSimulacao ? 'Gerando...' : 'Gerar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size(130, 48),
              ),
            ),
          ],
        ),
        if (_clienteNome.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Cliente selecionado: $_clienteNome',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGridParcelas() {
    if (_parcelasGeradas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: const Text(
          'Nenhuma parcela gerada.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3BF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    'Parcela',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Documento',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Emissão',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Vencimento',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Valor',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          ..._parcelasGeradas.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            final fundo = index.isEven ? Colors.white : const Color(0xFFFFFCED);

            return Container(
              color: fundo,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                children: [
                  Expanded(flex: 1, child: Text(item.numero.toString())),
                  Expanded(flex: 2, child: Text(item.documento)),
                  Expanded(flex: 2, child: Text(item.emissao)),
                  Expanded(flex: 2, child: Text(item.vencimento)),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'R\$ ${item.valor.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRodape() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _finalizando ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _finalizando ? null : _finalizarPrazo,
            icon: const Icon(Icons.check),
            label: Text(_finalizando ? 'Finalizando...' : 'Confirmar prazo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _parcelasController.dispose();
    _intervaloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Pagamento a prazo'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildResumoSuperior(),
            const SizedBox(height: 16),
            _buildFormulario(),
            const SizedBox(height: 16),
            Expanded(child: SingleChildScrollView(child: _buildGridParcelas())),
            const SizedBox(height: 16),
            _buildRodape(),
          ],
        ),
      ),
    );
  }
}
