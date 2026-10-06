import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/retention_policy.dart';
import '../services/cleanup_service.dart';
import '../services/settings_service.dart';

/// Lets the user point the app at their own vision API, and decide when to
/// clear their local data.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _endpointController = TextEditingController();
  final _modelController = TextEditingController();

  bool _loading = true;
  bool _obscureKey = true;
  bool _saving = false;
  bool _clearing = false;
  bool _retentionBusy = false;
  int _entryCount = 0;
  RetentionPolicy _policy = const RetentionPolicy();

  /// Bound to the slider, which works in doubles. Kept separate from [_policy]
  /// so an unconfirmed drag can be snapped back.
  double _sliderDays = RetentionPolicy.defaultDays.toDouble();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _endpointController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final services = AppServices.instance;
    final settings = await services.settings.load();
    final policy = await services.settings.loadRetentionPolicy();
    final count = await services.history.count();
    if (!mounted) return;
    setState(() {
      _apiKeyController.text = settings.apiKey;
      _endpointController.text = settings.endpoint;
      _modelController.text = settings.model;
      _policy = policy;
      _sliderDays = policy.days.toDouble();
      _entryCount = count;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await AppServices.instance.settings.save(
        AiSettings(
          apiKey: _apiKeyController.text,
          endpoint: _endpointController.text,
          model: _modelController.text,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定已儲存')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Called when the user lets go of the retention slider.
  ///
  /// Changing the window is not a free action, so it never applies silently:
  /// the user is told what the change costs and has to agree to it first.
  Future<void> _applyRetention(int days) async {
    final services = AppServices.instance;
    final proposed = RetentionPolicy.clamped(days);

    final impact = await services.cleanup.previewImpact(proposed);
    if (!mounted) return;

    if (impact.isUnchanged) {
      setState(() => _sliderDays = impact.current.days.toDouble());
      return;
    }

    final confirmed = await _confirmRetentionChange(impact);
    if (!mounted) return;

    if (confirmed != true) {
      // Snapped back: the drag was a question, not a decision.
      setState(() => _sliderDays = impact.current.days.toDouble());
      return;
    }

    setState(() => _retentionBusy = true);
    try {
      await services.settings.saveRetentionPolicy(proposed);
      final report = await services.cleanup.runWith(proposed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            report.expired == 0
                ? '保留期限已設為 ${proposed.days} 天'
                : '保留期限已設為 ${proposed.days} 天，清除了 '
                    '${report.expired} 筆逾時記錄',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _retentionBusy = false);
      await _load();
    }
  }

  /// "痛陳利害": spell out the consequence of the change the user is proposing.
  Future<bool?> _confirmRetentionChange(RetentionImpact impact) {
    final days = impact.proposed.days;
    final current = impact.current.days;

    final String title;
    final String body;
    final String action;

    if (impact.losesData) {
      title = '縮短保留期限？';
      body = '從 $current 天縮短到 $days 天，會立刻刪除 '
          '${impact.recordsAtRisk} 筆記錄，連同存在手機上的照片一起刪掉，'
          '而且無法復原。\n\n'
          '目前總共只有 ${impact.totalRecords} 筆記錄。';
      action = '仍要縮短';
    } else if (impact.isShortening) {
      title = '縮短保留期限？';
      body = '從 $current 天縮短到 $days 天。目前沒有記錄會因此被刪除，'
          '但之後的記錄也會更快過期。';
      action = '確定';
    } else {
      title = '延長保留期限？';
      body = '從 $current 天延長到 $days 天，資料會在手機上停留更久。\n\n'
          '本機圖片與辨識結果會持續累積，佔用的儲存空間會變多；'
          '圖片越多，App 的記憶體佔用與讀取負擔也會跟著增加，'
          '在儲存空間有限的裝置上尤其明顯。\n\n'
          '上限是 ${RetentionPolicy.maxDays} 天。';
      action = '仍要延長';
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Future<void> _clearNow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('立即清除所有記錄？'),
        content: Text(
          '這會永久刪除本機上的 $_entryCount 筆辨識記錄與對應的照片，'
          '無法復原。API 設定不會受影響。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _clearing = true);
    try {
      final report = await AppServices.instance.cleanup.runManual();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清除 ${report.manual} 筆記錄')),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('AI 辨識服務', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '辨識需要連網呼叫你選擇的服務。金鑰只存在這台裝置的'
                    '安全儲存區，不會上傳到其他地方。',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _obscureKey ? '顯示' : '隱藏',
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? '請填入 API Key，否則無法辨識'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _endpointController,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Endpoint',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final uri = Uri.tryParse(text);
                      if (uri == null ||
                          !uri.hasScheme ||
                          !(uri.isScheme('http') || uri.isScheme('https'))) {
                        return '請輸入有效的 http(s) 網址';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _modelController,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('儲存設定'),
                  ),
                  const Divider(height: 48),
                  Text('本機資料', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '記錄只存在這台裝置上，不會上傳。保留期限最長 '
                    '${RetentionPolicy.maxDays} 天。',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '保留最近 ${_sliderDays.round()} 天',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              if (_retentionBusy)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                          Slider(
                            value: _sliderDays,
                            min: RetentionPolicy.minDays.toDouble(),
                            max: RetentionPolicy.maxDays.toDouble(),
                            divisions: RetentionPolicy.maxDays -
                                RetentionPolicy.minDays,
                            label: '${_sliderDays.round()} 天',
                            onChanged: _retentionBusy
                                ? null
                                : (value) => setState(() => _sliderDays = value),
                            onChangeEnd: _retentionBusy
                                ? null
                                : (value) => _applyRetention(value.round()),
                          ),
                          Text(
                            '超過這個天數的記錄會自動刪除。'
                            '調整時會先告知影響。',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('目前記錄'),
                      subtitle: Text('$_entryCount 筆'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_forever_outlined,
                        color: theme.colorScheme.error,
                      ),
                      title: const Text('立即清除所有記錄'),
                      subtitle: const Text('照片與辨識結果都會一併刪除'),
                      trailing: _clearing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: _clearing ? null : _clearNow,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
