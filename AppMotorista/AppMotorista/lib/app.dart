import 'package:flutter/material.dart';

import 'auth/screens/login_screen.dart';
import 'auth/services/session_controller.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'sync/services/outbox_sync_controller.dart';
import 'viagens/screens/trips_screen.dart';
import 'viagens/services/trips_service.dart';

class AppMotorista extends StatefulWidget {
  const AppMotorista({
    required this.config,
    required this.sessionController,
    required this.tripsService,
    required this.outboxSyncController,
    super.key,
  });

  final AppConfig config;
  final SessionController sessionController;
  final TripsService tripsService;
  final OutboxSyncController outboxSyncController;

  @override
  State<AppMotorista> createState() => _AppMotoristaState();
}

class _AppMotoristaState extends State<AppMotorista>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.config.readOnly) {
      widget.outboxSyncController.start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.config.readOnly && state == AppLifecycleState.resumed) {
      widget.outboxSyncController.appResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.outboxSyncController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Motorista',
      debugShowCheckedModeBanner: widget.config.isDevelopment,
      theme: AppTheme.light(),
      home: ListenableBuilder(
        listenable: widget.sessionController,
        builder: (context, _) {
          return switch (widget.sessionController.state) {
            SessionState.bootstrapping => const _OpeningScreen(),
            SessionState.authenticated => TripsScreen(
              sessionController: widget.sessionController,
              tripsService: widget.tripsService,
              syncEvents: widget.config.readOnly
                  ? null
                  : widget.outboxSyncController,
              readOnly: widget.config.readOnly,
            ),
            SessionState.loggedOut => LoginScreen(
              sessionController: widget.sessionController,
              enableMobileBootstrap:
                  widget.config.enableMobileBootstrap,
            ),
          };
        },
      ),
    );
  }
}

class _OpeningScreen extends StatelessWidget {
  const _OpeningScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping_outlined, size: 64),
              SizedBox(height: 24),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Abrindo suas viagens…'),
            ],
          ),
        ),
      ),
    );
  }
}
