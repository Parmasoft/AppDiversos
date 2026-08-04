import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static String ip = "192.168.1.238";
  static String porta = "5000";
  static String ecfId = "";

  static String get baseUrl {
    return "http://$ip:$porta";
  }

  static int get ecfIdInt {
    return int.tryParse(ecfId) ?? 0;
  }

  static bool get ecfConfigurado {
    return ecfIdInt > 0;
  }

  static Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();

    ip = prefs.getString("server_ip") ?? ip;
    porta = prefs.getString("server_porta") ?? porta;
    ecfId = prefs.getString("ecf_id") ?? "";
  }

  static Future<void> salvar(
    String novoIp,
    String novaPorta,
    String novoEcfId,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("server_ip", novoIp);
    await prefs.setString("server_porta", novaPorta);
    await prefs.setString("ecf_id", novoEcfId);

    ip = novoIp;
    porta = novaPorta;
    ecfId = novoEcfId;
  }
}
