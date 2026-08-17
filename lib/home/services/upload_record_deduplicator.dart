class DeduplicatedUploadRecords {
  final List<Map<String, dynamic>> records;
  final int duplicateCount;

  const DeduplicatedUploadRecords({
    required this.records,
    required this.duplicateCount,
  });
}

String _part(Object? value) => value?.toString().trim().toUpperCase() ?? '';

String calibrationUploadLogicalKey(Map<String, dynamic> record) =>
    '${_part(record['seca'])}|${_part(record['cod_metrica'])}';

String supportUploadLogicalKey(Map<String, dynamic> record) =>
    '${_part(record['_support_module'])}|${_part(record['otst'])}|'
    '${_part(record['cod_metrica'])}';

DeduplicatedUploadRecords deduplicateUploadRecords(
  Iterable<Map<String, dynamic>> records,
  String Function(Map<String, dynamic>) logicalKey,
) {
  final unique = <Map<String, dynamic>>[];
  final seen = <String>{};
  var duplicateCount = 0;
  for (final record in records) {
    final key = logicalKey(record);
    if (key.endsWith('|') || !seen.add(key)) {
      if (!key.endsWith('|')) duplicateCount++;
      if (key.endsWith('|')) unique.add(record);
      continue;
    }
    unique.add(record);
  }
  return DeduplicatedUploadRecords(
    records: unique,
    duplicateCount: duplicateCount,
  );
}
