part of 'main.dart';

const _backgroundSetupGuideUri = 'https://dontkillmyapp.com/';

class BackgroundTimerService {
  const BackgroundTimerService();

  static int _activeRequestCount = 0;

  Future<bool> prepare() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      return FlutterBackground.initialize(
        androidConfig: const FlutterBackgroundAndroidConfig(
          notificationTitle: 'Breath and Insight Timer',
          notificationText: 'Meditation timer is running',
          notificationImportance: AndroidNotificationImportance.normal,
        ),
      );
    } on MissingPluginException {
      return false;
    } on Object {
      return false;
    }
  }

  Future<bool> start() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      if (_activeRequestCount > 0 &&
          FlutterBackground.isBackgroundExecutionEnabled) {
        _activeRequestCount += 1;
        return true;
      }

      final initialized = await prepare();
      if (!initialized) {
        return false;
      }

      if (FlutterBackground.isBackgroundExecutionEnabled) {
        _activeRequestCount += 1;
        return true;
      }

      final enabled = await FlutterBackground.enableBackgroundExecution();
      if (enabled) {
        _activeRequestCount += 1;
      }
      return enabled;
    } on MissingPluginException {
      return false;
    } on Object {
      return false;
    }
  }

  Future<void> stop() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      if (_activeRequestCount > 0) {
        _activeRequestCount -= 1;
      }

      if (_activeRequestCount > 0) {
        return;
      }

      if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
    } on MissingPluginException {
      return;
    } on Object {
      return;
    }
  }
}

Future<bool> _openBackgroundSetupGuide() async {
  try {
    return await launchUrl(
      Uri.parse(_backgroundSetupGuideUri),
      mode: LaunchMode.externalApplication,
    );
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  } on Object {
    return false;
  }
}
