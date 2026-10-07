import 'dart:convert';

import 'math_step.dart';

/// A past recognition, persisted in the local SQLite database.
///
/// Entries are device-local by design: the app ships no backend, so the only
/// copy of this data is the one on the user's phone.
class HistoryEntry {
  const HistoryEntry({
    this.id,
    required this.createdAt,
    required this.result,
    this.imagePath,
  });

  factory HistoryEntry.fromRow(Map<String, Object?> row) => HistoryEntry(
        id: row['id'] as int?,
        createdAt: DateTime.parse(row['created_at'] as String),
        imagePath: row['image_path'] as String?,
        result: RecognitionResult.fromJson(
          jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        ),
      );

  final int? id;
  final DateTime createdAt;
  final RecognitionResult result;

  /// Absolute path to the archived copy of the source photo, if one was kept.
  ///
  /// The file is owned by the app and is deleted alongside the row, so a
  /// dangling path here means "no preview available", not "missing file".
  final String? imagePath;

  int get stepCount => result.steps.length;

  /// Row shape for `HistoryRepository`. `id` is omitted so SQLite assigns it.
  Map<String, Object?> toRow() => {
        'created_at': createdAt.toIso8601String(),
        'image_path': imagePath,
        'payload': jsonEncode(result.toJson()),
        'step_count': stepCount,
      };
}
