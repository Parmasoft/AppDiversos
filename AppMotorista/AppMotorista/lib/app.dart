import 'dart:async';

import 'package:flutter/material.dart';

import 'auth/screens/login_screen.dart';
import 'auth/services/session_controller.dart';
import 'core/config/app_config.dart';
import 'core/config/admin_access_store.dart';
import 'core/config/api_endpoint.dart';
import 'core/config/endpoint_change_result.dart';
import 'core/theme/app_theme.dart';
import 'sync/local/outbox_local_store.dart';
import 'sync/services/outbox_sync_controller.dart';
import 'viagens/screens/trips_screen.dart';
import 'viagens/services/trips_service.dart';
import 'viagens/services/trip_state_controller.dart';

class AppMotorista extends StatefulWidget {
  const AppMotorista({
    required this.config,
    required this.sessionController,
    required this.tripsService,
    this.tripStateController,
    required this.outboxSyncController,
    required this.outboxLocalStore,
    required this.onEndpointSave,
    required this.adminAccess,
    super.key,
  });

  final AppConfig config;
  final SessionController sessionController;
  final TripsService tripsService;
  final TripStateController? tripStateController;
  final OutboxSyncController outboxSyncController;
  final OutboxLocalStore outboxLocalStore;
  final Future<EndpointChangeResult> Function(ApiEndpoint endpoint)
  onEndpointSave;
  final AdminAccessStore adminAccess;

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
    unawaited(widget.sessionController.restore());
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
              tripStateController: widget.tripStateController,
              outboxLocalStore: widget.outboxLocalStore,
              syncEvents: widget.config.readOnly
                  ? null
                  : widget.outboxSyncController,
              readOnly: widget.config.readOnly,
            ),
            SessionState.loggedOut => LoginScreen(
              sessionController: widget.sessionController,
              enableMobileBootstrap: widget.config.enableMobileBootstrap,
              endpoint: ApiEndpoint(widget.config.baseUri),
              allowHttp: widget.config.isDevelopment,
              onEndpointSave: widget.onEndpointSave,
              adminAccess: widget.adminAccess,
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
