import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/encryption_service.dart';
import '../domain/credential.dart';
import '../domain/credentials_repository.dart';

class CredentialsRepositoryImpl implements CredentialsRepository {
  CredentialsRepositoryImpl({
    required EncryptionService encryption,
    FlutterSecureStorage? storage,
  }) : _encryption = encryption,
       _storage = storage ?? const FlutterSecureStorage();

  static const _blobKey = 'credentials_v1';

  final EncryptionService _encryption;
  final FlutterSecureStorage _storage;
  final _uuid = const Uuid();

  Future<List<Map<String, dynamic>>> _readRaw() async {
    final raw = await _storage.read(key: _blobKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> _writeRaw(List<Map<String, dynamic>> rows) async {
    await _storage.write(key: _blobKey, value: jsonEncode(rows));
  }

  @override
  Future<List<Credential>> listWithoutPasswords() async {
    final rows = await _readRaw();
    return rows
        .map(
          (e) => Credential(
            id: e['id'] as String,
            url: e['url'] as String,
            login: e['login'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<Credential?> getDecryptedById(String id) async {
    final rows = await _readRaw();
    for (final e in rows) {
      if (e['id'] as String == id) {
        final encPwd = e['password'] as String;
        final plain = _encryption.decrypt(encPwd);
        return Credential(
          id: id,
          url: e['url'] as String,
          login: e['login'] as String,
          password: plain,
        );
      }
    }
    return null;
  }

  @override
  Future<void> upsert({
    required String url,
    required String login,
    required String password,
    String? id,
  }) async {
    final rows = await _readRaw();
    final encrypted = _encryption.encrypt(password);
    final effectiveId = id ?? _uuid.v4();
    final idx = id != null ? rows.indexWhere((e) => e['id'] == id) : -1;
    final row = {
      'id': effectiveId,
      'url': url,
      'login': login,
      'password': encrypted,
    };
    if (idx >= 0) {
      rows[idx] = row;
    } else {
      rows.add(row);
    }
    await _writeRaw(rows);
  }

  @override
  Future<void> delete(String id) async {
    final rows = await _readRaw();
    rows.removeWhere((e) => e['id'] == id);
    await _writeRaw(rows);
  }
}
