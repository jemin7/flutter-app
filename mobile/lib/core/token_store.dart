import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'constants.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// JWT lives in the encrypted secure storage (Keychain / Keystore), never SharedPreferences.
class TokenStore {
  TokenStore();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> read() => _storage.read(key: kTokenKey);

  Future<void> save(String token) => _storage.write(key: kTokenKey, value: token);

  Future<void> clear() => _storage.delete(key: kTokenKey);
}
