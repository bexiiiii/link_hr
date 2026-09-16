import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'api.dart';
import 'fmt.dart';

class Attachment {
  Attachment({required this.name, required this.fileName, required this.url, this.size, this.isPrivate = true});

  factory Attachment.fromJson(Json j) => Attachment(
        name: j['name'].toString(),
        fileName: (j['file_name'] ?? j['name']).toString(),
        url: j['file_url']?.toString() ?? '',
        size: j['file_size'] == null ? null : Fmt.number(j['file_size']),
        isPrivate: j['is_private'] == 1 || j['is_private'] == true,
      );

  final String name;
  final String fileName;
  final String url;
  final num? size;
  final bool isPrivate;

  String get meta {
    final dot = fileName.lastIndexOf('.');
    final ext = dot > 0 ? fileName.substring(dot + 1).toUpperCase() : '';
    return [if (size != null) Fmt.bytes(size), if (ext.isNotEmpty) ext].join(' • ');
  }
}

abstract final class Files {
  static Api get _api => Api.instance;

  static Future<List<Attachment>> list(String doctype, String name) async {
    final rows = await _api.list(
      'File',
      fields: ['name', 'file_name', 'file_url', 'file_size', 'is_private'],
      filters: {'attached_to_doctype': doctype, 'attached_to_name': name},
      orderBy: 'creation asc',
      limit: 100,
    );
    return rows.map(Attachment.fromJson).toList();
  }

  /// Lets the user pick a file and attaches it to the document. Null when cancelled.
  static Future<Attachment?> pickAndUpload(String doctype, String name) async {
    final picked = await FilePicker.pickFile();
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final res = await _api.call('hrms.api.upload_base64_file', {
      'content': base64Encode(bytes),
      'filename': picked.name,
      'dt': doctype,
      'dn': name,
    });
    final json = (res as Map).cast<String, dynamic>();
    json['file_size'] ??= bytes.length;
    return Attachment.fromJson(json);
  }

  static Future<void> delete(Attachment a) => _api.call('hrms.api.delete_attachment', {'filename': a.name});

  static Future<void> open(Attachment a) async {
    final bytes = await _api.download(a.url);
    await _openBytes(bytes, a.fileName);
  }

  static Future<void> openPrint(String doctype, String name) async {
    final path = '/api/method/frappe.utils.print_format.download_pdf'
        '?doctype=${Uri.encodeQueryComponent(doctype)}&name=${Uri.encodeQueryComponent(name)}';
    final bytes = await _api.download(path);
    await _openBytes(bytes, '$name.pdf');
  }

  static Future<void> openDataUri(String dataUri, String fileName) async {
    final data = UriData.parse(dataUri);
    await _openBytes(data.contentAsBytes(), fileName);
  }

  static Future<void> _openBytes(List<int> bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      throw ApiException('Не удалось открыть файл: ${result.message}');
    }
  }
}
