import 'dart:async';

import 'package:flutter/material.dart';

import '../db/journal_repository.dart';

class EntryPage extends StatefulWidget {
  final String date;
  const EntryPage({super.key, required this.date});

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  final _repo = JournalRepository();
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entry = await _repo.getByDate(widget.date);
    if (!mounted) return;
    setState(() {
      _controller.text = entry?.content ?? '';
      _loaded = true;
    });
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _repo.upsert(widget.date, value);
    });
  }

  // See today_page._clearComposing — same Hangul IME tap-selection workaround.
  void _clearComposing() {
    final v = _controller.value;
    if (v.composing.isValid && !v.composing.isCollapsed) {
      _controller.value = v.copyWith(composing: TextRange.empty);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _repo.upsert(widget.date, _controller.text);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.date),
      ),
      body: !_loaded
          ? const SizedBox.shrink()
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Empty entry',
                  ),
                  style: const TextStyle(fontSize: 17, height: 1.5),
                  onChanged: _onChanged,
                  onTap: _clearComposing,
                ),
              ),
            ),
    );
  }
}
