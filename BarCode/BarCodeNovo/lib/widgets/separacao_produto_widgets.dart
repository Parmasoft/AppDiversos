import 'package:flutter/material.dart';

BoxDecoration separacaoBoxDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.black12),
    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
  );
}

class SeparacaoCardResumo extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;

  const SeparacaoCardResumo({
    super.key,
    required this.titulo,
    required this.valor,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SeparacaoBotaoLerEtiqueta extends StatelessWidget {
  final bool processando;
  final bool habilitado;
  final VoidCallback onPressed;
  final String textoProcessando;

  const SeparacaoBotaoLerEtiqueta({
    super.key,
    required this.processando,
    required this.habilitado,
    required this.onPressed,
    this.textoProcessando = 'Processando etiqueta...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: separacaoBoxDecoration(),
      child: SizedBox(
        height: 58,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: habilitado && !processando ? onPressed : null,
          icon: processando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.qr_code_scanner, size: 24),
          label: Text(
            processando ? textoProcessando : 'Ler Etiqueta',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class SeparacaoBotaoRodape extends StatelessWidget {
  final IconData icone;
  final String texto;
  final VoidCallback onTap;
  final bool destaque;

  const SeparacaoBotaoRodape({
    super.key,
    required this.icone,
    required this.texto,
    required this.onTap,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icone, size: 21),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: destaque
              ? Colors.green.shade700
              : const Color(0xFFF3F4F6),
          foregroundColor: destaque ? Colors.white : Colors.black87,
          side: BorderSide(
            color: destaque ? Colors.green.shade900 : Colors.black26,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
