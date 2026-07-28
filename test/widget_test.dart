import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:breath_and_insight_timer/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('home screen opens on timers tab and can switch tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    expect(find.text('Breath and Insight Timer'), findsNothing);
    expect(find.text('Timers'), findsWidgets);
    expect(find.text('Pranayama'), findsOneWidget);
    expect(find.text('Stats'), findsWidgets);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('Recent timers'), findsOneWidget);
    expect(find.text('Quick 20 minutes'), findsWidgets);
    expect(find.text('Long sessions'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stats-tab-button')));
    await tester.pumpAndSettle();

    final statsButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('stats-tab-button')),
    );
    final timersButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('timers-tab-button')),
    );

    expect(statsButton.style?.foregroundColor?.resolve({}), Colors.white);
    expect(
      timersButton.style?.foregroundColor?.resolve({}),
      const Color(0xFF77777C),
    );

    await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sound'), findsOneWidget);
    expect(find.text('Turn screen back on near playing audio'), findsOneWidget);
    expect(find.text('Test sound'), findsOneWidget);
    expect(find.text('Background timers'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('prepare-background-timer-support-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('background-setup-guide-button')),
      findsOneWidget,
    );
    expect(find.text('Recent timers'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('recent-timer-limit-value')),
      findsOneWidget,
    );
    expect(find.text('Presets'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reinstall-default-presets-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('import-presets-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('export-presets-button')), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-logs-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('export-logs-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('purge-logs-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('acknowledgements-button')),
      findsOneWidget,
    );
  });

  testWidgets('acknowledgements screen opens from settings', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('acknowledgements-button')));
    await tester.pumpAndSettle();

    expect(find.text('Acknowledgements'), findsOneWidget);
    expect(
      find.textContaining('Insight Timer app', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Forrest Knutson', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('excellent book', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('thank you to Codex', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('close-acknowledgements-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('pranayama tab can run presets inline and edit the list', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('pranayama-tab-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pranayama-tab')), findsOneWidget);
    expect(find.text('Recent presets'), findsOneWidget);
    expect(find.text('No recent presets yet'), findsOneWidget);
    expect(find.text('Presets'), findsOneWidget);
    expect(find.text('6 in 8 out'), findsWidgets);
    expect(find.text('Balancing'), findsOneWidget);
    expect(find.text('Forrest Knutson'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('pranayama-folder-Forrest Knutson')),
    );
    await tester.pumpAndSettle();
    expect(find.text('4/5 HRV Breathing'), findsOneWidget);
    expect(find.text('15 minutes | 4-0-5-0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pranayama-6 in 8 out-root')));
    await tester.pump();

    expect(find.text('Inhale'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('toggle-pranayama-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('stop-pranayama-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('timers-tab-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pranayama-tab')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('pranayama-tab-button')));
    await tester.pumpAndSettle();
    expect(find.text('Inhale'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pranayama-6 in 8 out-recent')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('edit-pranayama-positions-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('editable-pranayama-browser')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('add-pranayama-preset-button')));
    await tester.pumpAndSettle();
    expect(find.text('Create new preset'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pranayama-in-breath-field')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('cancel-timer-edit-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-pranayama-folder-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pranayama-folder-title-field')),
      'Breath work',
    );
    await tester.tap(
      find.byKey(const ValueKey('save-pranayama-folder-title-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Breath work'), findsOneWidget);
  });

  testWidgets('meditation discard stops a concurrent pranayama session', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'soundEnabled': false});
    final clock = _TestClock();
    await tester.binding.setSurfaceSize(const Size(800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(home: HomeScreen(now: clock.now)));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('pranayama-tab-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pranayama-6 in 8 out-root')));
    await tester.pump();

    expect(find.text('Inhale'), findsOneWidget);
    expect(find.byKey(const ValueKey('stop-pranayama-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('timers-tab-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('timer-Quick 20 minutes-root')));
    await tester.pumpAndSettle();

    expect(find.text('Meditation'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('discard-session-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pranayama-tab-button')));
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Paused'), findsNothing);
    final stopButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('stop-pranayama-button')),
    );
    expect(stopButton.enabled, isFalse);
    expect(find.text('6 in 8 out'), findsWidgets);
  });

  test('finite pranayama segments complete whole breath cycles', () {
    const preset = PranayamaPreset(
      id: 'test-multi-segment',
      name: 'Multi segment',
      segments: [
        PranayamaSegment(
          id: 'segment-one',
          duration: Duration(seconds: 5),
          inBreath: Duration(seconds: 3),
          firstHold: Duration.zero,
          outBreath: Duration(seconds: 3),
          secondHold: Duration.zero,
        ),
        PranayamaSegment(
          id: 'segment-two',
          duration: Duration(seconds: 7),
          inBreath: Duration(seconds: 2),
          firstHold: Duration.zero,
          outBreath: Duration(seconds: 2),
          secondHold: Duration.zero,
        ),
      ],
    );

    expect(
      effectivePranayamaDurationForTesting(preset),
      const Duration(seconds: 14),
    );
    expect(
      pranayamaSegmentAtElapsedForTesting(
        preset,
        const Duration(milliseconds: 5999),
      ).segment.id,
      'segment-one',
    );
    expect(
      pranayamaSegmentAtElapsedForTesting(
        preset,
        const Duration(seconds: 6),
      ).segment.id,
      'segment-two',
    );
  });

  test('pranayama tone clips are longer than one breath cycle', () {
    const finiteSegment = PranayamaSegment(
      id: 'finite-tone',
      duration: Duration(minutes: 15),
      inBreath: Duration(seconds: 4),
      firstHold: Duration.zero,
      outBreath: Duration(seconds: 5),
      secondHold: Duration.zero,
    );
    const infiniteSegment = PranayamaSegment(
      id: 'infinite-tone',
      duration: null,
      inBreath: Duration(seconds: 6),
      firstHold: Duration.zero,
      outBreath: Duration(seconds: 8),
      secondHold: Duration.zero,
    );

    expect(
      pranayamaToneClipDurationForTesting(finiteSegment),
      effectivePranayamaDurationForTesting(
        const PranayamaPreset(
          id: 'finite-tone-preset',
          name: 'Finite tone',
          segments: [finiteSegment],
        ),
      ),
    );
    expect(
      pranayamaToneClipDurationForTesting(infiniteSegment),
      greaterThan(infiniteSegment.cycleDuration * 80),
    );
  });

  testWidgets('meditation screen can launch and pause pranayama presets', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'soundEnabled': false});
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('timer-Quick 20 minutes-root')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('select-pranayama-preset-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('select-pranayama-preset-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select preset'), findsOneWidget);
    expect(find.text('Recent presets'), findsOneWidget);
    expect(find.text('Presets'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pranayama-6 in 8 out-root')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Meditation'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meditation-pranayama-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stop-meditation-pranayama-button')),
      findsOneWidget,
    );
    expect(find.text('Inhale'), findsOneWidget);
    expect(find.textContaining('Clock: 12:'), findsOneWidget);
    expect(find.text('Breaths: 0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();

    expect(find.text('Paused'), findsOneWidget);

    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();

    expect(find.text('Paused'), findsNothing);
    expect(find.text('Inhale'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('stop-meditation-pranayama-button')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('meditation-pranayama-panel')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('select-pranayama-preset-button')),
      findsOneWidget,
    );
  });

  testWidgets('pranayama editor can create multi-segment presets', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('pranayama-tab-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-pranayama-preset-button')));
    await tester.pumpAndSettle();

    expect(find.text('Segments'), findsOneWidget);
    expect(find.text('Segment 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add-pranayama-segment-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('add-pranayama-segment-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Segment 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('duration-infinite-checkbox')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('duration-infinite-checkbox')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pranayama-in-breath-field')).last,
      '4',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pranayama-in-breath-field')).last,
      '',
    );
    TextField inBreathField = tester.widget(
      find
          .descendant(
            of: find.byKey(const ValueKey('pranayama-in-breath-field')).last,
            matching: find.byType(TextField),
          )
          .last,
    );
    expect(inBreathField.controller?.text, '');
    await tester.enterText(
      find.byKey(const ValueKey('pranayama-in-breath-field')).last,
      '6',
    );
    inBreathField = tester.widget(
      find
          .descendant(
            of: find.byKey(const ValueKey('pranayama-in-breath-field')).last,
            matching: find.byType(TextField),
          )
          .last,
    );
    expect(inBreathField.controller?.text, '6');
    await tester.enterText(
      find.byKey(const ValueKey('pranayama-out-breath-field')).last,
      '5',
    );

    await tester.tap(find.byKey(const ValueKey('save-timer-edit-button')));
    await tester.pumpAndSettle();

    expect(find.text('New preset'), findsOneWidget);
    expect(find.text('Infinite | 2 segments'), findsOneWidget);
  });

  testWidgets('sound setting can be disabled and is remembered', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
    await tester.pumpAndSettle();

    SwitchListTile soundSwitch = tester.widget(
      find.byKey(const ValueKey('sound-enabled-switch')),
    );
    expect(soundSwitch.value, isTrue);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('test-sound-button')))
          .enabled,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('sound-enabled-switch')));
    await tester.pumpAndSettle();

    soundSwitch = tester.widget(
      find.byKey(const ValueKey('sound-enabled-switch')),
    );
    expect(soundSwitch.value, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('test-sound-button')))
          .enabled,
      isFalse,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
    await tester.pumpAndSettle();

    soundSwitch = tester.widget(
      find.byKey(const ValueKey('sound-enabled-switch')),
    );
    expect(soundSwitch.value, isFalse);
  });

  testWidgets(
    'screen auto-reveal preference can be disabled and is remembered',
    (WidgetTester tester) async {
      await tester.pumpWidget(const BreathAndInsightTimerApp());
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
      await tester.pumpAndSettle();

      SwitchListTile revealSwitch = tester.widget(
        find.byKey(const ValueKey('turn-screen-on-near-audio-switch')),
      );
      expect(revealSwitch.value, isTrue);

      await tester.tap(
        find.byKey(const ValueKey('turn-screen-on-near-audio-switch')),
      );
      await tester.pumpAndSettle();

      revealSwitch = tester.widget(
        find.byKey(const ValueKey('turn-screen-on-near-audio-switch')),
      );
      expect(revealSwitch.value, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(const BreathAndInsightTimerApp());
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
      await tester.pumpAndSettle();

      revealSwitch = tester.widget(
        find.byKey(const ValueKey('turn-screen-on-near-audio-switch')),
      );
      expect(revealSwitch.value, isFalse);
    },
  );

  testWidgets('background setup guide failure shows a message', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(openBackgroundSetupGuide: () async => false),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('background-setup-guide-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Could not open the background setup guide.'),
      findsOneWidget,
    );
  });

  testWidgets('recent timers can be minimized and folders can expand', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    expect(find.text('Recent timers'), findsOneWidget);
    expect(find.text('No recent timers yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('folder-Long sessions')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('timer-1 hour-nested')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard session'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('timer-1 hour-recent')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recent-timers-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('timer-1 hour-recent')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('recent-timers-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('timer-1 hour-recent')), findsOneWidget);
  });

  testWidgets('recent timers use stable timer ids across renames', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('timer-Quick 20 minutes-root')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard session'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('timer-Quick 20 minutes-recent')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('edit-timer-timer-Quick 20 minutes')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-timer-title-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('timer-title-field')),
      '25 minutes',
    );
    await tester.tap(find.byKey(const ValueKey('save-timer-title-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-timer-edit-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('timer-25 minutes-recent')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('timer-Quick 20 minutes-recent')),
      findsNothing,
    );
  });

  testWidgets(
    'back minimizes active meditation and card can reopen or discard',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'soundEnabled': false});
      final clock = _TestClock();
      await tester.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MaterialApp(home: HomeScreen(now: clock.now)));
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('timer-Quick 20 minutes-root')),
      );
      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(
        find.byKey(const ValueKey('active-meditation-session-card')),
        findsNothing,
      );

      await tester.binding.handlePopRoute();
      await tester.pump();

      final activeCard = find.byKey(
        const ValueKey('active-meditation-session-card'),
      );
      expect(activeCard, findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
      expect(
        find.descendant(
          of: activeCard,
          matching: find.text('Quick 20 minutes'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: activeCard, matching: find.text('00:00')),
        findsOneWidget,
      );

      clock.advance(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.descendant(of: activeCard, matching: find.text('00:02')),
        findsOneWidget,
      );

      await tester.tap(activeCard);
      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.text('19:58'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();

      expect(activeCard, findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);

      await tester.tap(activeCard);
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.drag(activeCard, const Offset(700, 0));
      await tester.pumpAndSettle();

      expect(activeCard, findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
      expect(
        find.byKey(const ValueKey('timer-Quick 20 minutes-root')),
        findsOneWidget,
      );
    },
  );

  testWidgets('legacy saved bell assets are remapped to current sounds', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'timerEntries': jsonEncode([
        {
          'type': 'timer',
          'timer': {
            'id': 'legacy-bell-timer',
            'name': 'Legacy bell timer',
            'note': '',
            'activity': 'Meditation',
            'durationSeconds': 1200,
            'startingBell': 'audio/bells/singing-bowl--long--2.mp3',
            'endingBell': 'audio/bells/singing-bowl--very-long--1.mp3',
            'intermediateBells': [
              {
                'startTimeSeconds': 300,
                'bell': 'audio/bells/singing-bowl--long--4.mp3',
                'repeatIntervalSeconds': null,
              },
            ],
          },
        },
      ]),
    });

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    expect(find.text('Legacy bell timer'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('edit-timer-timer-Legacy bell timer')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meditation Bowl in G(ish)'), findsOneWidget);
    expect(find.text('Low and Long Singing Bowl'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-intermediate-bells-button')),
    );
    expect(find.text('Gong Bowl'), findsOneWidget);
  });

  testWidgets('recent timer count preference is remembered', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('increase-recent-timer-limit-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('increase-recent-timer-limit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('4'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
    await tester.pumpAndSettle();

    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('stats tab shows streak and practice bar periods', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final today = DateTime.now();
    for (var offset = 1; offset <= 40; offset += 1) {
      await const MeditationLogStore().append(
        MeditationLogEntry(
          id: 'streak-log-$offset',
          startedAt: DateTime(today.year, today.month, today.day - offset, 12),
          duration: const Duration(minutes: 20),
          preset: 'Quick 20 minutes',
          activity: 'Meditation',
        ),
      );
    }
    await const MeditationLogStore().append(
      MeditationLogEntry(
        id: 'older-streak-log-42',
        startedAt: DateTime(today.year, today.month, today.day - 42, 12),
        duration: const Duration(hours: 2),
        preset: 'Quick 20 minutes',
        activity: 'Meditation',
      ),
    );
    await const MeditationLogStore().append(
      MeditationLogEntry(
        id: 'older-streak-log-43',
        startedAt: DateTime(today.year, today.month, today.day - 43, 12),
        duration: const Duration(hours: 6),
        preset: 'Quick 20 minutes',
        activity: 'Meditation',
      ),
    );

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stats-tab-button')));
    await tester.pumpAndSettle();

    expect(find.text('Stats'), findsWidgets);
    expect(find.byKey(const ValueKey('view-edit-logs-button')), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('view-edit-logs-button')))
          .height,
      40,
    );
    expect(find.byKey(const ValueKey('streak-length-value')), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('streak length'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('some-statistics-section')),
      findsOneWidget,
    );
    expect(find.text('Some statistics'), findsOneWidget);
    expect(find.byKey(const ValueKey('streak-details-toggle')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('streak-details-toggle')));
    await tester.pumpAndSettle();

    final gapDay = DateTime(today.year, today.month, today.day - 41);
    expect(find.byKey(const ValueKey('streak-details-panel')), findsOneWidget);
    expect(
      find.text('First day before streak: ${_dateOnlyForTest(gapDay)}'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('repair-streak-button')), findsOneWidget);
    expect(find.text('10-30 minutes: 40'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('repair-streak-button')));
    await tester.pumpAndSettle();

    expect(find.text('Repair streak'), findsWidgets);
    expect(
      find.text(
        'We will now repair your streak by adding a zero-minute log entry on the day ${_dateOnlyForTest(gapDay)}, which will cause your streak number to rise from 40 to 43.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-repair-streak-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('43'), findsOneWidget);
    expect(find.text('Zero-minute days: 1'), findsWidgets);
    expect(find.byKey(const ValueKey('stats-period-selector')), findsOneWidget);
    expect(find.byKey(const ValueKey('practice-bar-chart')), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Daily practice'), findsOneWidget);
    expect(find.text('# of hours'), findsOneWidget);
    expect(find.text('day'), findsOneWidget);
    expect(find.text(_weekdayInitialForTest(today)), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('stats-period-weeks')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stats-per-day-checkbox')),
      findsOneWidget,
    );
    expect(find.text('Total practice per week'), findsOneWidget);
    expect(find.text('week'), findsOneWidget);
    expect(find.text(_weekLabelForTest(today)), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('stats-per-day-checkbox')));
    await tester.pumpAndSettle();

    final perDayCheckbox = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('stats-per-day-checkbox')),
    );
    expect(perDayCheckbox.value, isTrue);
    expect(find.text('Daily average per week'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stats-period-months')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stats-per-day-checkbox')),
      findsOneWidget,
    );
    expect(find.text('Daily average per month'), findsOneWidget);
    expect(find.text('month'), findsOneWidget);
    expect(find.text(_monthAbbreviationForTest(today.month)), findsWidgets);
  });

  testWidgets('timer positions can be edited by dragging top-level entries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    expect(find.byKey(const ValueKey('add-timer-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-folder-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('edit-timer-positions-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();

    final firstTimerHandle = find.byKey(
      const ValueKey('drag-handle-timer-Quick 20 minutes'),
    );
    final secondTimerHandle = find.byKey(
      const ValueKey('drag-handle-timer-Infinite meditation'),
    );

    expect(firstTimerHandle, findsOneWidget);
    expect(secondTimerHandle, findsOneWidget);

    final firstInitialTop = tester.getTopLeft(firstTimerHandle).dy;
    final secondInitialTop = tester.getTopLeft(secondTimerHandle).dy;
    expect(firstInitialTop, lessThan(secondInitialTop));

    await tester.drag(firstTimerHandle, const Offset(0, 180));
    await tester.pumpAndSettle();

    final firstMovedTop = tester.getTopLeft(firstTimerHandle).dy;
    final secondMovedTop = tester.getTopLeft(secondTimerHandle).dy;
    expect(firstMovedTop, greaterThan(secondMovedTop));

    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();

    final infiniteTop = tester.getTopLeft(find.text('Infinite meditation')).dy;
    final twentyMinuteTop = tester
        .getTopLeft(find.text('Quick 20 minutes').last)
        .dy;
    expect(infiniteTop, lessThan(twentyMinuteTop));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();

    final persistedFirstTop = tester.getTopLeft(secondTimerHandle).dy;
    final persistedSecondTop = tester.getTopLeft(firstTimerHandle).dy;
    expect(persistedFirstTop, lessThan(persistedSecondTop));
  });

  testWidgets('folder can be added from the timers section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('add-folder-button')));
    await tester.pumpAndSettle();

    expect(find.text('Add folder'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('folder-title-field')),
      'Long sessions',
    );
    await tester.tap(find.byKey(const ValueKey('save-folder-title-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('A folder with this title already exists'),
      findsOneWidget,
    );
    expect(find.text('Add folder'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('folder-title-field')),
      'Morning sessions',
    );
    await tester.tap(find.byKey(const ValueKey('save-folder-title-button')));
    await tester.pumpAndSettle();

    expect(find.text('Morning sessions'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    expect(find.text('Morning sessions'), findsOneWidget);
  });

  testWidgets('timers can move inside folders and back out', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();

    final infiniteHandle = find.byKey(
      const ValueKey('drag-handle-timer-Infinite meditation'),
    );
    final oneHourNestedHandle = find.byKey(
      const ValueKey('drag-handle-timer-Long sessions-1 hour'),
    );

    await tester.drag(infiniteHandle, const Offset(0, 180));
    await tester.pumpAndSettle();

    final infiniteNestedHandle = find.byKey(
      const ValueKey('drag-handle-timer-Long sessions-Infinite meditation'),
    );
    expect(infiniteNestedHandle, findsOneWidget);
    expect(
      tester.getTopLeft(infiniteNestedHandle).dy,
      lessThan(tester.getTopLeft(oneHourNestedHandle).dy),
    );

    await tester.drag(infiniteNestedHandle, const Offset(0, -95));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(infiniteNestedHandle).dy,
      lessThan(tester.getTopLeft(oneHourNestedHandle).dy),
    );

    await tester.drag(infiniteNestedHandle, const Offset(0, -450));
    await tester.pumpAndSettle();

    final infiniteTopLevelHandle = find.byKey(
      const ValueKey('drag-handle-timer-Infinite meditation'),
    );
    final folderHandle = find.byKey(
      const ValueKey('drag-handle-folder-Long sessions'),
    );
    expect(infiniteTopLevelHandle, findsOneWidget);
    expect(
      tester.getTopLeft(infiniteTopLevelHandle).dy,
      lessThan(tester.getTopLeft(folderHandle).dy),
    );

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();

    expect(infiniteTopLevelHandle, findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('drag-handle-timer-Long sessions-Infinite meditation'),
      ),
      findsNothing,
    );
  });

  testWidgets('folder title can be edited in position edit mode', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('add-folder-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('folder-title-field')),
      'Morning sessions',
    );
    await tester.tap(find.byKey(const ValueKey('save-folder-title-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('edit-folder-title-Long sessions')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit folder title'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('folder-title-field')),
      'Morning sessions',
    );
    await tester.tap(find.byKey(const ValueKey('save-folder-title-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('A folder with this title already exists'),
      findsOneWidget,
    );
    expect(find.text('Edit folder title'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('folder-title-field')),
      'Evening sessions',
    );
    await tester.tap(find.byKey(const ValueKey('save-folder-title-button')));
    await tester.pumpAndSettle();

    expect(find.text('Evening sessions'), findsOneWidget);
    expect(find.text('Long sessions'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    expect(find.text('Evening sessions'), findsOneWidget);
    expect(find.text('Long sessions'), findsNothing);
  });

  testWidgets('empty folder can be deleted but non-empty folder cannot', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('add-folder-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('folder-title-field')),
      'Empty folder',
    );
    await tester.tap(find.byKey(const ValueKey('save-folder-title-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('delete-timer-timer-Quick 20 minutes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('delete-folder-Long sessions')),
      findsOneWidget,
    );

    final nonEmptyDeleteButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('delete-folder-Long sessions')),
    );
    expect(nonEmptyDeleteButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('delete-folder-Long sessions')));
    await tester.pumpAndSettle();

    expect(find.text('Long sessions'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('drag-handle-timer-Long sessions-1 hour')),
      findsOneWidget,
    );

    final emptyDeleteButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('delete-folder-Empty folder')),
    );
    expect(emptyDeleteButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('delete-folder-Empty folder')));
    await tester.pumpAndSettle();

    expect(find.text('Empty folder'), findsNothing);
    expect(find.text('Long sessions'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();

    expect(find.text('Empty folder'), findsNothing);
    expect(find.text('Long sessions'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('drag-handle-timer-Long sessions-1 hour')),
      findsOneWidget,
    );
  });

  testWidgets('new timer can be created from the edit timer screen', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('add-timer-button')));
    await tester.pumpAndSettle();

    expect(find.text('Create new timer'), findsOneWidget);
    expect(find.byKey(const ValueKey('timers-tab-button')), findsNothing);
    expect(find.byKey(const ValueKey('settings-tab-button')), findsNothing);
    expect(
      find.byKey(const ValueKey('timer-edit-scroll-view')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('edit-timer-title-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('timer-title-field')),
      'Silent sitting',
    );
    await tester.tap(find.byKey(const ValueKey('save-timer-title-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('duration-infinite-checkbox')));
    await tester.pumpAndSettle();

    final hoursField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('duration-hours-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(hoursField.enabled, isFalse);

    await tester.tap(find.byKey(const ValueKey('starting-bell-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ending-bell-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-timer-edit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Silent sitting'), findsOneWidget);
    expect(find.text('Infinite'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    expect(find.text('Silent sitting'), findsOneWidget);
    expect(find.text('Infinite'), findsWidgets);
  });

  testWidgets('timer editor saves preparation time', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('add-timer-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-timer-title-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('timer-title-field')),
      'Timer with prep',
    );
    await tester.tap(find.byKey(const ValueKey('save-timer-title-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('preparation-minutes-field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('preparation-minutes-field')),
      '1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('preparation-seconds-field')),
      '75',
    );

    final preparationMinutesField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('preparation-minutes-field')),
        matching: find.byType(TextField),
      ),
    );
    final preparationSecondsField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('preparation-seconds-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(preparationMinutesField.controller?.text, '02');
    expect(preparationSecondsField.controller?.text, '15');

    await tester.tap(find.byKey(const ValueKey('save-timer-edit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Timer with prep'), findsOneWidget);
    expect(find.text('20 minutes + 2 minutes 15 seconds prep'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    expect(find.text('Timer with prep'), findsOneWidget);
    expect(find.text('20 minutes + 2 minutes 15 seconds prep'), findsOneWidget);
  });

  testWidgets('existing timer can be edited from position edit mode', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('edit-timer-timer-Quick 20 minutes')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit timer'), findsOneWidget);
    expect(find.byKey(const ValueKey('timers-tab-button')), findsNothing);
    expect(find.text('High and Long Meditation Bell'), findsOneWidget);
    expect(find.text('Low and Long Singing Bowl'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit-timer-title-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('timer-title-field')),
      '25 minutes',
    );
    await tester.tap(find.byKey(const ValueKey('save-timer-title-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('timer-note-field')),
      'Long sit',
    );
    await tester.enterText(
      find.byKey(const ValueKey('duration-minutes-field')),
      '25',
    );
    await tester.tap(find.byKey(const ValueKey('starting-bell-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-timer-edit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Edit timer'), findsNothing);
    expect(
      find.byKey(const ValueKey('edit-timer-positions-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('timer-25 minutes-root')), findsOneWidget);
    expect(find.text('25 minutes | Long sit'), findsOneWidget);
  });

  testWidgets('duration fields normalize overflow and invalid values on save', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('add-timer-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-timer-title-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('timer-title-field')),
      'Overflow timer',
    );
    await tester.tap(find.byKey(const ValueKey('save-timer-title-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('duration-hours-field')),
      '0',
    );
    await tester.enterText(
      find.byKey(const ValueKey('duration-minutes-field')),
      '90',
    );
    await tester.enterText(
      find.byKey(const ValueKey('duration-seconds-field')),
      '3670',
    );

    TextField hoursField = tester.widget(
      find.descendant(
        of: find.byKey(const ValueKey('duration-hours-field')),
        matching: find.byType(TextField),
      ),
    );
    TextField minutesField = tester.widget(
      find.descendant(
        of: find.byKey(const ValueKey('duration-minutes-field')),
        matching: find.byType(TextField),
      ),
    );
    TextField secondsField = tester.widget(
      find.descendant(
        of: find.byKey(const ValueKey('duration-seconds-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(hoursField.controller?.text, '2');
    expect(minutesField.controller?.text, '31');
    expect(secondsField.controller?.text, '10');

    await tester.tap(find.byKey(const ValueKey('save-timer-edit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Overflow timer'), findsOneWidget);
    expect(find.text('2 hours 31 minutes 10 seconds'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-timer-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-timer-title-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('timer-title-field')),
      'Too long timer',
    );
    await tester.tap(find.byKey(const ValueKey('save-timer-title-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('duration-hours-field')),
      '999',
    );
    await tester.enterText(
      find.byKey(const ValueKey('duration-minutes-field')),
      '0',
    );
    await tester.enterText(
      find.byKey(const ValueKey('duration-seconds-field')),
      '3600',
    );
    await tester.pump();

    final infiniteCheckbox = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('duration-infinite-checkbox')),
    );
    hoursField = tester.widget(
      find.descendant(
        of: find.byKey(const ValueKey('duration-hours-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(infiniteCheckbox.value, isTrue);
    expect(hoursField.enabled, isFalse);

    await tester.tap(find.byKey(const ValueKey('save-timer-edit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Too long timer'), findsOneWidget);
    expect(find.text('Infinite'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('add-timer-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-timer-title-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('timer-title-field')),
      'Messy input timer',
    );
    await tester.tap(find.byKey(const ValueKey('save-timer-title-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('duration-hours-field')),
      'bananas',
    );
    await tester.enterText(
      find.byKey(const ValueKey('duration-minutes-field')),
      '-12',
    );
    await tester.enterText(
      find.byKey(const ValueKey('duration-seconds-field')),
      '',
    );

    hoursField = tester.widget(
      find.descendant(
        of: find.byKey(const ValueKey('duration-hours-field')),
        matching: find.byType(TextField),
      ),
    );
    minutesField = tester.widget(
      find.descendant(
        of: find.byKey(const ValueKey('duration-minutes-field')),
        matching: find.byType(TextField),
      ),
    );
    secondsField = tester.widget(
      find.descendant(
        of: find.byKey(const ValueKey('duration-seconds-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(hoursField.controller?.text, 'bananas');
    expect(minutesField.controller?.text, '-12');
    expect(secondsField.controller?.text, '');

    await tester.tap(find.byKey(const ValueKey('save-timer-edit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Messy input timer'), findsOneWidget);
    expect(find.text('1 second'), findsOneWidget);
  });

  testWidgets('duration fields can be cleared while editing', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('add-timer-button')));
    await tester.pumpAndSettle();

    final minutesFinder = find.byKey(const ValueKey('duration-minutes-field'));
    await tester.enterText(minutesFinder, '10');
    await tester.enterText(minutesFinder, '1');
    await tester.enterText(minutesFinder, '');

    TextField minutesField = tester.widget(
      find.descendant(of: minutesFinder, matching: find.byType(TextField)),
    );
    expect(minutesField.controller?.text, '');

    await tester.enterText(minutesFinder, '6');
    minutesField = tester.widget(
      find.descendant(of: minutesFinder, matching: find.byType(TextField)),
    );
    expect(minutesField.controller?.text, '6');

    await tester.tap(find.byKey(const ValueKey('save-timer-edit-button')));
    await tester.pumpAndSettle();

    expect(find.text('New timer'), findsOneWidget);
    expect(find.text('6 minutes'), findsOneWidget);
  });

  testWidgets('bell sound fields open a filterable sound selection screen', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('add-timer-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('starting-bell-field')));
    await tester.pumpAndSettle();

    expect(find.text('Select sound'), findsOneWidget);
    expect(find.text('Knock on wood'), findsOneWidget);
    expect(find.text('High and Long Meditation Bell'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('play-sound-Knock on wood')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sound-tag-bowl')), findsOneWidget);
    expect(find.byKey(const ValueKey('sound-tag-long')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sound-tag-bowl')));
    await tester.pumpAndSettle();

    expect(find.text('Knock on wood'), findsNothing);
    expect(find.text('Meditation Bowl in G(ish)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sound-tag-long')));
    await tester.pumpAndSettle();

    expect(find.text('Low and Long Singing Bowl'), findsOneWidget);
    expect(find.text('Meditation Bowl in G(ish)'), findsNothing);

    await tester.tap(find.text('Low and Long Singing Bowl'));
    await tester.pumpAndSettle();

    expect(find.text('Select sound'), findsNothing);
    expect(find.text('Low and Long Singing Bowl'), findsOneWidget);
  });

  testWidgets('intermediate bells can be added and edited in timer editor', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('add-timer-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-timer-title-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('timer-title-field')),
      'Bell timer',
    );
    await tester.tap(find.byKey(const ValueKey('save-timer-title-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('add-intermediate-bell-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('add-intermediate-bell-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bell 1'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('intermediate-bell-0-start-minutes-field')),
      '0',
    );
    await tester.enterText(
      find.byKey(const ValueKey('intermediate-bell-0-start-seconds-field')),
      '90',
    );

    TextField startMinutesField = tester.widget(
      find.descendant(
        of: find.byKey(
          const ValueKey('intermediate-bell-0-start-minutes-field'),
        ),
        matching: find.byType(TextField),
      ),
    );
    TextField startSecondsField = tester.widget(
      find.descendant(
        of: find.byKey(
          const ValueKey('intermediate-bell-0-start-seconds-field'),
        ),
        matching: find.byType(TextField),
      ),
    );
    expect(startMinutesField.controller?.text, '01');
    expect(startSecondsField.controller?.text, '30');

    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('intermediate-bell-0-repeat-minutes-field')),
      '0',
    );
    await tester.enterText(
      find.byKey(const ValueKey('intermediate-bell-0-repeat-seconds-field')),
      '120',
    );

    TextField repeatMinutesField = tester.widget(
      find.descendant(
        of: find.byKey(
          const ValueKey('intermediate-bell-0-repeat-minutes-field'),
        ),
        matching: find.byType(TextField),
      ),
    );
    TextField repeatSecondsField = tester.widget(
      find.descendant(
        of: find.byKey(
          const ValueKey('intermediate-bell-0-repeat-seconds-field'),
        ),
        matching: find.byType(TextField),
      ),
    );
    expect(repeatMinutesField.controller?.text, '02');
    expect(repeatSecondsField.controller?.text, '00');

    await tester.tap(find.byKey(const ValueKey('save-timer-edit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Bell timer'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-timer-timer-Bell timer')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-intermediate-bells-button')),
    );

    expect(find.text('Knock on wood'), findsWidgets);
    expect(find.textContaining('00:01:30'), findsOneWidget);
    expect(find.textContaining('Repeats every'), findsOneWidget);
  });

  testWidgets('session plays intermediate bells with precedence', (
    WidgetTester tester,
  ) async {
    final clock = _TestClock();
    final playedBells = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MeditationSessionScreen(
          now: clock.now,
          onBellPlayed: (bell) => playedBells.add(bell.name),
          timer: const MeditationTimerPreset(
            id: 'timer-precedence-test',
            name: 'Precedence test',
            duration: Duration(seconds: 10),
            startingBell: BellSound(
              name: 'Start',
              assetPath: 'audio/bells/wood-knock.mp3',
            ),
            endingBell: BellSound(
              name: 'End',
              assetPath: 'audio/bells/singing-bowl--long--1.mp3',
            ),
            intermediateBells: [
              IntermediateBell(
                startTime: Duration(seconds: 5),
                bell: BellSound(
                  name: 'Priority',
                  assetPath: 'audio/bells/singing-bowl--long--4.mp3',
                ),
              ),
              IntermediateBell(
                startTime: Duration(seconds: 5),
                bell: BellSound(
                  name: 'Repeating',
                  assetPath: 'audio/bells/singing-bowl--long--3.mp3',
                ),
                repeatInterval: Duration(seconds: 5),
              ),
              IntermediateBell(
                startTime: Duration.zero,
                bell: BellSound(
                  name: 'Zero',
                  assetPath: 'audio/bells/singing-bowl--long--2.mp3',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(playedBells, ['Start']);

    clock.advance(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(playedBells, ['Start', 'Priority']);

    clock.advance(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(playedBells, ['Start', 'Priority', 'End']);
  });

  testWidgets('timer delete button confirms before removing a timer', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(
      const ValueKey('delete-timer-timer-Infinite meditation'),
    );
    expect(deleteButton, findsOneWidget);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Delete timer?'), findsOneWidget);
    expect(
      find.text('Delete "Infinite meditation"? This cannot be undone.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(deleteButton, findsOneWidget);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-timer-button')));
    await tester.pumpAndSettle();

    expect(deleteButton, findsNothing);
    expect(
      find.byKey(const ValueKey('drag-handle-timer-Infinite meditation')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();

    expect(deleteButton, findsNothing);
  });

  testWidgets('deleted default presets can be reinstalled from settings', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('edit-timer-positions-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('delete-timer-timer-Quick 20 minutes')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-timer-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('timer-Quick 20 minutes-root')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('reinstall-default-presets-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('ignore-preset-conflicts-button')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Reinstalled default presets'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('timers-tab-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('timer-Quick 20 minutes-root')),
      findsOneWidget,
    );
  });

  testWidgets('finished sessions are logged and logs can be edited', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await const MeditationLogStore().append(
      MeditationLogEntry(
        id: 'seed-log',
        startedAt: DateTime(2026, 5, 1, 16, 3, 29),
        duration: const Duration(minutes: 20, seconds: 4),
        preset: 'Quick 20 minutes',
        activity: 'Meditation',
      ),
    );

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stats-tab-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('view-edit-logs-button')));
    await tester.pumpAndSettle();

    expect(find.text('View and Edit Logs'), findsOneWidget);
    expect(find.textContaining('Quick 20 minutes'), findsOneWidget);
    expect(find.textContaining('Meditation'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('add-log-entry-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('log-duration-hours-field')),
      '1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('log-duration-minutes-field')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('log-duration-seconds-field')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('log-preset-field')),
      'Manual',
    );
    await tester.enterText(
      find.byKey(const ValueKey('log-activity-field')),
      'Walking',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-add-log-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Manual'), findsOneWidget);
    expect(find.textContaining('Walking'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-logs-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Manual'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('close-logs-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('view-edit-logs-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Quick 20 minutes'), findsOneWidget);
    expect(find.textContaining('Manual'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('edit-log-seed-log')));
    await tester.pumpAndSettle();
    expect(find.text('Edit log entry'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('log-started-at-time-button')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('log-duration-hours-field')),
      '0',
    );
    await tester.enterText(
      find.byKey(const ValueKey('log-duration-minutes-field')),
      '90',
    );
    await tester.enterText(
      find.byKey(const ValueKey('log-duration-seconds-field')),
      '75',
    );
    await tester.enterText(
      find.byKey(const ValueKey('log-activity-field')),
      'Edited practice',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-add-log-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('1:31:15'), findsOneWidget);
    expect(find.textContaining('Edited practice'), findsOneWidget);
  });

  testWidgets('logs can be imported from and exported to compatible CSV', (
    WidgetTester tester,
  ) async {
    await const MeditationLogStore().append(
      MeditationLogEntry(
        id: 'already-logged-in-app',
        startedAt: DateTime(2026, 5, 1, 16, 3, 29),
        duration: const Duration(minutes: 21, seconds: 4),
        preset: '',
        activity: 'Meditation',
      ),
    );

    const csv = '''
Started At,Duration,Preset,Activity
05/01/2026 16:03:29,0:21:4,,Meditation
05/01/2026 09:59:37,0:45:37,"Walking, mindful",Walking
bad-date,0:10:0,Broken,Meditation
''';

    final importResult = await const MeditationLogStore().importCsv(csv);

    expect(importResult.importedCount, 1);
    expect(importResult.skippedCount, 2);

    final duplicateImportResult = await const MeditationLogStore().importCsv(
      csv,
    );

    expect(duplicateImportResult.importedCount, 0);
    expect(duplicateImportResult.skippedCount, 3);

    final queryResult = await const MeditationLogStore().query();
    expect(queryResult.totalCount, 2);
    expect(
      queryResult.entries.first.duration,
      const Duration(minutes: 21, seconds: 4),
    );
    expect(queryResult.entries.last.preset, 'Walking, mindful');

    final exportedCsv = await const MeditationLogStore().exportCsv();

    expect(exportedCsv, startsWith('Started At,Duration,Preset,Activity'));
    expect(exportedCsv, contains('05/01/2026 16:03:29,0:21:4,,Meditation'));
    expect(exportedCsv, contains('"Walking, mindful",Walking'));
  });

  testWidgets('all logs can be purged from settings after confirmation', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const logStore = MeditationLogStore();
    await logStore.append(
      MeditationLogEntry(
        id: 'purge-test-log',
        startedAt: DateTime(2026, 5, 1, 16),
        duration: const Duration(minutes: 20),
        preset: 'Quick 20 minutes',
        activity: 'Meditation',
      ),
    );

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
    await tester.pumpAndSettle();

    final purgeButton = find.byKey(const ValueKey('purge-logs-button'));
    await tester.tap(purgeButton);
    await tester.pumpAndSettle();

    expect(find.text('Purge all logs?'), findsOneWidget);
    expect(
      find.text(
        'This will permanently delete every meditation log entry. This cannot be undone.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect((await logStore.query()).totalCount, 1);

    await tester.ensureVisible(purgeButton);
    await tester.tap(purgeButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-purge-logs-button')));
    await tester.pumpAndSettle();

    expect((await logStore.query()).totalCount, 0);
    expect(find.text('All meditation logs have been purged.'), findsOneWidget);
  });

  testWidgets('log filter icon highlights only while filter is active', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LogsScreen(initialStartDate: DateTime(2026, 5, 1))),
    );
    await tester.pumpAndSettle();

    IconButton filterButton = tester.widget(
      find.byKey(const ValueKey('filter-logs-button')),
    );
    expect(filterButton.color, const Color(0xFF70D878));

    await tester.tap(find.byKey(const ValueKey('filter-logs-button')));
    await tester.pumpAndSettle();

    expect(find.text('Filter logs'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('disable-log-filter-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('disable-log-filter-button')));
    await tester.pumpAndSettle();

    filterButton = tester.widget(
      find.byKey(const ValueKey('filter-logs-button')),
    );
    expect(filterButton.color, Colors.white);
  });

  testWidgets('dirty log edits highlight save and confirm before closing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              key: const ValueKey('open-logs-host-button'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const LogsScreen(),
                  ),
                );
              },
              child: const Text('Open logs'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-logs-host-button')));
    await tester.pumpAndSettle();

    TextButton saveButton = tester.widget(
      find.byKey(const ValueKey('save-logs-button')),
    );
    expect(saveButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('add-log-entry-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('log-duration-minutes-field')),
      '10',
    );
    await tester.enterText(
      find.byKey(const ValueKey('log-preset-field')),
      'Unsaved test',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-add-log-button')));
    await tester.pumpAndSettle();

    saveButton = tester.widget(find.byKey(const ValueKey('save-logs-button')));
    expect(saveButton.onPressed, isNotNull);
    expect(
      saveButton.style?.foregroundColor?.resolve({}),
      const Color(0xFF70D878),
    );

    await tester.tap(find.byKey(const ValueKey('close-logs-button')));
    await tester.pumpAndSettle();

    expect(find.text('Unsaved edits'), findsOneWidget);
    expect(
      find.text(
        'There are unsaved edits. Are you sure you want to close the log screen?',
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('save-leave-logs-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('leave-logs-without-saving-button')),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('View and Edit Logs'), findsOneWidget);
    expect(find.textContaining('Unsaved test'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('close-logs-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-leave-logs-button')));
    await tester.pumpAndSettle();

    expect(find.text('Open logs'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-logs-host-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unsaved test'), findsOneWidget);
  });

  testWidgets('session timer starts running and can be paused', (
    WidgetTester tester,
  ) async {
    final clock = _TestClock();
    await tester.pumpWidget(
      MaterialApp(
        home: MeditationSessionScreen(playBells: false, now: clock.now),
      ),
    );

    expect(find.text('Meditation'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.text('Finish'), findsNothing);

    clock.advance(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('19:50'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.text('Log & Finish early (play bell)'), findsOneWidget);
    expect(find.text('Log & Finish early (no bell)'), findsOneWidget);
    expect(find.text('Discard session'), findsOneWidget);
  });

  testWidgets('session title uses the timer activity', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MeditationSessionScreen(
          playBells: false,
          timer: MeditationTimerPreset(
            id: 'activity-title-test',
            name: 'Activity title test',
            duration: Duration(minutes: 20),
            startingBell: null,
            endingBell: null,
            activity: 'Breathwork',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Breathwork'), findsOneWidget);
    expect(find.text('Meditation'), findsNothing);
  });

  testWidgets('wake lock is enabled during a meditation session and released', (
    WidgetTester tester,
  ) async {
    final wakeLockStates = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MeditationSessionScreen(
          playBells: false,
          setWakeLockEnabled: (enabled) async {
            wakeLockStates.add(enabled);
          },
        ),
      ),
    );
    await tester.pump();

    expect(wakeLockStates, [true]);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.tap(find.text('Discard session'));
    await tester.pump();

    expect(wakeLockStates, [true, false]);
  });

  testWidgets('background timer service starts and stops with session', (
    WidgetTester tester,
  ) async {
    final backgroundService = _FakeBackgroundTimerService();

    await tester.pumpWidget(
      MaterialApp(
        home: MeditationSessionScreen(
          playBells: false,
          backgroundTimerService: backgroundService,
        ),
      ),
    );
    await tester.pump();

    expect(backgroundService.startCount, 1);
    expect(backgroundService.stopCount, 0);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.tap(find.text('Discard session'));
    await tester.pump();

    expect(backgroundService.startCount, 1);
    expect(backgroundService.stopCount, 1);
  });

  testWidgets('meditation display can dim and auto-reveals around bells', (
    WidgetTester tester,
  ) async {
    final clock = _TestClock();

    await tester.pumpWidget(
      MaterialApp(
        home: MeditationSessionScreen(
          now: clock.now,
          onBellPlayed: (_) {},
          timer: const MeditationTimerPreset(
            id: 'display-dim-test',
            name: 'Display dim test',
            duration: Duration(minutes: 2),
            startingBell: null,
            endingBell: BellSound(
              name: 'End',
              assetPath: 'audio/bells/wood-knock.mp3',
            ),
            intermediateBells: [
              IntermediateBell(
                startTime: Duration(seconds: 20),
                bell: BellSound(
                  name: 'Middle',
                  assetPath: 'audio/bells/wood-knock.mp3',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('meditation-screen-toggle-zone')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('meditation-display-dimmed-overlay')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('meditation-display-dimmed-overlay')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('meditation-display-dimmed-overlay')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('meditation-screen-toggle-zone')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('meditation-display-dimmed-overlay')),
      findsOneWidget,
    );

    clock.advance(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));

    expect(
      find.byKey(const ValueKey('meditation-display-dimmed-overlay')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('meditation-screen-toggle-zone')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('meditation-display-dimmed-overlay')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('meditation-display-dimmed-overlay')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('meditation-display-dimmed-overlay')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('meditation-screen-toggle-zone')),
    );
    await tester.pump();

    clock.advance(const Duration(seconds: 41));
    await tester.pump(const Duration(seconds: 41));

    expect(
      find.byKey(const ValueKey('meditation-display-dimmed-overlay')),
      findsOneWidget,
    );
  });

  testWidgets(
    'meditation display does not auto-reveal when preference is off',
    (WidgetTester tester) async {
      final clock = _TestClock();

      await tester.pumpWidget(
        MaterialApp(
          home: MeditationSessionScreen(
            now: clock.now,
            turnScreenOnNearAudio: false,
            onBellPlayed: (_) {},
            timer: const MeditationTimerPreset(
              id: 'display-no-auto-reveal-test',
              name: 'Display no auto reveal test',
              duration: Duration(minutes: 2),
              startingBell: null,
              endingBell: BellSound(
                name: 'End',
                assetPath: 'audio/bells/wood-knock.mp3',
              ),
              intermediateBells: [
                IntermediateBell(
                  startTime: Duration(seconds: 20),
                  bell: BellSound(
                    name: 'Middle',
                    assetPath: 'audio/bells/wood-knock.mp3',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('meditation-screen-toggle-zone')),
      );
      await tester.pump();

      clock.advance(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));

      expect(
        find.byKey(const ValueKey('meditation-display-dimmed-overlay')),
        findsOneWidget,
      );
    },
  );

  testWidgets('meditation display can dim immediately after starting bell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MeditationSessionScreen(playBells: false)),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('meditation-screen-toggle-zone')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('meditation-display-dimmed-overlay')),
      findsOneWidget,
    );
  });

  testWidgets('infinite session counts up from zero', (
    WidgetTester tester,
  ) async {
    final clock = _TestClock();
    await tester.pumpWidget(
      MaterialApp(
        home: MeditationSessionScreen(
          now: clock.now,
          timer: const MeditationTimerPreset(
            id: 'timer-infinite-test',
            name: 'Infinite test',
            duration: null,
            startingBell: BellSound(
              name: 'Start',
              assetPath: 'audio/bells/wood-knock.mp3',
            ),
            endingBell: BellSound(
              name: 'End',
              assetPath: 'audio/bells/wood-knock.mp3',
            ),
          ),
          playBells: false,
        ),
      ),
    );

    expect(find.text('00:00'), findsOneWidget);

    clock.advance(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));

    expect(find.text('00:10'), findsOneWidget);
  });

  testWidgets('paused session can resume and discard exits session', (
    WidgetTester tester,
  ) async {
    final clock = _TestClock();
    await tester.pumpWidget(
      MaterialApp(
        home: MeditationSessionScreen(playBells: false, now: clock.now),
      ),
    );

    clock.advance(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('19:57'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    clock.advance(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('19:56'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.tap(find.text('Discard session'));
    await tester.pump();

    expect(find.text('Breath and Insight Timer'), findsNothing);
    expect(find.text('Timers'), findsWidgets);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
  });

  testWidgets('finish shows summary and continue reports a log entry', (
    WidgetTester tester,
  ) async {
    final clock = _TestClock();
    MeditationLogEntry? loggedEntry;
    final today = DateTime.now();
    await const MeditationLogStore().append(
      MeditationLogEntry(
        id: 'today-summary-seed',
        startedAt: DateTime(today.year, today.month, today.day, 8),
        duration: const Duration(minutes: 10),
        preset: 'Morning',
        activity: 'Meditation',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MeditationSessionScreen(
          now: clock.now,
          playBells: false,
          onSessionFinished: (entry) {
            loggedEntry = entry;
          },
        ),
      ),
    );

    clock.advance(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.tap(find.text('Log & Finish early (no bell)'));
    await tester.pumpAndSettle();

    expect(loggedEntry, isNull);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('You completed:'), findsOneWidget);
    expect(find.text('00:04'), findsOneWidget);
    expect(find.text('Total time today:'), findsOneWidget);
    expect(find.text('10:04'), findsOneWidget);
    expect(find.text('Your streak today is:'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('summary-continue-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('summary-discard-button')),
      findsOneWidget,
    );
    expect(find.text('Finish'), findsOneWidget);
    expect(find.text('Discard session (delete log)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('summary-continue-button')));
    await tester.pumpAndSettle();

    expect(loggedEntry, isNotNull);
    expect(loggedEntry?.preset, 'Quick 20 minutes');
    expect(loggedEntry?.activity, 'Meditation');
    expect(loggedEntry?.duration, const Duration(seconds: 4));
    expect(find.text('Breath and Insight Timer'), findsNothing);
    expect(find.text('Timers'), findsWidgets);
    expect(find.text('Stats'), findsOneWidget);
  });

  testWidgets(
    'summary finish returns while detached ending bell keeps playing',
    (WidgetTester tester) async {
      final clock = _TestClock();
      final detachedBells = <String>[];
      MeditationLogEntry? loggedEntry;

      await tester.pumpWidget(
        MaterialApp(
          home: MeditationSessionScreen(
            now: clock.now,
            onDetachedEndingBellRequested: (bell) {
              detachedBells.add(bell.name);
            },
            onSessionFinished: (entry) {
              loggedEntry = entry;
            },
            timer: const MeditationTimerPreset(
              id: 'detached-ending-bell-session',
              name: 'Detached ending bell session',
              duration: Duration(minutes: 20),
              startingBell: null,
              endingBell: BellSound(
                name: 'End',
                assetPath: 'audio/bells/wood-knock.mp3',
              ),
            ),
          ),
        ),
      );

      clock.advance(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      await tester.tap(find.text('Log & Finish early (play bell)'));
      await tester.pumpAndSettle();

      expect(detachedBells, ['End']);
      expect(loggedEntry, isNull);
      expect(find.text('Summary'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('summary-continue-button')));
      await tester.pumpAndSettle();

      expect(loggedEntry, isNotNull);
      expect(find.text('Timers'), findsWidgets);
    },
  );

  testWidgets('preparation time delays starting bell and meditation clock', (
    WidgetTester tester,
  ) async {
    final clock = _TestClock(DateTime(2026, 7, 28, 6));
    final playedBells = <String>[];
    MeditationLogEntry? loggedEntry;

    await tester.pumpWidget(
      MaterialApp(
        home: MeditationSessionScreen(
          now: clock.now,
          onBellPlayed: (bell) => playedBells.add(bell.name),
          onSessionFinished: (entry) {
            loggedEntry = entry;
          },
          timer: const MeditationTimerPreset(
            id: 'preparation-session',
            name: 'Preparation session',
            duration: Duration(seconds: 3),
            preparationDuration: Duration(seconds: 2),
            startingBell: BellSound(
              name: 'Start',
              assetPath: 'audio/bells/wood-knock.mp3',
            ),
            endingBell: BellSound(
              name: 'End',
              assetPath: 'audio/bells/wood-knock.mp3',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Preparation'), findsOneWidget);
    expect(find.text('00:02'), findsOneWidget);
    expect(playedBells, isEmpty);

    clock.advance(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Preparation'), findsOneWidget);
    expect(find.text('00:01'), findsOneWidget);
    expect(playedBells, isEmpty);

    clock.advance(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(playedBells, ['Start']);
    expect(find.text('Preparation'), findsNothing);
    expect(find.text('00:03'), findsOneWidget);

    clock.advance(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('00:02'), findsOneWidget);

    clock.advance(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(playedBells, ['Start', 'End']);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('You completed:'), findsOneWidget);
    expect(find.text('00:03'), findsWidgets);
    expect(loggedEntry, isNull);

    await tester.tap(find.byKey(const ValueKey('summary-continue-button')));
    await tester.pumpAndSettle();

    expect(loggedEntry, isNotNull);
    expect(loggedEntry?.duration, const Duration(seconds: 3));
    expect(loggedEntry?.startedAt, DateTime(2026, 7, 28, 6, 0, 2));
  });

  testWidgets('natural timed completion plays ending bell and shows summary', (
    WidgetTester tester,
  ) async {
    final clock = _TestClock();
    final playedBells = <String>[];
    MeditationLogEntry? loggedEntry;

    await tester.pumpWidget(
      MaterialApp(
        home: MeditationSessionScreen(
          now: clock.now,
          playBells: false,
          onBellPlayed: (bell) => playedBells.add(bell.name),
          onSessionFinished: (entry) {
            loggedEntry = entry;
          },
          timer: const MeditationTimerPreset(
            id: 'short-natural-session',
            name: 'Short natural session',
            duration: Duration(seconds: 3),
            startingBell: BellSound(
              name: 'Start',
              assetPath: 'audio/bells/wood-knock.mp3',
            ),
            endingBell: BellSound(
              name: 'End',
              assetPath: 'audio/bells/wood-knock.mp3',
            ),
          ),
        ),
      ),
    );

    clock.advance(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(playedBells, ['End']);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('You completed:'), findsOneWidget);
    expect(find.text('00:03'), findsWidgets);
    expect(find.text('Total time today:'), findsOneWidget);
    expect(find.text('Your streak has increased to:'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(loggedEntry, isNull);

    await tester.tap(find.byKey(const ValueKey('summary-discard-button')));
    await tester.pumpAndSettle();

    expect(loggedEntry, isNull);
    expect(find.text('Timers'), findsWidgets);
  });
}

String _weekdayInitialForTest(DateTime dateTime) {
  return switch (dateTime.weekday) {
    DateTime.monday => 'M',
    DateTime.tuesday => 'T',
    DateTime.wednesday => 'W',
    DateTime.thursday => 'T',
    DateTime.friday => 'F',
    DateTime.saturday => 'S',
    DateTime.sunday => 'S',
    _ => '',
  };
}

String _dateOnlyForTest(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '$month/$day/${dateTime.year}';
}

String _weekLabelForTest(DateTime dateTime) {
  final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final weekStart = DateTime(
    date.year,
    date.month,
    date.day - (date.weekday - DateTime.monday),
  );
  final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
  if (weekStart.month == weekEnd.month) {
    final firstDayOfMonth = DateTime(weekStart.year, weekStart.month);
    final daysUntilFirstMonday =
        (DateTime.monday - firstDayOfMonth.weekday) % 7;
    final firstFullWeekStart = DateTime(
      firstDayOfMonth.year,
      firstDayOfMonth.month,
      firstDayOfMonth.day + daysUntilFirstMonday,
    );
    if (weekStart == firstFullWeekStart) {
      return _monthAbbreviationForTest(weekStart.month);
    }
  }

  return weekStart.day.toString();
}

String _monthAbbreviationForTest(int month) {
  return const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}

class _TestClock {
  _TestClock([DateTime? initialNow]) : _now = initialNow ?? DateTime.now();

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

class _FakeBackgroundTimerService extends BackgroundTimerService {
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<bool> start() async {
    startCount += 1;
    return true;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }
}
