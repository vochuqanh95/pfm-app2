import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class FileShareService {
  const FileShareService();

  Future<void> openFile(File file) async {
    await OpenFilex.open(file.path);
  }

  Future<void> shareFile(
    File file, {
    String? subject,
    String? text,
    String? mimeType,
  }) async {
    final xFile = XFile(
      file.path,
      mimeType: mimeType,
      name: file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : null,
    );
    await Share.shareXFiles(
      [xFile],
      subject: subject,
      text: text,
    );
  }
}
