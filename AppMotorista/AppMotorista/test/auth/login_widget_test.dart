import 'package:app_motorista/auth/screens/login_screen.dart';
import 'package:app_motorista/auth/services/session_controller.dart';
import 'package:app_motorista/core/config/admin_access_store.dart';
import 'package:app_motorista/core/config/api_endpoint.dart';
import 'package:app_motorista/core/config/endpoint_change_result.dart';
import 'package:app_motorista/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('login mostra somente credenciais e ação principal', (
    tester,
  ) async {
    final controller = SessionController(
      repository: FakeAuthGateway(),
      storage: MemorySessionStorage(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LoginScreen(
          sessionController: controller,
          endpoint: const ApiEndpoint('https://motorista.parmatech.com.br'),
          allowHttp: false,
          adminAccess: AdminAccessStore(),
          onEndpointSave: (_) async =>
              const EndpointChangeResult.saved('salvo'),
        ),
      ),
    );

    expect(find.text('App Motorista'), findsOneWidget);
    expect(find.text('Usuário'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ENTRAR'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'ENTRAR'));
    await tester.pump();
    expect(find.text('Informe seu usuário.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
  });

  testWidgets('menu administrativo exige senha antes de abrir configurações', (
    tester,
  ) async {
    final controller = SessionController(
      repository: FakeAuthGateway(),
      storage: MemorySessionStorage(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LoginScreen(
          sessionController: controller,
          endpoint: const ApiEndpoint('https://motorista.parmatech.com.br'),
          allowHttp: false,
          adminAccess: AdminAccessStore(),
          onEndpointSave: (_) async =>
              const EndpointChangeResult.saved('salvo'),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '123',
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Configurações'), findsOneWidget);
    expect(find.byKey(const Key('api-address-field')), findsOneWidget);
  });
}
