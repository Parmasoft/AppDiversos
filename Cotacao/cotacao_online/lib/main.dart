import 'features/desktop/verificar_api_page.dart';
import 'package:flutter/material.dart';
import 'features/desktop/cotacoes_list_desktop_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CotacaoOnlineApp());
}

class CotacaoOnlineApp extends StatelessWidget {
  const CotacaoOnlineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cotação Online',
      theme: ThemeData(
        useMaterial3: true,
      ),
      //home: const CotacoesListDesktopPage(),
      home: VerificarApiPage(
        onSuccess: const CotacoesListDesktopPage(),
      ),
    );
  }
}
