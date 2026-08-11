import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/login/services/password_verifier.dart';

void main() {
  test('crea un verificador sin conservar la contraseña', () async {
    const password = 'clave-offline-segura';
    final verifier = await PasswordVerifier.create(password);

    expect(verifier.salt, isNotEmpty);
    expect(verifier.hash, isNotEmpty);
    expect(verifier.hash, isNot(contains(password)));
    expect(
      await PasswordVerifier.verify(
        password: password,
        salt: verifier.salt,
        expectedHash: verifier.hash,
      ),
      isTrue,
    );
    expect(
      await PasswordVerifier.verify(
        password: 'incorrecta',
        salt: verifier.salt,
        expectedHash: verifier.hash,
      ),
      isFalse,
    );
  });
}
