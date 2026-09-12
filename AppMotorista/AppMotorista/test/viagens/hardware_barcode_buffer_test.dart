import 'package:app_motorista/viagens/services/hardware_barcode_buffer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leitor HID acumula caracteres e envia somente no ENTER', () {
    final buffer = HardwareBarcodeBuffer();

    expect(buffer.handle(_character(LogicalKeyboardKey.keyC, 'C')), isNull);
    expect(buffer.handle(_character(LogicalKeyboardKey.digit1, '1')), isNull);
    expect(buffer.handle(_character(LogicalKeyboardKey.digit2, '2')), isNull);
    expect(buffer.current, 'C12');

    expect(buffer.handle(_enter()), 'C12');
    expect(buffer.current, isEmpty);
  });

  test('ENTER vazio não cria leitura e backspace corrige o buffer', () {
    final buffer = HardwareBarcodeBuffer();

    expect(buffer.handle(_enter()), isNull);
    buffer.handle(_character(LogicalKeyboardKey.keyR, 'R'));
    buffer.handle(_character(LogicalKeyboardKey.digit1, '1'));
    buffer.handle(_backspace());

    expect(buffer.handle(_numpadEnter()), 'R');
  });

  test('key up não duplica caracteres enviados pelo HID', () {
    final buffer = HardwareBarcodeBuffer();

    buffer.handle(_character(LogicalKeyboardKey.keyC, 'C'));
    buffer.handle(
      KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.keyC,
        logicalKey: LogicalKeyboardKey.keyC,
        timeStamp: Duration.zero,
      ),
    );

    expect(buffer.handle(_enter()), 'C');
  });
}

KeyDownEvent _character(LogicalKeyboardKey key, String character) {
  return KeyDownEvent(
    physicalKey: _physicalKey(key),
    logicalKey: key,
    character: character,
    timeStamp: Duration.zero,
  );
}

KeyDownEvent _enter() {
  return KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.enter,
    logicalKey: LogicalKeyboardKey.enter,
    timeStamp: Duration.zero,
  );
}

KeyDownEvent _numpadEnter() {
  return KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.numpadEnter,
    logicalKey: LogicalKeyboardKey.numpadEnter,
    timeStamp: Duration.zero,
  );
}

KeyDownEvent _backspace() {
  return KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.backspace,
    logicalKey: LogicalKeyboardKey.backspace,
    timeStamp: Duration.zero,
  );
}

PhysicalKeyboardKey _physicalKey(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.keyC) return PhysicalKeyboardKey.keyC;
  if (key == LogicalKeyboardKey.keyR) return PhysicalKeyboardKey.keyR;
  if (key == LogicalKeyboardKey.digit1) return PhysicalKeyboardKey.digit1;
  if (key == LogicalKeyboardKey.digit2) return PhysicalKeyboardKey.digit2;
  throw ArgumentError.value(key);
}
