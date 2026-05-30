import 'dart:async';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class Entry {
  final String date;
  final String content;
  final DateTime updatedAt;

  Entry({required this.date, required this.content, required this.updatedAt});

  factory Entry.fromRow(Map<String, Object?> row) => Entry(
        date: row['date'] as String,
        content: row['content'] as String,
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      );
}

class SearchHit {
  final String date;
  final String snippet;
  SearchHit({required this.date, required this.snippet});
}

class JournalRepository {
  // Single shared instance so every screen uses one SQLCipher connection.
  // Multiple connections to the same encrypted file risk SQLITE_BUSY when
  // autosave timers on different pages fire near-simultaneously.
  JournalRepository._();
  static final JournalRepository instance = JournalRepository._();
  factory JournalRepository() => instance;

  static const _dbKeyStorageKey = 'journal_db_key_v1';
  static const _dbFilename = 'journal.db';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Database? _db;
  Future<Database>? _opening;

  Future<Database> _open() {
    return _opening ??= _doOpen();
  }

  Future<Database> _doOpen() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbFilename);
    final key = await _getOrCreateKey();

    _db = await openDatabase(
      path,
      password: key,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            content TEXT NOT NULL DEFAULT '',
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE VIRTUAL TABLE entries_fts USING fts5(
            content,
            content='entries',
            content_rowid='id',
            tokenize='unicode61'
          )
        ''');
        await db.execute('''
          CREATE TRIGGER entries_ai AFTER INSERT ON entries BEGIN
            INSERT INTO entries_fts(rowid, content) VALUES (new.id, new.content);
          END
        ''');
        await db.execute('''
          CREATE TRIGGER entries_ad AFTER DELETE ON entries BEGIN
            INSERT INTO entries_fts(entries_fts, rowid, content)
              VALUES('delete', old.id, old.content);
          END
        ''');
        await db.execute('''
          CREATE TRIGGER entries_au AFTER UPDATE ON entries BEGIN
            INSERT INTO entries_fts(entries_fts, rowid, content)
              VALUES('delete', old.id, old.content);
            INSERT INTO entries_fts(rowid, content) VALUES (new.id, new.content);
          END
        ''');
      },
    );
    return _db!;
  }

  Future<String> _getOrCreateKey() async {
    final existing = await _secureStorage.read(key: _dbKeyStorageKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await _secureStorage.write(key: _dbKeyStorageKey, value: hex);
    return hex;
  }

  static String dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<Entry> getOrCreateToday() async {
    final db = await _open();
    final today = dateKey(DateTime.now());
    final rows = await db.query('entries',
        where: 'date = ?', whereArgs: [today], limit: 1);
    if (rows.isNotEmpty) return Entry.fromRow(rows.first);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('entries', {
      'date': today,
      'content': '',
      'updated_at': now,
    });
    return Entry(date: today, content: '', updatedAt: DateTime.now());
  }

  Future<Entry?> getByDate(String date) async {
    final db = await _open();
    final rows =
        await db.query('entries', where: 'date = ?', whereArgs: [date], limit: 1);
    if (rows.isEmpty) return null;
    return Entry.fromRow(rows.first);
  }

  Future<void> upsert(String date, String content) async {
    final db = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawInsert(
      'INSERT INTO entries(date, content, updated_at) VALUES(?, ?, ?) '
      'ON CONFLICT(date) DO UPDATE SET content = excluded.content, '
      'updated_at = excluded.updated_at',
      [date, content, now],
    );
  }

  // Remove an entry by date. The entries_ad trigger keeps the FTS index in
  // sync, so deleted text stops surfacing in search. Restoring is just an
  // upsert of the saved content (see ArchivePage's Undo).
  Future<void> delete(String date) async {
    final db = await _open();
    await db.delete('entries', where: 'date = ?', whereArgs: [date]);
  }

  Future<List<Entry>> listAll({int? limit}) async {
    final db = await _open();
    final rows = await db.query(
      'entries',
      where: "content != ''",
      orderBy: 'date DESC',
      limit: limit,
    );
    return rows.map(Entry.fromRow).toList();
  }

  Future<List<SearchHit>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    final db = await _open();
    final ftsQuery = _toFtsQuery(query);
    final rows = await db.rawQuery('''
      SELECT e.date AS date,
             snippet(entries_fts, 0, '[', ']', '...', 12) AS snippet
        FROM entries_fts
        JOIN entries e ON e.id = entries_fts.rowid
       WHERE entries_fts MATCH ?
       ORDER BY e.date DESC
       LIMIT 200
    ''', [ftsQuery]);
    return rows
        .map((r) =>
            SearchHit(date: r['date'] as String, snippet: r['snippet'] as String))
        .toList();
  }

  String _toFtsQuery(String input) {
    final tokens = input
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"*');
    return tokens.join(' ');
  }
}
