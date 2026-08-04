import 'cotacao_nova_desktop_page.dart';
import 'package:flutter/material.dart';

class DesktopHomePage extends StatelessWidget {
  const DesktopHomePage({super.key});

  static const String logoParmasoft = 'assets/images/logo.jpeg';
  static const String logoCotacao = 'assets/images/cotacao.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3C4),
              Color(0xFFFFF9E6),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _header(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Column(
                      children: [
                        // ===============================
                        // LINHA 2 → LOGOS (2 COLUNAS)
                        // ===============================
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: const [
                              Expanded(
                                child: _LogoCard(imagePath: logoParmasoft),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _LogoCard(imagePath: logoCotacao),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ===============================
                        // LINHAS DE BAIXO → 3 COLUNAS
                        // ===============================
                        Expanded(
                          flex: 7,
                          child: Row(
                            children: [
                              // NOVA COTAÇÃO
                              Expanded(
                                flex: 5,
                                child: _ActionCard(
                                  title: 'NOVA\nCOTAÇÃO',
                                  icon: Icons.add_circle_outline,
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) =>
                                          const CotacaoNovaDesktopModal(),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),

                              // PRODUTOS / FORNECEDORES
                              Expanded(
                                flex: 4,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: _ActionCard(
                                        title: 'PRODUTOS',
                                        icon: Icons.shopping_bag_outlined,
                                        onPressed: () {
                                          // TODO: abrir produtos
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: _ActionCard(
                                        title: 'FORNECEDORES',
                                        icon: Icons.storefront_outlined,
                                        onPressed: () {
                                          // TODO: abrir fornecedores
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),

                              // LIBERAR / FECHAR
                              Expanded(
                                flex: 4,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: _ActionCard(
                                        title: 'ABRIR VENDEDOR',
                                        icon: Icons.verified_outlined,
                                        onPressed: () {
                                          // TODO: liberar
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: _ActionCard(
                                        title: 'FECHAR',
                                        icon: Icons.exit_to_app_outlined,
                                        onPressed: () =>
                                            Navigator.of(context).maybePop(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _header() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: const Center(
        child: Text(
          'COTAÇÃO DE PREÇOS',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class _LogoCard extends StatelessWidget {
  final String imagePath;
  const _LogoCard({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.80),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_not_supported_outlined, size: 50),
          ),
        ),
      ),
    );
  }
}

/// ✅ CARD FINAL
/// - 100% clicável
/// - 1 ícone apenas
/// - título central (sem "Acessar")
class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onPressed,
      hoverColor: Colors.black.withOpacity(0.03),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.80),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
