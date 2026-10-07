import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_services.dart';
import '../services/math_ai_service.dart';
import 'history_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';

/// Home screen: take or choose a photo, then convert it to LaTeX.
///
/// The camera and gallery are the operating system's own pickers, reached
/// through `image_picker` - the app does not ship a custom camera UI.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();

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

    final services = AppServices.instance;
    final settings = await services.settings.load();

    if (!settings.isConfigured) {
      if (!mounted) return;
      await _promptForApiKey();
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final service = MathAiService(
        apiKey: settings.apiKey,
        endpoint: settings.endpoint,
        model: settings.model,
      );
      final result = await service.analyseImage(image);

      // Local-only persistence: the record never leaves the device.
      await services.history.save(result: result, sourceImage: image);

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

  Future<void> _promptForApiKey() async {
    final goToSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('尚未設定 API Key'),
        content: const Text('辨識需要一組 API Key。請先到設定頁填入你的服務資訊。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('稍後'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('前往設定'),
          ),
        ],
      ),
    );

    if (goToSettings == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('MathChanger'),
        actions: [
          IconButton(
            tooltip: '歷史記錄',
            icon: const Icon(Icons.history),
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
          ),
          IconButton(
            tooltip: '設定',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _busy ? null : _openSettings,
          ),
        ],
      ),
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
