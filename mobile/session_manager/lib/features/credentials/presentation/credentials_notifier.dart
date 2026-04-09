import 'package:flutter/foundation.dart';

import '../domain/credential.dart';
import '../domain/credentials_repository.dart';

class CredentialsNotifier extends ChangeNotifier {
  CredentialsNotifier(this._repository);

  final CredentialsRepository _repository;

  List<Credential> _items = [];
  bool _loading = false;
  String? _error;

  List<Credential> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _repository.listWithoutPasswords();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await load();
  }
}

class SessionFlowNotifier extends ChangeNotifier {
  String? _pendingSessionId;
  /// База URL из QR (схема + хост + порт), без path — для POST на релей (Node server.js).
  Uri? _relayOrigin;

  String? get pendingSessionId => _pendingSessionId;

  Uri? get relayOrigin => _relayOrigin;

  void setSessionFromQr({required String sessionId, required Uri requestUri}) {
    _pendingSessionId = sessionId;
    if (requestUri.hasScheme && requestUri.host.isNotEmpty) {
      _relayOrigin = Uri(
        scheme: requestUri.scheme,
        host: requestUri.host,
        port: requestUri.hasPort ? requestUri.port : null,
      );
    } else {
      _relayOrigin = null;
    }
    notifyListeners();
  }

  void clearSession() {
    _pendingSessionId = null;
    _relayOrigin = null;
    notifyListeners();
  }
}
