import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class PedidoPage extends StatelessWidget {
  final String comanda;

  const PedidoPage({super.key, required this.comanda});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Comanda $comanda",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Center(
        child: Text(
          "Pedido da comanda $comanda",
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
