import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/math_step.dart';

/// Shows the LaTeX produced for each step, with copy-to-clipboard helpers.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final RecognitionResult result;

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已複製到剪貼簿')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('LaTeX 結果'),
        actions: [
          if (!result.isEmpty)
            IconButton(
              tooltip: '複製全部',
              icon: const Icon(Icons.copy_all),
              onPressed: () => _copy(context, result.fullLatex),
            ),
        ],
      ),
      body: result.isEmpty
          ? const Center(child: Text('沒有辨識到任何數學內容'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: result.steps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final step = result.steps[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Step ${step.index}',
                              style: theme.textTheme.labelLarge,
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: '複製這一步',
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () => _copy(context, step.latex),
                            ),
                          ],
                        ),
                        SelectableText(
                          step.latex,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                          ),
                        ),
                        if (step.explanation != null &&
                            step.explanation!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            step.explanation!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
