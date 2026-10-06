/// How long recognition history is kept on the device.
///
/// The window is adjustable, but only downwards from the default: [maxDays] is
/// a hard ceiling. Letting the window stretch would contradict the reason this
/// app stores anything locally at all - a cheap phone should not be asked to
/// carry an ever-growing pile of photos.
class RetentionPolicy {
  const RetentionPolicy({this.days = defaultDays});

  static const int minDays = 1;
  static const int maxDays = 15;
  static const int defaultDays = 15;

  /// Number of days a record survives after it is written.
  final int days;

  Duration get duration => Duration(days: days);

  bool get isMax => days >= maxDays;
  bool get isMin => days <= minDays;

  /// Coerces any value into the supported range.
  factory RetentionPolicy.clamped(int days) {
    if (days < minDays) return const RetentionPolicy(days: minDays);
    if (days > maxDays) return const RetentionPolicy(days: maxDays);
    return RetentionPolicy(days: days);
  }

  /// Short label for a settings row.
  String get label => '保留最近 $days 天';

  @override
  bool operator ==(Object other) =>
      other is RetentionPolicy && other.days == days;

  @override
  int get hashCode => days.hashCode;

  @override
  String toString() => 'RetentionPolicy(days: $days)';
}
