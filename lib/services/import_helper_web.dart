// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'dart:html' as html;

String createBlobUrl(Uint8List bytes) {
  final blob = html.Blob([bytes]);
  return html.Url.createObjectUrlFromBlob(blob);
}
