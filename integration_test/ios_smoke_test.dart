import 'dart:convert';

import 'package:breath_and_insight_timer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/ios_pranayama_fixture.dart';

// Run only on a disposable simulator: this seeds native preferences and logs.
// No plugin mocks: a native audio failure must fail the test, not fall back to
// the otherwise-valid silent timer used by ordinary host-side widget tests.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets(
    'iOS audio, timer, breathing, logs and settings smoke test',
    (tester) async {
      expect(
        const bool.fromEnvironment('DISPOSABLE_TEST_DEVICE'),
        isTrue,
        reason:
            'This test clears app data. Use only a disposable simulator with '
            '--dart-define=DISPOSABLE_TEST_DEVICE=true.',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await const MeditationLogStore().purgeAll();
      await prefs.setString(
        'pranayamaEntries',
        jsonEncode(iosPranayamaEntries),
      );

      await tester.pumpWidget(const BreathAndInsightTimerApp());
      await tester.pumpAndSettle();
      await binding.takeScreenshot('01-timers');
      final preset = find.byKey(
        const ValueKey('pranayama-iOS breathing test-root'),
      );
      // Native preference loading can finish after the first settled frame.
      // Establish that the fixture is loaded before exercising other routes.
      await tester.tap(find.byKey(const ValueKey('pranayama-tab-button')));
      await _waitUntil(tester, () => preset.evaluate().isNotEmpty);
      await tester.tap(find.byKey(const ValueKey('timers-tab-button')));
      await _waitUntil(
        tester,
        () => find.byKey(const ValueKey('timers-tab')).evaluate().isNotEmpty,
      );

      // A real MP3 bell through the app's playback path and native SoLoud engine.
      await tester.tap(find.text('Quick 20 minutes').first);
      await _waitUntil(
        tester,
        () =>
            SoLoud.instance.isInitialized &&
            SoLoud.instance.getActiveVoiceCount() > 0,
      );
      expect(SoLoud.instance.isInitialized, isTrue);
      expect(SoLoud.instance.getActiveVoiceCount(), greaterThan(0));
      final clock = SoLoud.instance.getEngineTime();
      await tester.pump(const Duration(seconds: 2));
      expect(SoLoud.instance.getEngineTime(), greaterThan(clock));
      await binding.takeScreenshot('02-meditation');
      await tester.tap(
        find.byKey(const ValueKey('minimize-meditation-button')),
      );
      await tester.pump(const Duration(seconds: 1));
      final activeTimer = find.byKey(
        const ValueKey('active-meditation-session-card'),
      );
      expect(activeTimer, findsOneWidget);
      await tester.tap(activeTimer);
      await tester.pump();
      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('03-paused');
      await tester.tap(
        find.byKey(const ValueKey('finish-without-bell-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('You completed:'), findsOneWidget);
      await binding.takeScreenshot('04-summary');
      await tester.tap(find.byKey(const ValueKey('summary-continue-button')));
      await _waitUntil(
        tester,
        () => find.byKey(const ValueKey('timers-tab')).evaluate().isNotEmpty,
      );
      final logs = await const MeditationLogStore().allEntries();
      expect(logs, hasLength(1));
      expect(logs.single.preset, 'Quick 20 minutes');
      expect(logs.single.duration.inSeconds, greaterThanOrEqualTo(2));

      final catalog =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/audio/bells/default-sounds.json',
                ),
              )
              as List<dynamic>;
      for (final sound in catalog.cast<Map<String, dynamic>>()) {
        final source = await SoLoud.instance.loadAsset(
          'assets/audio/bells/${sound['filename']}',
          mode: LoadMode.memory,
        );
        expect(
          SoLoud.instance.getLength(source),
          greaterThan(Duration.zero),
          reason: sound['filename'] as String,
        );
        await SoLoud.instance.disposeSource(source);
      }

      // Validate generated PCM, scheduled voices, tab survival and segment end.
      await tester.tap(find.byKey(const ValueKey('pranayama-tab-button')));
      await _waitUntil(tester, () => preset.evaluate().isNotEmpty);
      expect(find.byKey(const ValueKey('pranayama-tab')), findsOneWidget);
      await binding.takeScreenshot('05a-pranayama-ready');
      expect(preset, findsOneWidget);
      await tester.ensureVisible(preset);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(preset);
      await _waitUntil(tester, () => SoLoud.instance.getActiveVoiceCount() > 0);
      expect(SoLoud.instance.getActiveVoiceCount(), greaterThan(0));
      // Off-screen sliver headers are excluded from the widget finder. Scroll
      // back like a user would instead of requiring the header to exist first.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pranayama-tab-button')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 200));
      await binding.takeScreenshot('05-pranayama');
      await tester.tap(find.byKey(const ValueKey('timers-tab-button')));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('pranayama-tab-button')));
      await _waitUntil(tester, () => find.text('3.0s').evaluate().length == 2);
      expect(find.text('3.0s'), findsNWidgets(2));
      await binding.takeScreenshot('06-second-segment');
      await tester.tap(find.byKey(const ValueKey('toggle-pranayama-button')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(SoLoud.instance.getActiveVoiceCount(), 0);
      await tester.tap(find.byKey(const ValueKey('toggle-pranayama-button')));
      // The existing scheduler skips partial cycles rather than seeking into
      // a delayed voice. A mid-cycle resume can be silent until the next cycle.
      await _waitUntil(tester, () => SoLoud.instance.getActiveVoiceCount() > 0);
      expect(SoLoud.instance.getActiveVoiceCount(), greaterThan(0));
      await _waitUntil(
        tester,
        () =>
            find.text('Ready').evaluate().isNotEmpty &&
            SoLoud.instance.getActiveVoiceCount() == 0,
      );
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
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _waitUntil(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    ready(),
    isTrue,
    reason:
        'Timed out waiting for native app state. Visible labels: '
        '${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join(', ')}',
  );
}
