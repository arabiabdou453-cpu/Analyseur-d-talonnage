/// Accès aux fichiers : sélection (lecture seule, taille bornée) et partage.
/// Aucun envoi réseau : le partage passe par la feuille système de l'appareil.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../core/engine.dart' show CoreError;

class PickedFile {
  const PickedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;

  bool get isPdf => name.toLowerCase().endsWith('.pdf');

  /// Texte UTF-8 (BOM et caractères invalides tolérés).
  String get text => utf8.decode(bytes, allowMalformed: true);
}

/// Ouvre le sélecteur de fichiers ; null si l'utilisateur annule.
Future<PickedFile?> pickFile(List<String> extensions, {required int maxBytes}) async {
  final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: extensions);
  if (f == null) return null;
  final size = await f.length();
  if (size != null && size > maxBytes) throw const CoreError('tooLarge');
  final bytes = await f.readAsBytes();
  if (bytes.length > maxBytes) throw const CoreError('tooLarge');
  return PickedFile(f.name, bytes);
}

Future<void> shareBytes(Uint8List bytes, String name, String mime) async {
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(bytes, mimeType: mime, name: name)],
    fileNameOverrides: [name],
  ));
}

/// Nom de fichier sûr dérivé du certificat ou de l'instrument.
String fileStem(String certificate, String instrument) {
  final base = (certificate.isNotEmpty ? certificate : (instrument.isNotEmpty ? instrument : 'etalonnage'))
      .replaceAll(RegExp(r'[^\w\-]+'), '_');
  final s = base.length > 40 ? base.substring(0, 40) : base;
  return s.isEmpty ? 'etalonnage' : s;
}
