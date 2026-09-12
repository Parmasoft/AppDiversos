import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../storage/session_storage.dart';
import '../models/session.dart';
import '../models/mobile_bootstrap.dart';
import '../repositories/auth_repository.dart';

enum SessionState { bootstrapping, loggedOut, authenticated }

class SessionController extends ChangeNotifier {
  SessionController({
    required AuthGateway repository,
    required SessionStorage storage,
    DateTime Function()? now,
  }) : _repository = repository,
       _storage = storage,
       _now = now ?? DateTime.now;

  final AuthGateway _repository;
  final SessionStorage _storage;
  final DateTime Function() _now;

  SessionState _state = SessionState.bootstrapping;
  DriverSession? _session;
  bool _busy = false;
  String? _loginError;
  Future<DriverSession>? _refreshing;

  SessionState get state => _state;
  DriverSession? get session => _session;
  bool get busy => _busy;
  String? get loginError => _loginError;

  Future<void> restore() async {
    try {
      _session = await _storage.read();
      if (_session == null) {
        _state = SessionState.loggedOut;
      } else if (_accessNeedsRefresh(_session!)) {
        try {
          await _renew();
        } catch (error) {
          if (_isCommunicationFailure(error) && _session != null) {
            _state = SessionState.authenticated;
          } else if (_session != null) {
            await _clearSession();
          }
        }
      } else {
        _state = SessionState.authenticated;
      }
    } catch (_) {
      await _clearSession();
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    if (_busy) return false;
    _busy = true;
    _loginError = null;
    notifyListeners();
    try {
      final session = await _repository.login(
        username: username,
        password: password,
        device: 'App Motorista Flutter',
      );
      await _setSession(session);
      return true;
    } on ApiException catch (error) {
      _loginError = error.statusCode == 401
          ? 'Usuário ou senha inválidos.'
          : error.message;
      return false;
    } on FormatException {
      _loginError = 'O servidor enviou uma resposta inválida.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> importMobileBootstrap(MobileBootstrap bootstrap) {
    return _setSession(bootstrap.toSession());
  }

  Future<T> authorized<T>(
    Future<T> Function(String accessToken) request,
  ) async {
    var current = _session;
    if (current == null) {
      throw const ApiException(
        'Sua sessão expirou. Entre novamente.',
        statusCode: 401,
      );
    }
    if (_accessNeedsRefresh(current)) current = await _renew();
    try {
      return await request(current.accessToken);
    } on ApiException catch (error) {
      if (!error.isUnauthorized) rethrow;
      try {
        current = await _renew();
      } catch (error) {
        if (_isCommunicationFailure(error)) rethrow;
        if (_session != null) await logout();
        throw const ApiException(
          'Sua sessão expirou. Entre novamente.',
          statusCode: 401,
        );
      }
      try {
        return await request(current.accessToken);
      } on ApiException catch (secondError) {
        if (!secondError.isUnauthorized) rethrow;
        await logout();
        throw const ApiException(
          'Sua sessão expirou. Entre novamente.',
          statusCode: 401,
        );
      }
    }
  }

  Future<void> logout() async {
    await _clearSession();
    notifyListeners();
  }

  Future<DriverSession> _renew() {
    final active = _refreshing;
    if (active != null) return active;
    final future = _performRenew();
    _refreshing = future;
    future.then<void>(
      (_) => _refreshing = null,
      onError: (_) => _refreshing = null,
    );
    return future;
  }

  Future<DriverSession> _performRenew() async {
    final current = _session;
    if (current == null) {
      throw const ApiException('Sessão inexistente.', statusCode: 401);
    }
    try {
      final renewed = await _repository.renew(current.refreshToken);
      final session = renewed.driver.name.trim().isEmpty
          ? DriverSession(
              accessToken: renewed.accessToken,
              refreshToken: renewed.refreshToken,
              accessExpiresAt: renewed.accessExpiresAt,
              driver: current.driver,
            )
          : renewed;
      await _setSession(session);
      return session;
    } catch (error) {
      if (!_isCommunicationFailure(error)) {
        await _clearSession();
        notifyListeners();
      }
      rethrow;
    }
  }

  bool _isCommunicationFailure(Object error) {
    if (error is! ApiException) return false;
    final statusCode = error.statusCode;
    return statusCode == null || statusCode >= 500;
  }

  bool _accessNeedsRefresh(DriverSession value) {
    return !value.accessExpiresAt.isAfter(
      _now().add(const Duration(seconds: 30)),
    );
  }

  Future<void> _setSession(DriverSession value) async {
    _session = value;
    _state = SessionState.authenticated;
    await _storage.write(value);
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _session = null;
    _state = SessionState.loggedOut;
    await _storage.clear();
  }
}
