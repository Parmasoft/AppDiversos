import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pedido/services/server_config.dart';
import 'package:http/http.dart' as http;

class ConfigPage extends StatefulWidget {
  final bool emDialogo;

  const ConfigPage({super.key, this.emDialogo = false});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final TextEditingController ipController = TextEditingController();
  final TextEditingController portaController = TextEditingController();
  final TextEditingController ecfController = TextEditingController();

  bool carregandoConfig = true;
  String? mensagemStatus;
  bool mensagemSucesso = false;
  Timer? _timerMensagem;

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
  }

  Future<void> _carregarConfiguracoes() async {
    await ServerConfig.carregar();

    ipController.text = ServerConfig.ip;
    portaController.text = ServerConfig.porta;
    ecfController.text = ServerConfig.ecfId;

    if (!mounted) return;

    setState(() {
      carregandoConfig = false;
    });
  }

  void _mostrarMensagem(String texto, {required bool sucesso}) {
    if (!mounted) return;

    _timerMensagem?.cancel();

    setState(() {
      mensagemStatus = texto;
      mensagemSucesso = sucesso;
    });

    if (texto.trim().isNotEmpty) {
      _timerMensagem = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;

        setState(() {
          mensagemStatus = null;
        });
      });
    }
  }

  @override
  void dispose() {
    _timerMensagem?.cancel();
    ipController.dispose();
    portaController.dispose();
    ecfController.dispose();
    super.dispose();
  }

  Future<void> testarConexao() async {
    final ip = ipController.text.trim();
    final porta = portaController.text.trim();
    final url = Uri.parse("http://$ip:$porta/ping");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 3));

      if (!mounted) return;

      if (response.statusCode == 200) {
        _mostrarMensagem("Servidor conectado com sucesso.", sucesso: true);
      } else {
        _mostrarMensagem(
          "Não foi possível conectar ao servidor.",
          sucesso: false,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _mostrarMensagem(
        "Não foi possível conectar ao servidor.",
        sucesso: false,
      );
    }
  }

  Widget _buildMensagemLocal() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      height: mensagemStatus == null || mensagemStatus!.trim().isEmpty ? 0 : 56,
      curve: Curves.easeInOut,
      child: mensagemStatus == null || mensagemStatus!.trim().isEmpty
          ? const SizedBox.shrink()
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mensagemSucesso
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: mensagemSucesso
                      ? const Color(0xFF81C784)
                      : const Color(0xFFE57373),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    mensagemSucesso
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: mensagemSucesso ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      mensagemStatus!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mensagemSucesso
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFFB71C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conteudo = carregandoConfig
        ? const SizedBox(
            width: 520,
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          )
        : Material(
            color: const Color(0xFFE5E5E5),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 760,
              constraints: const BoxConstraints(maxWidth: 760, minHeight: 500),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),

              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Configuração",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8CC8F),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black26),
                      ),
                      child: const Text(
                        "Servidor / API",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: ipController,
                      decoration: InputDecoration(
                        labelText: "IP do Servidor",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: portaController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Porta",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8CC8F),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black26),
                      ),
                      child: const Text(
                        "Aparelho / Terminal",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: ecfController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "ECF ID do aparelho",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              side: const BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              final ip = ipController.text.trim();
                              final porta = portaController.text.trim();
                              final ecfId = ecfController.text.trim();

                              if (ip.isEmpty ||
                                  porta.isEmpty ||
                                  ecfId.isEmpty) {
                                _mostrarMensagem(
                                  "Preencha IP, porta e ECF ID.",
                                  sucesso: false,
                                );
                                return;
                              }

                              if (int.tryParse(porta) == null) {
                                _mostrarMensagem(
                                  "Porta inválida.",
                                  sucesso: false,
                                );
                                return;
                              }

                              if (int.tryParse(ecfId) == null) {
                                _mostrarMensagem(
                                  "ECF ID inválido.",
                                  sucesso: false,
                                );
                                return;
                              }

                              await ServerConfig.salvar(ip, porta, ecfId);

                              if (!mounted) return;

                              _mostrarMensagem(
                                "Configuração salva com sucesso.",
                                sucesso: true,
                              );
                            },
                            child: const Text("Salvar"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              side: const BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: testarConexao,
                            child: const Text("Testar"),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    _buildMensagemLocal(),

                    const SizedBox(height: 10),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2E9C9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Dica: use o botão \"Testar\" para validar a conexão.\n"
                        "Depois clique \"Salvar\" para gravar no aparelho.\n\n"
                        "URL de teste: http://IP:PORT/ping",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2E9C9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Dica: use o botão \"Testar\" para validar a conexão.\n"
                        "Depois clique \"Salvar\" para gravar no aparelho.\n\n"
                        "URL de teste: http://IP:PORT/ping",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

    if (widget.emDialogo) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 20),
        child: conteudo,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8D48A),
        elevation: 0,
        title: const Text(
          "Configuração",
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(child: conteudo),
    );
  }
}
