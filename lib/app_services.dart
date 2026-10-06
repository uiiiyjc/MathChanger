import 'services/cleanup_service.dart';
import 'services/history_repository.dart';
import 'services/settings_service.dart';

/// Process-wide handle on the app's services.
///
/// Instantiated once in `main()` and read by screens via `AppServices.instance`.
/// A plain holder keeps this dependency-free - pulling in a DI package for three
/// objects would be more ceremony than the app earns.
class AppServices {
  AppServices._({
    required this.settings,
    required this.history,
    required this.cleanup,
  });

  final SettingsService settings;
  final HistoryRepository history;
  final CleanupService cleanup;

  static AppServices? _instance;

  static AppServices get instance {
    final current = _instance;
    if (current == null) {
      throw StateError(
        'AppServices.bootstrap() must run before AppServices.instance is read.',
      );
    }
    return current;
  }

  static AppServices bootstrap() {
    final settings = SettingsService();
    final history = HistoryRepository();
    final services = AppServices._(
      settings: settings,
      history: history,
      cleanup: CleanupService(history, settings),
    );
    _instance = services;
    return services;
  }
}
