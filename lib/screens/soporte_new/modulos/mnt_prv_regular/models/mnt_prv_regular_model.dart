import 'dart:io';

import 'package:service_met/screens/soporte_new/models/base_soporte_model.dart';

class MntPrvRegularModel extends BaseSoporteModel {
  @override
  final String sessionId;
  @override
  final String codMetrica;
  @override
  Map<String, List<File>> fieldPhotos = {};

  MntPrvRegularModel({
    required this.sessionId,
    required this.codMetrica,
    Map<String, List<File>>? fieldPhotos,
  }) : fieldPhotos = fieldPhotos ?? {};

  @override
  Map<String, dynamic> toMap() => {
        'session_id': sessionId,
        'cod_metrica': codMetrica,
      };

  @override
  void addPhoto(String field, File photo) {
    fieldPhotos.putIfAbsent(field, () => []).add(photo);
  }

  @override
  void removePhoto(String field, int index) {
    if (fieldPhotos.containsKey(field) && index < fieldPhotos[field]!.length) {
      fieldPhotos[field]!.removeAt(index);
    }
  }

  @override
  void clearPhotos(String field) {
    fieldPhotos.remove(field);
  }
}
