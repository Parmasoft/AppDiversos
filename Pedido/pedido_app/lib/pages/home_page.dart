import 'package:flutter/material.dart';
import 'package:pedido/pages/config_page.dart';
import 'package:pedido/services/api_services.dart';
import 'package:pedido/widgets/logo_widget.dart';
import '../core/app_colors.dart';
import 'menu_page.dart';
import 'dart:convert';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String numeroComanda = "";

  void adicionarNumero(String numero) {
    if (numeroComanda.length < 2) {
      setState(() {
        numeroComanda += numero;
      });
    }
  }

  void deletarNumero() {
    if (numeroComanda.isNotEmpty) {
      setState(() {
        numeroComanda = numeroComanda.substring(0, numeroComanda.length - 1);
      });
    }
  }

  Future<void> confirmar() async {
    if (numeroComanda.isEmpty) return;

    try {
      final response = await ApiService.buscarComanda(
        empresa: 1,
        comanda: numeroComanda,
      );

      // COMANDA EM USO NO BALCÃO
      if (response.statusCode == 409) {
        final dados = jsonDecode(response.body);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFFFFF3B0), // amarelo leve
            title: const Text(
              "Atenção!!!",
              style: TextStyle(
                color: Colors.black,
                fontSize: 50,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              dados["erro"],
              style: const TextStyle(color: Colors.black, fontSize: 19),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  "OK",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

        return;
      }

      // COMANDA LIVRE → ABRE MENU
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MenuPage(comanda: numeroComanda),
        ),
      ).then((_) {
        setState(() {
          numeroComanda = "";
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao consultar servidor")),
      );
    }
  }

  Widget buildBotao(String texto, {VoidCallback? onTap, Color? cor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: cor ?? AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.black, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              texto,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),

      appBar: AppBar(
        backgroundColor: const Color(0xFFE5E5E5),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConfigPage()),
              );
            },
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),

            // Logo 3D
            const LogoWidget(),

            const SizedBox(height: 50),

            // Campo Comanda
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  const Text("Nº COMANDA", style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 90,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.black, width: 2),
                    ),
                    child: Text(
                      numeroComanda.padLeft(2, "0"),
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            //const Spacer(),
            const SizedBox(height: 5),

            // Teclado
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      buildBotao("7", onTap: () => adicionarNumero("7")),
                      buildBotao("8", onTap: () => adicionarNumero("8")),
                      buildBotao("9", onTap: () => adicionarNumero("9")),
                    ],
                  ),
                  Row(
                    children: [
                      buildBotao("4", onTap: () => adicionarNumero("4")),
                      buildBotao("5", onTap: () => adicionarNumero("5")),
                      buildBotao("6", onTap: () => adicionarNumero("6")),
                    ],
                  ),
                  Row(
                    children: [
                      buildBotao("1", onTap: () => adicionarNumero("1")),
                      buildBotao("2", onTap: () => adicionarNumero("2")),
                      buildBotao("3", onTap: () => adicionarNumero("3")),
                    ],
                  ),
                  Row(
                    children: [
                      buildBotao("DEL", onTap: deletarNumero),
                      buildBotao("0", onTap: () => adicionarNumero("0")),
                      buildBotao(
                        "ENTER",
                        cor: AppColors.primary,
                        onTap: confirmar,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
