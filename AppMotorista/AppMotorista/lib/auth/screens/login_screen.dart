import 'package:flutter/material.dart';

import '../services/session_controller.dart';
import '../models/mobile_bootstrap.dart';
import '../../viagens/screens/camera_scanner_screen.dart';
import '../../core/config/admin_access_store.dart';
import '../../core/config/api_endpoint.dart';
import '../../core/config/endpoint_change_result.dart';
import '../../core/widgets/admin_settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.sessionController,
    required this.endpoint,
    required this.allowHttp,
    required this.onEndpointSave,
    required this.adminAccess,
    this.enableMobileBootstrap = false,
    super.key,
  });

  final SessionController sessionController;
  final ApiEndpoint endpoint;
  final bool allowHttp;
  final Future<EndpointChangeResult> Function(ApiEndpoint endpoint)
  onEndpointSave;
  final AdminAccessStore adminAccess;
  final bool enableMobileBootstrap;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _hidePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await widget.sessionController.login(_username.text, _password.text);
  }

  Future<void> _bootstrap() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const CameraScannerScreen(preserveCase: true),
      ),
    );
    if (!mounted || code == null) return;
    try {
      final bootstrap = MobileBootstrap.parse(
        code,
        now: DateTime.now().toUtc(),
      );
      await widget.sessionController.importMobileBootstrap(bootstrap);
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR de homologacao invalido ou expirado.'),
          ),
        );
      }
    }
  }

  Future<void> _openSettings() async {
    final password = TextEditingController();
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acesso administrativo'),
        content: TextField(
          controller: password,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Senha administrativa'),
          onSubmitted: (_) => Navigator.of(context).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    final verified =
        allowed == true && await widget.adminAccess.verify(password.text);
    if (!mounted) {
      password.dispose();
      return;
    }
    if (!verified) {
      password.dispose();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha administrativa inválida.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminSettingsScreen(
          endpoint: widget.endpoint,
          allowHttp: widget.allowHttp,
          onSave: widget.onEndpointSave,
          adminAccess: widget.adminAccess,
        ),
      ),
    );
    password.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.sessionController;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.local_shipping_rounded,
                          size: 76,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'App Motorista',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Entre para ver suas viagens',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 36),
                        TextFormField(
                          controller: _username,
                          enabled: !controller.busy,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            labelText: 'Usuário',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          onFieldSubmitted: (_) =>
                              _passwordFocus.requestFocus(),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Informe seu usuário.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          focusNode: _passwordFocus,
                          enabled: !controller.busy,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _hidePassword
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              onPressed: () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Informe sua senha.'
                              : null,
                        ),
                        if (controller.loginError != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              controller.loginError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: controller.busy ? null : _submit,
                          child: controller.busy
                              ? const SizedBox.square(
                                  dimension: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text('ENTRAR'),
                        ),
                        if (widget.enableMobileBootstrap) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: controller.busy ? null : _bootstrap,
                            icon: const Icon(Icons.qr_code_scanner_outlined),
                            label: const Text('LER QR DE HOMOLOGACAO'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                tooltip: 'Menu',
                onSelected: (value) {
                  if (value == 'settings') _openSettings();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'settings',
                    child: Text('Configurações'),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
