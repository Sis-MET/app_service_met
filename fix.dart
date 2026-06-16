import 'dart:io';

void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (var file in files) {
    var content = file.readAsStringSync();
    var newContent = content;

    // Replace Icon() with FaIcon()
    newContent = newContent.replaceAll(
        'Icon(FontAwesomeIcons.', 'FaIcon(FontAwesomeIcons.');

    // Replace IconData icon = ... with var icon = ...
    newContent = newContent.replaceAll('final IconData icon = isCalibracion',
        'final var icon = isCalibracion');
    // Dart doesn't allow 'final var', so we should use 'final icon = isCalibracion'
    newContent = newContent.replaceAll(
        'final IconData icon = isCalibracion', 'final icon = isCalibracion');

    if (content != newContent) {
      file.writeAsStringSync(newContent);
      print('Updated ${file.path}');
    }
  }
}
