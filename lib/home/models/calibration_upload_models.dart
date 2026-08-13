class UploadValidationIssue {
  final String? column;
  final dynamic value;
  final String code;
  final String message;
  final String? expected;

  UploadValidationIssue.fromJson(Map<String, dynamic> json)
      : column = json['column']?.toString(),
        value = json['value'],
        code = json['code']?.toString() ?? '',
        message = json['message']?.toString() ?? 'Dato inválido',
        expected = json['expected']?.toString();
}

class UploadRecordValidation {
  final int index;
  final String? codigoRegistro;
  final String? seca;
  final String? codMetrica;
  final bool valid;
  final List<UploadValidationIssue> errors;

  UploadRecordValidation.fromJson(Map<String, dynamic> json)
      : index = json['index'] as int? ?? 0,
        codigoRegistro = json['codigoRegistro']?.toString(),
        seca = json['seca']?.toString(),
        codMetrica = json['codMetrica']?.toString(),
        valid = json['valid'] == true,
        errors = (json['errors'] as List<dynamic>? ?? const [])
            .map((item) => UploadValidationIssue.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
}

class CalibrationValidationResult {
  final int total;
  final int validCount;
  final int invalidCount;
  final List<UploadRecordValidation> records;

  CalibrationValidationResult.fromJson(Map<String, dynamic> json)
      : total = json['total'] as int? ?? 0,
        validCount = json['validCount'] as int? ?? 0,
        invalidCount = json['invalidCount'] as int? ?? 0,
        records = (json['records'] as List<dynamic>? ?? const [])
            .map((item) => UploadRecordValidation.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
}

class UploadedCalibrationRecord {
  final int index;
  final String codigoRegistro;
  final int serverN;
  final String? sessionId;
  final bool isNewScale;

  UploadedCalibrationRecord.fromJson(Map<String, dynamic> json)
      : index = json['index'] as int? ?? 0,
        codigoRegistro = json['codigoRegistro']?.toString() ?? '',
        serverN = json['n'] as int? ?? 0,
        sessionId = json['sessionId']?.toString(),
        isNewScale = json['isNewScale'] == true;
}

class CalibrationUploadResult {
  final String message;
  final List<UploadedCalibrationRecord> uploaded;
  final List<UploadRecordValidation> invalidRecords;

  int get newScaleCount => uploaded.where((record) => record.isNewScale).length;

  CalibrationUploadResult.fromJson(Map<String, dynamic> json)
      : message = json['message']?.toString() ?? '',
        uploaded = (json['uploaded'] as List<dynamic>? ?? const [])
            .map((item) => UploadedCalibrationRecord.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
        invalidRecords = (json['invalidRecords'] as List<dynamic>? ?? const [])
            .map((item) => UploadRecordValidation.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
}
