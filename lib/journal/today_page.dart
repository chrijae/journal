import 'dart:async';

import 'package:flutter/material.dart';

import '../db/journal_repository.dart';
import '../export/export_service.dart';
import '../search/search_page.dart';
import 'archive_page.dart';
import 'entry_page.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final _repo = JournalRepository();
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  bool _loaded = false;
  String? _date;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entry = await _repo.getOrCreateToday();
    if (!mounted) return;
    final prepared = _withSessionTimestamp(entry.content);
    setState(() {
      _controller.text = prepared;
      // Park the cursor at the end (the empty line below the timestamp).
      _controller.selection = TextSelection.collapsed(offset: prepared.length);
      _date = entry.date;
      _loaded = true;
    });
    // Cursor blinks here — request focus on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  static final _timestampPattern = RegExp(r'^\d{2}:\d{2}$');

  String _withSessionTimestamp(String existing) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final stamp = '$hh:$mm';

    // If the entry already ends with a timestamp the user hasn't written
    // under yet, don't stack another one — just ensure a trailing newline
    // so the cursor sits on a fresh line.
    final trimmed = existing.trimRight();
    if (trimmed.isNotEmpty) {
      final lastLine = trimmed.split('\n').last.trim();
      if (_timestampPattern.hasMatch(lastLine)) {
        return trimmed.endsWith('\n') ? trimmed : '$trimmed\n';
      }
    }

    if (existing.isEmpty) return '$stamp\n';
    final separator = existing.endsWith('\n') ? '\n' : '\n\n';
    return '$existing$separator$stamp\n';
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final d = _date;
      if (d != null) _repo.upsert(d, value);
    });
  }

  Future<void> _flush() async {
    _debounce?.cancel();
    final d = _date;
    if (d != null) await _repo.upsert(d, _controller.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Best-effort sync write on dispose; result intentionally not awaited.
    final d = _date;
    if (d != null) _repo.upsert(d, _controller.text);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _formatHeader(String date) {
    // date is YYYY-MM-DD
    final parts = date.split('-');
    if (parts.length != 3) return date;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = int.tryParse(parts[1]) ?? 1;
    final d = int.tryParse(parts[2]) ?? 1;
    return '${months[m - 1]} $d, ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _formatHeader(_date!),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.check),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _flush();
              if (!mounted) return;
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(
                const SnackBar(
                  content: Row(children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Saved'),
                  ]),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              // Capture context-bound objects before the async gap.
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await _flush();
              if (!mounted) return;
              switch (value) {
                case 'search':
                  await navigator.push(MaterialPageRoute(
                    builder: (_) => const SearchPage(),
                  ));
                  break;
                case 'archive':
                  final picked = await navigator.push<String>(
                    MaterialPageRoute(builder: (_) => const ArchivePage()),
                  );
                  if (picked != null && mounted) {
                    await navigator.push(MaterialPageRoute(
                      builder: (_) => EntryPage(date: picked),
                    ));
                  }
                  break;
                case 'export':
                  await ExportService().exportAll(messenger);
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'search', child: Text('Search')),
              PopupMenuItem(value: 'archive', child: Text('Past entries')),
              PopupMenuItem(value: 'export', child: Text('Export')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Write…',
                  ),
                  style: const TextStyle(fontSize: 17, height: 1.5),
                  onChanged: _onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
