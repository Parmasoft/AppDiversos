import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:padaria_app/pages/config_page.dart';
import 'pages/pedidos_pendentes_page.dart';
import 'pages/nova_encomenda_page.dart';
import 'services/api_service.dart';

// para funcionar o windows (estava na roça, lembra?)
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

//Future<void> main() async {
//  WidgetsFlutterBinding.ensureInitialized();
//  await ApiService.init();
//  runApp(const BuscaEANApp());
//}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ SQLite para Desktop (Windows / Linux / macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // ✅ continua exatamente como já estava
  await ApiService.init();

  runApp(const BuscaEANApp());
}

class BuscaEANApp extends StatelessWidget {
  const BuscaEANApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TelaUnica(),
    );
  }
}

// ============================================================================
// LOGO GIRANDO (TELA INICIAL)
// ============================================================================
class LogoGira extends StatefulWidget {
  const LogoGira({super.key});

  @override
  State<LogoGira> createState() => _LogoGiraState();
}

class _LogoGiraState extends State<LogoGira>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        final angle = controller.value * 6.28318;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(-angle),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Image.asset(
          'assets/images/logo.jpeg',
          width: 180,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ============================================================================
// TELA PRINCIPAL (HOME REAL)
// ============================================================================
class TelaUnica extends StatefulWidget {
  const TelaUnica({super.key});

  @override
  State<TelaUnica> createState() => _TelaUnicaState();
}

class _TelaUnicaState extends State<TelaUnica> {
  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,

      // ----------------------------------------------------------------------
      // BOTÕES DE RODAPÉ
      // ----------------------------------------------------------------------
      bottomNavigationBar: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // NOVA ENCOMENDA
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NovaEncomendaPage()),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.add_shopping_cart,
                      color: Colors.black,
                      size: 26,
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Encomenda",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(width: 1, color: Colors.black12),

            // CONFIG
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConfigPage()),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.settings, color: Colors.black, size: 26),
                    SizedBox(height: 4),
                    Text(
                      "Config",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(width: 1, color: Colors.black12),

            // PENDENTES
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PedidosPendentesPage(),
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.list_alt, color: Colors.black54, size: 26),
                    SizedBox(height: 4),
                    Text(
                      "Pendentes",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ----------------------------------------------------------------------
      // CONTEÚDO PRINCIPAL
      // ----------------------------------------------------------------------
      body: Column(
        children: [
          const SizedBox(height: 40),
          const Text(
            "Controle de Encomendas",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 20),

          Container(
            height: altura * 0.30,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF9E3), Color(0xFFF7EFC7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: const Center(child: LogoGira()),
          ),

          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEDEDED), Color(0xFFD9D9D9)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Image.asset('assets/images/padaria.jpg', width: 220),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
