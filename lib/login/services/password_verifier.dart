import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PasswordVerifierData {
  final String salt;
  final String hash;

  const PasswordVerifierData({required this.salt, required this.hash});
}

class PasswordVerifier {
  PasswordVerifier._();

  static const int iterations = 60000;
  static const int derivedKeyLength = 32;

  static Future<PasswordVerifierData> create(String password) async {
    final saltBytes = Uint8List.fromList(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final salt = base64UrlEncode(saltBytes);
    final hash = await Isolate.run(
      () => _deriveBase64(password, salt, iterations, derivedKeyLength),
    );
    return PasswordVerifierData(salt: salt, hash: hash);
  }

  static Future<bool> verify({
    required String password,
    required String salt,
    required String expectedHash,
  }) async {
    if (salt.isEmpty || expectedHash.isEmpty) return false;
    final actual = await Isolate.run(
      () => _deriveBase64(password, salt, iterations, derivedKeyLength),
    );
    return _constantTimeEquals(actual, expectedHash);
  }

  static String _deriveBase64(
    String password,
    String encodedSalt,
    int rounds,
    int length,
  ) {
    final passwordBytes = utf8.encode(password);
    final salt = base64Url.decode(encodedSalt);
    final hmac = Hmac(sha256, passwordBytes);
    const hashLength = 32;
    final blockCount = (length / hashLength).ceil();
    final output = BytesBuilder(copy: false);

    for (var block = 1; block <= blockCount; block++) {
      final initial = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..setRange(salt.length, salt.length + 4, [
          (block >> 24) & 0xff,
          (block >> 16) & 0xff,
          (block >> 8) & 0xff,
          block & 0xff,
        ]);
      var u = hmac.convert(initial).bytes;
      final result = Uint8List.fromList(u);
      for (var round = 1; round < rounds; round++) {
        u = hmac.convert(u).bytes;
        for (var i = 0; i < hashLength; i++) {
          result[i] ^= u[i];
        }
      }
      output.add(result);
    }
    return base64UrlEncode(output.takeBytes().sublist(0, length));
  }

  static bool _constantTimeEquals(String a, String b) {
    final left = utf8.encode(a);
    final right = utf8.encode(b);
    var difference = left.length ^ right.length;
    final length = min(left.length, right.length);
    for (var i = 0; i < length; i++) {
      difference |= left[i] ^ right[i];
    }
    return difference == 0;
  }
}
