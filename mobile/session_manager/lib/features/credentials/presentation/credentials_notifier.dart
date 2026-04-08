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

  String? get pendingSessionId => _pendingSessionId;

  void setSessionFromQr(String sessionId) {
    _pendingSessionId = sessionId;
    notifyListeners();
  }

  void clearSession() {
    _pendingSessionId = null;
    notifyListeners();
  }
}
