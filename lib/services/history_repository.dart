import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/history_entry.dart';
import '../models/math_step.dart';

/// Copies picked photos into app-owned storage.
///
/// `image_picker` hands back paths inside the OS cache directory, which the
/// system is free to wipe at any time. Archiving the bytes next to the database
/// is what makes a history row's preview survive a reboot.
class LocalImageStore {
  LocalImageStore({Future<Directory> Function()? rootDirectory})
      : _rootDirectory = rootDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _rootDirectory;

  Future<Directory> _imagesDir() async {
    final root = await _rootDirectory();
    final dir = Directory(p.join(root.path, 'history_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Returns the destination path of the archived copy.
  Future<String> archive(File source, {required DateTime now}) async {
    final dir = await _imagesDir();
    final extension =
        p.extension(source.path).isEmpty ? '.jpg' : p.extension(source.path);
    final name = '${now.millisecondsSinceEpoch}$extension';
    return (await source.copy(p.join(dir.path, name))).path;
  }

  /// Best-effort unlink; a missing file is not an error worth surfacing.
  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Already gone, or not ours to delete. Either way, nothing to do.
    }
  }
}

/// SQLite-backed store for recognition history.
///
/// Everything lives in a single database file under the app documents
/// directory. There is no network layer and no account, so the user is never
/// asked to trust a third party with their notes.
class HistoryRepository {
  HistoryRepository({LocalImageStore? imageStore, Database? database})
      : _imageStore = imageStore ?? LocalImageStore(),
        _injectedDatabase = database;

  static const String _fileName = 'math_changer.db';
  static const String _table = 'history';
  static const int _schemaVersion = 1;

  static const String _columnId = 'id';
  static const String _columnCreatedAt = 'created_at';
  static const String _columnImagePath = 'image_path';

  final LocalImageStore _imageStore;
  final Database? _injectedDatabase;

  Database? _database;

  Future<Database> get _db async {
    final injected = _injectedDatabase;
    if (injected != null) return injected;

    final existing = _database;
    if (existing != null) return existing;

    final dir = await getApplicationDocumentsDirectory();
    final opened = await openDatabase(
      p.join(dir.path, _fileName),
      version: _schemaVersion,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE $_table (
  $_columnId INTEGER PRIMARY KEY AUTOINCREMENT,
  $_columnCreatedAt TEXT NOT NULL,
  $_columnImagePath TEXT,
  payload TEXT NOT NULL,
  step_count INTEGER NOT NULL DEFAULT 0
)
''');
        await db.execute(
          'CREATE INDEX idx_history_created_at '
          'ON $_table ($_columnCreatedAt)',
        );
      },
    );
    _database = opened;
    return opened;
  }

  /// Persists a successful recognition, archiving the photo alongside it.
  Future<HistoryEntry> save({
    required RecognitionResult result,
    File? sourceImage,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final archivedPath = sourceImage == null
        ? null
        : await _imageStore.archive(sourceImage, now: timestamp);

    final entry = HistoryEntry(
      createdAt: timestamp,
      result: result,
      imagePath: archivedPath,
    );

    final db = await _db;
    final id = await db.insert(_table, entry.toRow());
    return HistoryEntry(
      id: id,
      createdAt: entry.createdAt,
      result: entry.result,
      imagePath: entry.imagePath,
    );
  }

  /// Newest first.
  Future<List<HistoryEntry>> recent({int limit = 200}) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      orderBy: '$_columnCreatedAt DESC',
      limit: limit,
    );
    return rows.map(HistoryEntry.fromRow).toList(growable: false);
  }

  Future<int> count() => _countWhere(null, null);

  /// How many records a given cutoff would remove right now. Used to warn the
  /// user before a retention change deletes anything.
  Future<int> countOlderThan(DateTime cutoff) => _countWhere(
        '$_columnCreatedAt < ?',
        [cutoff.toIso8601String()],
      );

  Future<int> _countWhere(String? where, List<Object?>? args) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM $_table'
      '${where == null ? '' : ' WHERE $where'}',
      args,
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Deletes rows created strictly before [cutoff], along with their photos.
  /// Returns the number of rows removed.
  Future<int> deleteOlderThan(DateTime cutoff) async {
    final db = await _db;
    final where = '$_columnCreatedAt < ?';
    final args = [cutoff.toIso8601String()];

    final stale = await db.query(
      _table,
      columns: [_columnImagePath],
      where: where,
      whereArgs: args,
    );
    final removed = await db.delete(_table, where: where, whereArgs: args);

    for (final row in stale) {
      await _imageStore.delete(row[_columnImagePath] as String?);
    }
    return removed;
  }

  /// Keeps only the newest [maxEntries] rows. Returns rows removed.
  Future<int> trimToMax(int maxEntries) async {
    final db = await _db;
    final stale = await db.query(
      _table,
      columns: [_columnId, _columnImagePath],
      orderBy: '$_columnCreatedAt DESC',
      offset: maxEntries,
    );
    if (stale.isEmpty) return 0;

    final ids = stale.map((row) => row[_columnId] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    final removed = await db.delete(
      _table,
      where: '$_columnId IN ($placeholders)',
      whereArgs: ids,
    );

    for (final row in stale) {
      await _imageStore.delete(row[_columnImagePath] as String?);
    }
    return removed;
  }

  /// Wipes every row and every archived photo. Returns rows removed.
  Future<int> deleteAll() async {
    final db = await _db;
    final paths = await db.query(_table, columns: [_columnImagePath]);
    final removed = await db.delete(_table);

    for (final row in paths) {
      await _imageStore.delete(row[_columnImagePath] as String?);
    }
    return removed;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
