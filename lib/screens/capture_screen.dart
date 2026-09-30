import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/math_ai_service.dart';
import 'result_screen.dart';

/// Home screen: take or choose a photo, then convert it to LaTeX.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  final MathAiService _service = MathAiService.fromEnvironment();

  File? _image;
  bool _busy = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 2048);
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _error = null;
    });
  }

  Future<void> _convert() async {
    final image = _image;
    if (image == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await _service.analyseImage(image);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('MathChanger')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: _image == null
                    ? const Center(child: Text('尚未選擇圖片'))
                    : Image.file(_image!, fit: BoxFit.contain),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('拍照'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('相簿'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _image == null || _busy ? null : _convert,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_busy ? '轉換中…' : '轉換成 LaTeX'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
