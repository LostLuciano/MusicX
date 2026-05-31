// import_helper_web.dart
import 'dart:typed_data';
import 'dart:html' as html;

String createBlobUrl(Uint8List bytes) {
  final blob = html.Blob([bytes]);
  return html.Url.createObjectUrlFromBlob(blob);
}
