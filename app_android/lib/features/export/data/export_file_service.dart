import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/export_file_name.dart';

/// Writes the export to a temporary folder and hands it to the system share
/// sheet. The files are temporary on purpose: they hold real amounts, so they
/// are deleted as soon as the share sheet reports back, before the next
/// export, and when the app starts ([cleanUp]).
class ExportFileService {
  Future<Directory> _folder() async {
    final base = await getTemporaryDirectory();
    final folder = Directory('${base.path}/exports');
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  /// Deletes every leftover export file.
  Future<void> cleanUp() async {
    try {
      final folder = await _folder();
      await for (final entity in folder.list()) {
        if (entity is File &&
            entity.uri.pathSegments.last.startsWith(exportFilePrefix)) {
          await entity.delete();
        }
      }
    } on FileSystemException {
      // Nothing to clean when the folder cannot be read.
    }
  }

  Future<File> write(String name, List<int> bytes) async {
    await cleanUp();
    final file = File('${(await _folder()).path}/$name');
    return file.writeAsBytes(bytes, flush: true);
  }

  /// Opens the share sheet. On Android the result is not reported (the target
  /// app may read the file after this returns), so the file then stays until
  /// the next export or app start; elsewhere it is removed right away.
  Future<void> share(File file, String mimeType, String subject) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: subject,
      ),
    );
    if (result.status != ShareResultStatus.unavailable && file.existsSync()) {
      await file.delete();
    }
  }
}
