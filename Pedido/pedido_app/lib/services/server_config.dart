import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static String ip = "192.168.1.238";
  static String porta = "5002";

  static String get baseUrl {
    return "http://$ip:$porta";
  }

  static Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();

    ip = prefs.getString("server_ip") ?? ip;
    porta = prefs.getString("server_porta") ?? porta;
  }

  static Future<void> salvar(String novoIp, String novaPorta) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("server_ip", novoIp);
    await prefs.setString("server_porta", novaPorta);

    ip = novoIp;
    porta = novaPorta;
  }
}
