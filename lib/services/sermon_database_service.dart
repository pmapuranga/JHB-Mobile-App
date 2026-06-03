import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/sermon.dart';
import '../models/sermon_paragraph.dart';
import '../models/sermon_search_result.dart';

class SermonDatabaseService {
  SermonDatabaseService._();

  static final SermonDatabaseService instance = SermonDatabaseService._();

  static const String _databaseName = 'sermon_library.sqlite';
  static const int _databaseVersion = 12;
  static const String _databaseAsset = 'assets/preload/sermon_library.sqlite';
  static const String _booksAsset = 'assets/preload/books.json';
  static const String _searchIndexAsset = 'assets/preload/search_index.json';
  static const String _sermonTextAssetPrefix = 'assets/preload/sermons/';

  Database? _database;
  bool _ftsAvailable = false;
  bool _searchTableAvailable = false;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _databaseName);
    await _installPrebuiltDatabase(dbPath);
    final db = await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _resetSchema(db);
        await _createSchema(db);
      },
    );

    _searchTableAvailable = await _hasSearchTable(db);
    if (!await _hasPackagedSermons(db)) {
      await _seedFromPreload(db);
    }
    _database = db;
    return db;
  }

  Future<List<Sermon>> sermons() async {
    final db = await database;
    final rows = await db.query(
      'sermons',
      orderBy: 'sermon_date DESC, code DESC, title COLLATE NOCASE ASC',
    );
    return rows.map(Sermon.fromMap).toList();
  }

  Future<Sermon?> sermonForBookId(String bookId) async {
    final db = await database;
    final rows = await db.query(
      'sermons',
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Sermon.fromMap(rows.first);
  }

  Future<List<SermonParagraph>> paragraphsForSermon(int sermonId) async {
    final db = await database;
    final rows = await db.query(
      'sermon_paragraphs',
      where: 'sermon_id = ?',
      whereArgs: [sermonId],
      orderBy: 'paragraph_no ASC, paragraph_id ASC',
    );
    return rows.map(SermonParagraph.fromMap).toList();
  }

  Future<MapEntry<Sermon, List<SermonParagraph>>?> preloadedContentForBookId(
    String bookId,
  ) async {
    final normalizedBookId = _normalizePreloadedBookId(bookId);
    final booksRaw = await rootBundle.loadString(_booksAsset);
    final booksJson = jsonDecode(booksRaw) as Map<String, dynamic>;
    final books = (booksJson['books'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final lookupKey = _lookupKey(bookId);
    Map<String, dynamic>? book;
    for (final candidate in books) {
      if (_matchesPreloadedBook(candidate, normalizedBookId, lookupKey)) {
        book = candidate;
        break;
      }
    }

    if (book == null) return null;

    final matchedBookId = _normalizePreloadedBookId(
      book['id']?.toString() ?? '',
    );
    final code = book['idCode']?.toString() ?? '';
    final title = book['title']?.toString() ?? '';
    final duration = _durationToSeconds(book['duration']?.toString() ?? '');
    final audioFile = book['audio']?.toString() ?? '';
    final sermon = Sermon(
      id: -1,
      code: code,
      title: title,
      preacher: book['preacher']?.toString() ?? '',
      sermonDate: _dateFromCode(code),
      place: book['location']?.toString() ?? '',
      language: book['language']?.toString() ?? 'en',
      durationSeconds: duration,
      audioFile: audioFile,
      isDownloaded: audioFile.isNotEmpty,
      bookId: matchedBookId,
      category: book['category']?.toString() ?? 'preloaded',
    );

    final sermonEntries = await _preloadedEntriesForBookId(matchedBookId);
    sermonEntries.sort((a, b) {
      final aOrder = _asInt(a['paragraph']) ?? _asInt(a['sortOrder']) ?? 1;
      final bOrder = _asInt(b['paragraph']) ?? _asInt(b['sortOrder']) ?? 1;
      return aOrder.compareTo(bOrder);
    });

    final paragraphs = <SermonParagraph>[];
    for (var index = 0; index < sermonEntries.length; index += 1) {
      final entry = sermonEntries[index];
      final number =
          _asInt(entry['paragraph']) ?? _asInt(entry['sortOrder']) ?? index + 1;
      paragraphs.add(
        SermonParagraph(
          id: index + 1,
          sermonId: sermon.id,
          number: number.toString(),
          sortOrder: number,
          text: entry['text']?.toString() ?? '',
          startMs: _asInt(entry['startMs']),
          endMs: _asInt(entry['endMs']),
        ),
      );
    }

    if (paragraphs.isEmpty) {
      paragraphs.add(
        SermonParagraph(
          id: 1,
          sermonId: sermon.id,
          number: '1',
          sortOrder: 1,
          text: title,
        ),
      );
    }

    return MapEntry(sermon, paragraphs);
  }

  Future<List<Map<String, dynamic>>> _preloadedEntriesForBookId(
    String bookId,
  ) async {
    final normalizedBookId = _normalizePreloadedBookId(bookId);
    final assetId = normalizedBookId.replaceFirst('preloaded:', '');

    try {
      final raw =
          await rootBundle.loadString('$_sermonTextAssetPrefix$assetId.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (json['entries'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      final searchRaw = await rootBundle.loadString(_searchIndexAsset);
      final searchJson = jsonDecode(searchRaw) as Map<String, dynamic>;
      final entries = (searchJson['entries'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      return entries
          .where(
            (entry) =>
                _normalizePreloadedBookId(entry['bookId']?.toString() ?? '') ==
                normalizedBookId,
          )
          .toList();
    }
  }

  Future<List<SermonSearchResult>> search({
    required String query,
    String? bookId,
    bool wholePhrase = false,
    int limit = 100,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final db = await database;
    final scopeSql = bookId == null ? '' : 'AND sermons.book_id = ?';
    final scopeArgs = bookId == null ? <Object?>[] : <Object?>[bookId];

    if (_ftsAvailable) {
      final matchQuery =
          wholePhrase ? '"${_escapeFts(trimmed)}"' : _fts(trimmed);
      final rows = await db.rawQuery('''
        SELECT
          sermons.sermon_id,
          sermons.book_id,
          sermons.code,
          sermons.title,
          sermons.place,
          sermon_paragraphs.paragraph_id,
          sermon_paragraphs.paragraph_no,
          sermon_paragraphs.text,
          sermon_paragraphs.start_time_ms,
          sermon_paragraphs.end_time_ms,
          bm25(sermon_search) AS rank
        FROM sermon_search
        JOIN sermon_paragraphs
          ON sermon_paragraphs.paragraph_id = sermon_search.paragraph_id
        JOIN sermons
          ON sermons.sermon_id = sermon_search.sermon_id
        WHERE sermon_search MATCH ?
          $scopeSql
        ORDER BY rank, sermons.sermon_date, sermon_paragraphs.paragraph_no
        LIMIT ?
      ''', [matchQuery, ...scopeArgs, limit]);
      return rows.map(SermonSearchResult.fromMap).toList();
    }

    final terms = wholePhrase
        ? [trimmed.toLowerCase()]
        : trimmed
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((term) => term.isNotEmpty)
            .toList();
    final whereParts = terms.map((_) => 'LOWER(sermon_paragraphs.text) LIKE ?');
    final whereJoiner = wholePhrase ? ' AND ' : ' OR ';
    final likeArgs = terms.map((term) => '%$term%').toList();
    final rows = await db.rawQuery('''
      SELECT
        sermons.sermon_id,
        sermons.book_id,
        sermons.code,
        sermons.title,
        sermons.place,
        sermon_paragraphs.paragraph_id,
        sermon_paragraphs.paragraph_no,
        sermon_paragraphs.text,
        sermon_paragraphs.start_time_ms,
        sermon_paragraphs.end_time_ms,
        0.0 AS rank
      FROM sermon_paragraphs
      JOIN sermons ON sermons.sermon_id = sermon_paragraphs.sermon_id
      WHERE (${whereParts.join(whereJoiner)})
        $scopeSql
      ORDER BY sermons.sermon_date, sermon_paragraphs.paragraph_no
      LIMIT ?
    ''', [...likeArgs, ...scopeArgs, limit]);
    return rows.map(SermonSearchResult.fromMap).toList();
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sermons (
        sermon_id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT,
        title TEXT NOT NULL,
        preacher TEXT,
        sermon_date TEXT,
        place TEXT,
        language TEXT DEFAULT 'en',
        category TEXT,
        audio_file TEXT,
        duration_seconds INTEGER DEFAULT 0,
        is_downloaded INTEGER DEFAULT 0,
        book_id TEXT UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sermon_paragraphs (
        paragraph_id INTEGER PRIMARY KEY AUTOINCREMENT,
        sermon_id INTEGER NOT NULL,
        paragraph_no INTEGER NOT NULL,
        text TEXT NOT NULL,
        start_time_ms INTEGER,
        end_time_ms INTEGER,
        FOREIGN KEY (sermon_id) REFERENCES sermons(sermon_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS downloads (
        download_id INTEGER PRIMARY KEY AUTOINCREMENT,
        sermon_id INTEGER,
        audio_url TEXT,
        local_path TEXT,
        file_format TEXT DEFAULT 'opus',
        downloaded_at TEXT,
        FOREIGN KEY (sermon_id) REFERENCES sermons(sermon_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks (
        bookmark_id INTEGER PRIMARY KEY AUTOINCREMENT,
        sermon_id INTEGER,
        paragraph_id INTEGER,
        note TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sermon_id) REFERENCES sermons(sermon_id) ON DELETE CASCADE,
        FOREIGN KEY (paragraph_id) REFERENCES sermon_paragraphs(paragraph_id)
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS highlights (
        highlight_id INTEGER PRIMARY KEY AUTOINCREMENT,
        sermon_id INTEGER,
        paragraph_id INTEGER,
        start_offset INTEGER,
        end_offset INTEGER,
        color TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sermon_id) REFERENCES sermons(sermon_id) ON DELETE CASCADE,
        FOREIGN KEY (paragraph_id) REFERENCES sermon_paragraphs(paragraph_id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sermons_book_id ON sermons(book_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sermon_paragraphs_sermon ON sermon_paragraphs(sermon_id, paragraph_no)',
    );

    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS sermon_search
        USING fts5(
          title,
          text,
          sermon_id UNINDEXED,
          paragraph_id UNINDEXED
        )
      ''');
      _ftsAvailable = true;
      _searchTableAvailable = true;
    } catch (_) {
      _ftsAvailable = false;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sermon_search (
          title TEXT,
          text TEXT,
          sermon_id INTEGER,
          paragraph_id INTEGER
        )
      ''');
      _searchTableAvailable = true;
    }
  }

  Future<void> _resetSchema(Database db) async {
    await db.execute('DROP TABLE IF EXISTS sermon_search');
    await db.execute('DROP TABLE IF EXISTS paragraphs_fts');
    await db.execute('DROP TABLE IF EXISTS highlights');
    await db.execute('DROP TABLE IF EXISTS bookmarks');
    await db.execute('DROP TABLE IF EXISTS notes');
    await db.execute('DROP TABLE IF EXISTS downloads');
    await db.execute('DROP TABLE IF EXISTS timestamps');
    await db.execute('DROP TABLE IF EXISTS sermon_paragraphs');
    await db.execute('DROP TABLE IF EXISTS paragraphs');
    await db.execute('DROP TABLE IF EXISTS sermons');
  }

  Future<void> _installPrebuiltDatabase(String dbPath) async {
    final existing = databaseFactory.databaseExists(dbPath);
    if (await existing) return;

    try {
      final data = await rootBundle.load(_databaseAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await databaseFactory.writeDatabaseBytes(dbPath, bytes);
    } catch (_) {
      return;
    }
  }

  Future<bool> _hasPackagedSermons(Database db) async {
    try {
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM sermons'),
      );
      return (count ?? 0) > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _seedFromPreload(Database db) async {
    final booksRaw = await rootBundle.loadString(_booksAsset);
    final searchRaw = await rootBundle.loadString(_searchIndexAsset);
    final booksJson = jsonDecode(booksRaw) as Map<String, dynamic>;
    final searchJson = jsonDecode(searchRaw) as Map<String, dynamic>;
    final books = (booksJson['books'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final entries = (searchJson['entries'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final currentBookIds = books
        .map((book) => book['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .map((id) => id.startsWith('preloaded:') ? id : 'preloaded:$id')
        .toSet();
    final expectedParagraphs = entries
        .where((entry) => currentBookIds.contains(entry['bookId']?.toString()))
        .length;

    if (await _hasCurrentSeed(
      db,
      currentBookIds: currentBookIds,
      expectedParagraphs: expectedParagraphs,
    )) {
      return;
    }

    await _resetSchema(db);
    await _createSchema(db);

    await db.transaction((txn) async {
      for (final book in books) {
        final rawId = book['id']?.toString() ?? '';
        final bookId =
            rawId.startsWith('preloaded:') ? rawId : 'preloaded:$rawId';
        final code = book['idCode']?.toString() ?? '';
        final title = book['title']?.toString() ?? '';
        final duration = _durationToSeconds(book['duration']?.toString() ?? '');
        final audioFile = book['audio']?.toString() ?? '';
        final sermonId = await txn.insert(
          'sermons',
          {
            'code': code,
            'title': title,
            'preacher': book['preacher']?.toString() ?? '',
            'sermon_date': _dateFromCode(code),
            'place': book['location']?.toString() ?? '',
            'language': book['language']?.toString() ?? 'en',
            'category': book['category']?.toString() ?? 'preloaded',
            'audio_file': audioFile,
            'duration_seconds': duration,
            'is_downloaded': audioFile.isEmpty ? 0 : 1,
            'book_id': bookId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final sermonEntries = entries
            .where((entry) => entry['bookId']?.toString() == bookId)
            .toList();
        if (sermonEntries.isEmpty) {
          await _insertParagraph(
            txn,
            sermonId: sermonId,
            title: title,
            number: 1,
            text: title,
          );
        } else {
          for (final entry in sermonEntries) {
            await _insertParagraph(
              txn,
              sermonId: sermonId,
              title: title,
              number:
                  _asInt(entry['paragraph']) ?? _asInt(entry['sortOrder']) ?? 1,
              text: entry['text']?.toString() ?? '',
              startMs: _asInt(entry['startMs']),
              endMs: _asInt(entry['endMs']),
            );
          }
        }
      }
    });
  }

  Future<bool> _hasCurrentSeed(
    Database db, {
    required Set<String> currentBookIds,
    required int expectedParagraphs,
  }) async {
    if (currentBookIds.isEmpty) return false;

    final placeholders = List.filled(currentBookIds.length, '?').join(',');
    final existingBooks = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM sermons WHERE book_id IN ($placeholders)',
        currentBookIds.toList(),
      ),
    );
    if ((existingBooks ?? 0) != currentBookIds.length) return false;

    final existingParagraphs = Sqflite.firstIntValue(
      await db.rawQuery(
        '''
        SELECT COUNT(*)
        FROM sermon_paragraphs
        JOIN sermons ON sermons.sermon_id = sermon_paragraphs.sermon_id
        WHERE sermons.book_id IN ($placeholders)
        ''',
        currentBookIds.toList(),
      ),
    );

    final minimumParagraphs =
        expectedParagraphs > 0 ? expectedParagraphs : currentBookIds.length;
    return (existingParagraphs ?? 0) >= minimumParagraphs;
  }

  Future<int> _insertParagraph(
    Transaction txn, {
    required int sermonId,
    required String title,
    required int number,
    required String text,
    int? startMs,
    int? endMs,
  }) async {
    final paragraphId = await txn.insert('sermon_paragraphs', {
      'sermon_id': sermonId,
      'paragraph_no': number,
      'text': text,
      'start_time_ms': startMs,
      'end_time_ms': endMs,
    });
    if (_searchTableAvailable) {
      await txn.insert('sermon_search', {
        'title': title,
        'text': text,
        'sermon_id': sermonId,
        'paragraph_id': paragraphId,
      });
    }
    return paragraphId;
  }

  Future<bool> _hasSearchTable(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'sermon_search'",
    );
    return rows.isNotEmpty;
  }

  String _fts(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .map(_escapeFts)
        .join(' OR ');
  }

  String _escapeFts(String value) {
    return value.replaceAll('"', '""');
  }

  int _durationToSeconds(String value) {
    final cleaned = value.replaceAll('TIME:', '').trim();
    final parts = cleaned
        .split(':')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
    if (parts.length == 1) return parts.first;
    if (parts.length == 2) return parts.first * 60 + parts.last;
    if (parts.length >= 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
    return 0;
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _normalizePreloadedBookId(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('preloaded:')) return trimmed;
    return 'preloaded:$trimmed';
  }

  bool _matchesPreloadedBook(
    Map<String, dynamic> book,
    String normalizedBookId,
    String lookupKey,
  ) {
    final id = book['id']?.toString() ?? '';
    final code = book['idCode']?.toString() ?? '';
    final title = book['title']?.toString() ?? '';
    final normalizedId = _normalizePreloadedBookId(id);
    final idKey = _lookupKey(id);
    final codeKey = _lookupKey(code);
    final titleKey = _lookupKey(title);

    if (normalizedId == normalizedBookId) return true;
    if (lookupKey.isEmpty) return false;
    if (lookupKey == idKey || lookupKey == codeKey || lookupKey == titleKey) {
      return true;
    }
    if (codeKey.isNotEmpty && lookupKey.contains(codeKey)) return true;
    if (idKey.isNotEmpty &&
        (lookupKey.contains(idKey) || idKey.contains(lookupKey))) {
      return true;
    }
    if (titleKey.isNotEmpty &&
        (lookupKey.contains(titleKey) || titleKey.contains(lookupKey))) {
      return true;
    }
    return false;
  }

  String _lookupKey(String value) {
    return value
        .toLowerCase()
        .replaceFirst('preloaded:', '')
        .replaceAll(RegExp(r'\.[a-z0-9]+$'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _dateFromCode(String code) {
    final match = RegExp(r'^(\d{2})-(\d{2})(\d{2})').firstMatch(code);
    if (match == null) return '';
    final year = int.parse(match.group(1)!);
    final century = year >= 40 ? 1900 : 2000;
    return '${century + year}-${match.group(2)}-${match.group(3)}';
  }
}
