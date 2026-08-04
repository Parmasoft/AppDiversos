import 'package:shared_preferences/shared_preferences.dart';

class NumeracaoPedidoService {
  static const _chave = 'ultimo_numero_pedido';

  /// Retorna sempre o próximo número sequencial
  static Future<int> proximoNumero() async {
    final prefs = await SharedPreferences.getInstance();
    final ultimo = prefs.getInt(_chave) ?? 0;
    final proximo = ultimo + 1;
    await prefs.setInt(_chave, proximo);
    return proximo;
  }

  /// (Opcional) consultar último número sem incrementar
  static Future<int> ultimoNumero() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_chave) ?? 0;
  }
}
