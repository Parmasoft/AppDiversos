import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'pages/home_page.dart';
import 'services/server_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ServerConfig.carregar();

  runApp(const PedidoApp());
}

class PedidoApp extends StatelessWidget {
  const PedidoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ParmaSoft Pedidos',
      theme: AppTheme.lightTheme,
      home: const HomePage(),
    );
  }
}
