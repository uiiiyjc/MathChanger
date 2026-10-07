import 'dart:io';

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/history_entry.dart';
import 'result_screen.dart';

/// Lists the recognition records still inside the retention window.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<HistoryEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = AppServices.instance.history.recent();
  }

  Future<void> _refresh() async {
    final future = AppServices.instance.history.recent();
    setState(() => _entries = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('歷史記錄')),
      body: FutureBuilder<List<HistoryEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('讀取失敗：${snapshot.error}'));
          }

          final entries = snapshot.data ?? const <HistoryEntry>[];
          if (entries.isEmpty) {
            return const Center(child: Text('還沒有任何記錄'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: _Thumbnail(path: entry.imagePath),
                    title: Text(_formatDate(entry.createdAt)),
                    subtitle: Text(
                      entry.stepCount == 0
                          ? '沒有辨識到內容'
                          : '${entry.stepCount} 個步驟',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ResultScreen(result: entry.result),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = path == null ? null : File(path!);

    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: file != null && file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ),
      ),
    );
  }
}
