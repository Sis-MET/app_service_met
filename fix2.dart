import 'dart:io';

void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (var file in files) {
    var content = file.readAsStringSync();
    var newContent = content;

    newContent = newContent.replaceAll('final var icon =', 'final icon =');
    newContent = newContent
        .replaceAll('Icon(icon,', 'icon is IconData ? Icon(icon,')
        .replaceAll(
            'icon is IconData ? Icon(icon, color: Colors.white, size: 20)',
            'icon is IconData ? Icon(icon, color: Colors.white, size: 20) : FaIcon(icon, color: Colors.white, size: 20)');

    // To be safer, let's just do targeted replace for Icon(icon

    if (content != newContent) {
      file.writeAsStringSync(newContent);
      print('Updated ${file.path}');
    }
  }
}
