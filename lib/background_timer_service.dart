part of 'main.dart';

const _backgroundSetupGuideUri = 'https://dontkillmyapp.com/';

class BackgroundTimerService {
  const BackgroundTimerService();

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
      final initialized = await prepare();
      if (!initialized) {
        return false;
      }

      if (FlutterBackground.isBackgroundExecutionEnabled) {
        return true;
      }

      return FlutterBackground.enableBackgroundExecution();
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
