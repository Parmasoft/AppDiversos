import 'package:app_motorista/auth/screens/login_screen.dart';
import 'package:app_motorista/auth/services/session_controller.dart';
import 'package:app_motorista/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
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
        home: LoginScreen(sessionController: controller),
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
}
