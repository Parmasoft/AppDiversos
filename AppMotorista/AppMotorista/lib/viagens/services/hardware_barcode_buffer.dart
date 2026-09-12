import 'package:flutter/services.dart';

class HardwareBarcodeBuffer {
  final StringBuffer _buffer = StringBuffer();

  String get current => _buffer.toString();

  String? handle(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return take();
    }
    if (key == LogicalKeyboardKey.backspace) {
      _removeLastCharacter();
      return null;
    }

    final character = event.character;
    if (character == null || !_isPrintable(character)) return null;
    _buffer.write(character);
    return null;
  }

  String? take() {
    final code = current.trim();
    clear();
    return code.isEmpty ? null : code;
  }

  void clear() => _buffer.clear();

  bool _isPrintable(String value) {
    return value.runes.every((rune) => rune >= 32 && rune != 127);
  }

  void _removeLastCharacter() {
    final runes = current.runes.toList();
    if (runes.isEmpty) return;
    runes.removeLast();
    clear();
    _buffer.write(String.fromCharCodes(runes));
  }
}
