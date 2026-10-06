import '../models/retention_policy.dart';
import 'history_repository.dart';
import 'settings_service.dart';

/// Outcome of a cleanup pass, used to report back to the user.
class CleanupReport {
  const CleanupReport({this.expired = 0, this.overflow = 0, this.manual = 0});

  /// Rows dropped for being past the retention window.
  final int expired;

  /// Rows dropped for exceeding the entry ceiling.
  final int overflow;

  /// Rows dropped by an explicit user request.
  final int manual;

  int get total => expired + overflow + manual;

  bool get removedNothing => total == 0;
}

/// A forecast of what a retention policy would do if applied right now.
///
/// The settings screen uses this to tell the user exactly how much data they
/// are about to lose before they commit to a shorter window.
class RetentionImpact {
  const RetentionImpact({
    required this.current,
    required this.proposed,
    required this.recordsAtRisk,
    required this.totalRecords,
  });

  final RetentionPolicy current;
  final RetentionPolicy proposed;

  /// Records that the proposed window would delete immediately.
  final int recordsAtRisk;

  final int totalRecords;

  bool get isShortening => proposed.days < current.days;
  bool get isLengthening => proposed.days > current.days;
  bool get isUnchanged => proposed.days == current.days;

  /// True when shortening the window would actually destroy something. Warn
  /// only when there is real data on the line.
  bool get losesData => isShortening && recordsAtRisk > 0;
}

/// Enforces the app's data-retention rules.
///
/// The window is adjustable within the bounds of [RetentionPolicy], which caps
/// it at [RetentionPolicy.maxDays]. Storage on a phone is finite, so the app
/// never lets the window grow past that ceiling.
class CleanupService {
  CleanupService(this._repository, this._settings);

  /// Hard ceiling that backstops the time window, so a burst of scans inside
  /// the retention period still cannot fill the device.
  static const int maxEntries = 200;

  final HistoryRepository _repository;
  final SettingsService _settings;

  /// Runs on every cold start. Silent, non-blocking, tolerant of failure.
  Future<CleanupReport> runAutomatic({DateTime? now}) async {
    final policy = await _settings.loadRetentionPolicy();
    return runWith(policy, now: now);
  }

  /// Applies [policy] immediately.
  Future<CleanupReport> runWith(RetentionPolicy policy, {DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(policy.duration);
    final expired = await _repository.deleteOlderThan(cutoff);
    final overflow = await _repository.trimToMax(maxEntries);
    return CleanupReport(expired: expired, overflow: overflow);
  }

  /// Triggered by the user from the settings screen.
  Future<CleanupReport> runManual() async {
    final removed = await _repository.deleteAll();
    return CleanupReport(manual: removed);
  }

  /// Works out what switching to [proposed] would cost, without changing
  /// anything. Callers show this to the user before persisting the choice.
  Future<RetentionImpact> previewImpact(
    RetentionPolicy proposed, {
    DateTime? now,
  }) async {
    final current = await _settings.loadRetentionPolicy();
    final safe = RetentionPolicy.clamped(proposed.days);

    final total = await _repository.count();
    final atRisk = await _repository.countOlderThan(
      (now ?? DateTime.now()).subtract(safe.duration),
    );

    return RetentionImpact(
      current: current,
      proposed: safe,
      recordsAtRisk: atRisk,
      totalRecords: total,
    );
  }
}
