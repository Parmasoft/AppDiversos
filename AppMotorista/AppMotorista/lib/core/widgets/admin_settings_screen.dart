import 'package:flutter/material.dart';

import '../config/admin_access_store.dart';
import '../config/api_endpoint.dart';
import '../config/endpoint_change_result.dart';
import '../network/api_health_checker.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({
    required this.endpoint,
    required this.allowHttp,
    required this.onSave,
    required this.adminAccess,
    super.key,
    ApiHealthChecker? healthChecker,
  }) : _healthChecker = healthChecker;

  final ApiEndpoint endpoint;
  final bool allowHttp;
  final Future<EndpointChangeResult> Function(ApiEndpoint endpoint) onSave;
  final AdminAccessStore adminAccess;
  final ApiHealthChecker? _healthChecker;

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late final TextEditingController _address = TextEditingController(
    text: widget.endpoint.baseUri,
  );
  late final ApiHealthChecker _healthChecker =
      widget._healthChecker ?? ApiHealthChecker();
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  ApiEndpoint? _endpointOrShowError() {
    try {
      return ApiEndpoint.parse(_address.text, allowHttp: widget.allowHttp);
    } on FormatException catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return null;
    }
  }

  Future<void> _test() async {
    final endpoint = _endpointOrShowError();
    if (endpoint == null) return;
    setState(() => _busy = true);
    final result = await _healthChecker.check(endpoint.baseUri);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.ok
            ? Colors.green.shade700
            : Colors.red.shade700,
      ),
    );
  }

  Future<void> _save() async {
    final endpoint = _endpointOrShowError();
    if (endpoint == null) return;
    setState(() => _busy = true);
    final result = await widget.onSave(endpoint);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.saved) Navigator.of(context).pop();
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final replacement = TextEditingController();
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar senha administrativa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha atual'),
            ),
            TextField(
              controller: replacement,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nova senha (mínimo 4 caracteres)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (changed == true) {
      final ok = await widget.adminAccess.changePassword(
        currentPassword: current.text,
        newPassword: replacement.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Senha administrativa atualizada.'
                  : 'Não foi possível alterar a senha.',
            ),
          ),
        );
      }
    }
    current.dispose();
    replacement.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Configurações'),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'password') _changePassword();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'password',
              child: Text('Alterar senha administrativa'),
            ),
          ],
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ambiente: ${widget.allowHttp ? 'desenvolvimento' : 'homologação segura'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('api-address-field'),
              controller: _address,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Endereço da API',
                hintText: 'https://servidor.exemplo',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Em homologação, apenas endereços HTTPS são aceitos.'),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _busy ? null : _test,
              icon: const Icon(Icons.wifi_tethering_outlined),
              label: Text(_busy ? 'AGUARDE...' : 'TESTAR CONEXÃO'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('SALVAR'),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('CANCELAR'),
            ),
          ],
        ),
      ),
    ),
  );
}
