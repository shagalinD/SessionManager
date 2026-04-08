import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256 encryption for credential secrets. Key material is stored in secure storage.
class EncryptionService {
  static const _keyName = 'session_manager_aes256_key';

  final FlutterSecureStorage _storage;
  enc.Key? _key;
  enc.Encrypter? _encrypter;

  EncryptionService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> init() async {
    var keyB64 = await _storage.read(key: _keyName);
    if (keyB64 == null) {
      final k = enc.Key.fromSecureRandom(32);
      keyB64 = k.base64;
      await _storage.write(key: _keyName, value: keyB64);
    }
    _key = enc.Key.fromBase64(keyB64);
    _encrypter = enc.Encrypter(enc.AES(_key!));
  }

  String encrypt(String plain) {
    final encrypter = _encrypter;
    if (encrypter == null) {
      throw StateError('EncryptionService.init() must be called first');
    }
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(plain, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  String decrypt(String packed) {
    final encrypter = _encrypter;
    if (encrypter == null) {
      throw StateError('EncryptionService.init() must be called first');
    }
    final parts = packed.split(':');
    if (parts.length != 2) {
      throw const FormatException('Invalid ciphertext');
    }
    final iv = enc.IV.fromBase64(parts[0]);
    return encrypter.decrypt64(parts[1], iv: iv);
  }
}
