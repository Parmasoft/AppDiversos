import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pedido/services/server_config.dart';

import '../core/app_colors.dart';

class ClienteBuscaPage extends StatefulWidget {
  final int empresa;

  const ClienteBuscaPage({super.key, this.empresa = 1});

  @override
  State<ClienteBuscaPage> createState() => _ClienteBuscaPageState();
}

class _ClienteBuscaPageState extends State<ClienteBuscaPage> {
  final TextEditingController _buscaController = TextEditingController();

  Timer? _debounce;
  bool _carregando = false;
  String _erro = '';
  String _ultimaBusca = '';
  List<Map<String, dynamic>> _clientes = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaController.dispose();
    super.dispose();
  }

  void _aoDigitarBusca(String texto) {
    final q = texto.trim();

    _debounce?.cancel();

    if (q.length < 3) {
      setState(() {
        _ultimaBusca = q;
        _clientes = [];
        _erro = '';
        _carregando = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _buscarClientes(q);
    });
  }

  Future<void> _buscarClientes(String q) async {
    setState(() {
      _carregando = true;
      _erro = '';
      _ultimaBusca = q;
    });

    try {
      final uri = Uri.parse('${ServerConfig.baseUrl}/pdv/clientes/buscar')
          .replace(
            queryParameters: {'empresa': widget.empresa.toString(), 'q': q},
          );

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      dynamic data;
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          data = jsonDecode(response.body);
        }
      }

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _clientes = [];

          _erro = data is Map<String, dynamic>
              ? (data['erro'] ??
                        data['message'] ??
                        data['mensagem'] ??
                        'Erro ao buscar clientes.')
                    .toString()
              : 'Erro ao buscar clientes.';

          _carregando = false;
        });
        return;
      }

      List lista = [];
      if (data is List) {
        lista = data;
      } else if (data is Map<String, dynamic>) {
        lista = (data['dados'] as List?) ?? [];
      }

      setState(() {
        _clientes = lista
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _clientes = [];
        _erro = 'Erro ao buscar clientes: $e';
        _carregando = false;
      });
    }
  }

  Widget _buildLista() {
    final busca = _ultimaBusca.trim();

    if (busca.isEmpty || busca.length < 3) {
      return const Center(
        child: Text(
          'Digite pelo menos 3 caracteres para buscar o cliente.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro.isNotEmpty) {
      return Center(
        child: Text(
          _erro,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_clientes.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum cliente encontrado.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _clientes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final cliente = _clientes[index];

        final id = cliente['id'];
        final nome = (cliente['nome'] ?? '').toString();
        final documento = (cliente['documento'] ?? '').toString();

        return InkWell(
          onTap: () {
            Navigator.pop(context, cliente);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3BF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$id',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (documento.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          documento,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Buscar cliente'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _buscaController,
              autofocus: true,
              onChanged: _aoDigitarBusca,
              decoration: InputDecoration(
                labelText: 'Nome, código ou documento',
                hintText: 'Digite 3 caracteres...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildLista()),
          ],
        ),
      ),
    );
  }
}
