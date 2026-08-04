import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/desktop/desktop_home_page.dart';

class CotacaoOnlineApp extends StatelessWidget {
  const CotacaoOnlineApp({super.key});

  bool get _isDesktop {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cotação Online',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F1C6),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
      ),
      home: DesktopHomePage(),
    );
  }
}
