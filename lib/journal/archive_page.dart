import 'package:flutter/material.dart';

import '../db/journal_repository.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  final _repo = JournalRepository();
  late Future<List<Entry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.listAll();
  }

  static final _timestampPattern = RegExp(r'^\d{2}:\d{2}$');

  // Parse content into (time, text) pairs by walking HH:MM lines emitted by
  // today_page's session timestamps. Falls back to a single pair with no time
  // for legacy entries that pre-date that feature.
  List<({String? time, String text})> _segments(String content) {
    final lines = content.split('\n');
    final out = <({String? time, String text})>[];
    String? currentTime;
    final buf = StringBuffer();

    void flush() {
      final text = buf.toString().trim();
      if (text.isNotEmpty || currentTime != null) {
        out.add((time: currentTime, text: text));
      }
      buf.clear();
    }

    for (final line in lines) {
      if (_timestampPattern.hasMatch(line.trim())) {
        flush();
        currentTime = line.trim();
      } else {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(line.trim());
      }
    }
    flush();

    return out.where((s) => s.text.isNotEmpty || s.time != null).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Past entries')),
      body: FutureBuilder<List<Entry>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data!;
          if (entries.isEmpty) {
            return const Center(child: Text('No past entries yet.'));
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = entries[i];
              final segments = _segments(e.content).take(2).toList();
              return _ArchiveTile(
                date: e.date,
                segments: segments,
                onTap: () => Navigator.of(context).pop(e.date),
              );
            },
          );
        },
      ),
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  final String date;
  final List<({String? time, String text})> segments;
  final VoidCallback onTap;

  const _ArchiveTile({
    required this.date,
    required this.segments,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.primary,
    );
    final textStyle = theme.textTheme.bodyMedium;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final s in segments)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(s.time ?? '', style: timeStyle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.text,
                        style: textStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
