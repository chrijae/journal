import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/journal_repository.dart';

class ExportService {
  final _repo = JournalRepository();

  Future<void> exportAll(ScaffoldMessengerState messenger) async {
    try {
      final entries = await _repo.listAll();
      if (entries.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Nothing to export yet.')),
        );
        return;
      }

      final tmp = await getTemporaryDirectory();
      final zipPath = p.join(
        tmp.path,
        'journal-${DateTime.now().millisecondsSinceEpoch}.zip',
      );

      final archive = Archive();
      for (final e in entries) {
        final filename = '${e.date}.md';
        final bytes = utf8.encode(_markdownFor(e));
        archive.addFile(ArchiveFile(filename, bytes.length, bytes));
      }

      final encoded = ZipEncoder().encode(archive);
      if (encoded == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Export failed.')),
        );
        return;
      }
      final file = File(zipPath);
      await file.writeAsBytes(encoded);

      await Share.shareXFiles(
        [XFile(zipPath, mimeType: 'application/zip')],
        subject: 'My journal export',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  String _markdownFor(Entry e) {
    return '# ${e.date}\n\n${e.content}\n';
  }
}
