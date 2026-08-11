import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/login/models/user_model.dart';

void main() {
  test('interpreta el usuario devuelto por la API Node.js', () {
    final user = UserModel.fromMap(const {
      'usuario': 'tecnico',
      'nombre1': 'Ana',
      'apellido1': 'Pérez',
      'apellido2': 'Rojas',
      'tituloAbr': 'Ing.',
      'estado': 'ACTIVO',
      'accesoApp': '1',
    });

    expect(user.fullName, 'Ing. Ana Pérez Rojas');
    expect(user.isActive, isTrue);
    expect(user.accesoApp, '1');
    expect(user.isSelectable, isTrue);
  });

  test('interpreta los metadatos del acceso guardado', () {
    final user = UserModel.fromMap(const {
      'usuario': 'tecnico',
      'estado': 'INACTIVO',
      'acceso_app': '0',
      'fecha_guardado': '2026-08-10T08:00:00.000',
      'last_verified_at': '2026-08-11T09:00:00.000',
    });

    expect(user.savedAt, DateTime(2026, 8, 10, 8));
    expect(user.lastVerifiedAt, DateTime(2026, 8, 11, 9));
    expect(user.isSelectable, isFalse);
  });
}
