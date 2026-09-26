import 'dart:convert';

import 'package:breath_and_insight_timer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Run only on a disposable simulator: this seeds native preferences and logs.
// No plugin mocks: a native audio failure must fail the test, not fall back to
// the otherwise-valid silent timer used by ordinary host-side widget tests.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS audio, timer, breathing, logs and settings smoke test', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await const MeditationLogStore().purgeAll();
    await prefs.setString(
      'pranayamaEntries',
      jsonEncode([
        {
          'type': 'preset',
          'preset': {
            'id': 'ios-breathing',
            'name': 'iOS breathing test',
            'segments': [
              {
                'id': 'first',
                'durationSeconds': 8,
                'inBreathSeconds': 2,
                'firstHoldSeconds': 0,
                'outBreathSeconds': 2,
                'secondHoldSeconds': 0,
              },
              {
                'id': 'second',
                'durationSeconds': 12,
                'inBreathSeconds': 3,
                'firstHoldSeconds': 0,
                'outBreathSeconds': 3,
                'secondHoldSeconds': 0,
              },
            ],
          },
        },
      ]),
    );

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01-timers');

    // A real MP3 bell through the app's playback path and native SoLoud engine.
    await tester.tap(find.text('Quick 20 minutes').first);
    await tester.pump(const Duration(seconds: 2));
    expect(SoLoud.instance.isInitialized, isTrue);
    expect(SoLoud.instance.getActiveVoiceCount(), greaterThan(0));
    final clock = SoLoud.instance.getEngineTime();
    await tester.pump(const Duration(seconds: 1));
    expect(SoLoud.instance.getEngineTime(), greaterThan(clock));
    await binding.takeScreenshot('02-meditation');
    await tester.tap(find.byTooltip('Pause'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03-paused');
    await tester.tap(find.byKey(const ValueKey('finish-without-bell-button')));
    await tester.pumpAndSettle();
    expect(find.text('You completed:'), findsOneWidget);
    await binding.takeScreenshot('04-summary');
    await tester.tap(find.byKey(const ValueKey('summary-continue-button')));
    await tester.pumpAndSettle();
    final logs = await const MeditationLogStore().allEntries();
    expect(logs, hasLength(1));
    expect(logs.single.preset, 'Quick 20 minutes');
    expect(logs.single.duration.inSeconds, greaterThanOrEqualTo(2));

    // Validate generated PCM, scheduled voices, tab survival and segment end.
    await tester.tap(find.byKey(const ValueKey('pranayama-tab-button')));
    await tester.pumpAndSettle();
    final preset = find.byKey(
      const ValueKey('pranayama-iOS breathing test-root'),
    );
    await tester.ensureVisible(preset);
    await tester.tap(preset);
    await tester.pump(const Duration(seconds: 2));
    expect(SoLoud.instance.getActiveVoiceCount(), greaterThan(0));
    await tester.ensureVisible(
      find.byKey(const ValueKey('pranayama-tab-button')),
    );
    await binding.takeScreenshot('05-pranayama');
    await tester.tap(find.byKey(const ValueKey('timers-tab-button')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('pranayama-tab-button')));
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('3.0s'), findsNWidgets(2));
    await binding.takeScreenshot('06-second-segment');
    await tester.tap(find.byKey(const ValueKey('toggle-pranayama-button')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(SoLoud.instance.getActiveVoiceCount(), 0);
    await tester.tap(find.byKey(const ValueKey('toggle-pranayama-button')));
    await tester.pump(const Duration(seconds: 1));
    expect(SoLoud.instance.getActiveVoiceCount(), greaterThan(0));
    await tester.pump(const Duration(seconds: 14));
    expect(find.text('Ready'), findsOneWidget);
    expect(SoLoud.instance.getActiveVoiceCount(), 0);

    await tester.tap(find.byKey(const ValueKey('stats-tab-button')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('07-stats');
    await tester.tap(find.byKey(const ValueKey('view-edit-logs-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Quick 20 minutes'), findsOneWidget);
    await binding.takeScreenshot('08-logs');
    await tester.tap(find.byKey(const ValueKey('close-logs-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('09-settings');
    await tester.tap(find.byKey(const ValueKey('sound-enabled-switch')));
    await tester.pumpAndSettle();
    await prefs.reload();
    expect(prefs.getBool('soundEnabled'), isFalse);
    expect(tester.takeException(), isNull);
  });
}
