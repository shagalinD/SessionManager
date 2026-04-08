import 'credential.dart';

abstract class CredentialsRepository {
  Future<List<Credential>> listWithoutPasswords();

  Future<Credential?> getDecryptedById(String id);

  Future<void> upsert({
    required String url,
    required String login,
    required String password,
    String? id,
  });

  Future<void> delete(String id);
}
