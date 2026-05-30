import 'dart:async';

import 'package:flutter/material.dart';

import '../db/journal_repository.dart';
import '../journal/entry_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _repo = JournalRepository();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SearchHit> _results = const [];
  String _activeQuery = '';
  bool _searching = false;

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => _run(value));
  }

  Future<void> _run(String q) async {
    setState(() {
      _searching = true;
      _activeQuery = q;
    });
    final results = await _repo.search(q);
    if (!mounted) return;
    if (q != _activeQuery) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search your journal…',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_activeQuery.trim().isEmpty) {
      return const Center(child: Text('Type to search across all entries.'));
    }
    if (_searching && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return const Center(child: Text('No matches.'));
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final hit = _results[i];
        return ListTile(
          title: Text(hit.date),
          subtitle: Text(hit.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EntryPage(date: hit.date),
            ));
            // Re-run the query so edits made in EntryPage are reflected.
            if (mounted && _activeQuery.trim().isNotEmpty) {
              _run(_activeQuery);
            }
          },
        );
      },
    );
  }
}
