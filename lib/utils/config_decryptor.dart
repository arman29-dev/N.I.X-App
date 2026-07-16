import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

Uint8List _deriveKey(String secret) {
  final hmac = HMac(SHA256Digest(), 64);
  hmac.init(KeyParameter(utf8.encode(secret)));
  final salt = utf8.encode('nix-desktop-registration');
  hmac.update(salt, 0, salt.length);
  final key = Uint8List(32);
  hmac.doFinal(key, 0);
  return key;
}

Map<String, String>? decryptConfigFile(
  String encryptedJson,
  String secretKey,
) {
  try {
    final blob = jsonDecode(encryptedJson) as Map<String, dynamic>;
    final key = _deriveKey(secretKey);
    final ct = base64Decode(blob['data'] as String);
    final iv = base64Decode(blob['iv'] as String);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));

    final out = Uint8List(cipher.getOutputSize(ct.length));
    final off1 = cipher.processBytes(ct, 0, ct.length, out, 0);
    final off2 = cipher.doFinal(out, off1);
    final result = utf8.decode(out.sublist(0, off1 + off2));
    final data = jsonDecode(result) as Map<String, dynamic>;

    return {
      'device_uid': data['device_uid'] as String,
      'user_access_token': data['user_access_token'] as String,
      'access_token_uid': data['access_token_uid'] as String,
      'owner_uid': data['owner_uid'] as String,
    };
  } catch (e) {
    return null;
  }
}
