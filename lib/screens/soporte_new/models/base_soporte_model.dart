import 'dart:io';

abstract class BaseSoporteModel {
  String get sessionId;
  String get codMetrica;
  Map<String, List<File>> get fieldPhotos;

  Map<String, dynamic> toMap();
  void addPhoto(String field, File photo);
  void removePhoto(String field, int index);
  void clearPhotos(String field);
}
