import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:breath_and_insight_timer/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('home screen opens on timers tab and can switch tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    expect(find.text('Breath and Insight Timer'), findsNothing);
    expect(find.text('Timers'), findsWidgets);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('Recent timers'), findsOneWidget);
    expect(find.text('20 minutes'), findsWidgets);
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
    expect(find.text('Test sound'), findsOneWidget);
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

    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
    await tester.pumpAndSettle();

    soundSwitch = tester.widget(
      find.byKey(const ValueKey('sound-enabled-switch')),
    );
    expect(soundSwitch.value, isFalse);
  });

  testWidgets('recent timers can be minimized and folders can expand', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();

    expect(find.text('Recent timers'), findsOneWidget);
    expect(find.text('1 hour'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recent-timers-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('1 hour'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('folder-Long sessions')));
    await tester.pumpAndSettle();

    expect(find.text('1 hour'), findsOneWidget);
  });

  testWidgets('session timer starts running and can be paused', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MeditationSessionScreen(playBells: false)),
    );

    expect(find.text('Meditation'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.text('Finish'), findsNothing);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('19:50'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
    expect(find.text('Discard session'), findsOneWidget);
  });

  testWidgets('infinite session counts up from zero', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MeditationSessionScreen(
          timer: MeditationTimerPreset(
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

    await tester.pump(const Duration(seconds: 10));

    expect(find.text('00:10'), findsOneWidget);
  });

  testWidgets('paused session can resume and discard exits session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MeditationSessionScreen(playBells: false)),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('19:57'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
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

  testWidgets('finish exits session without logging yet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MeditationSessionScreen(playBells: false)),
    );

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.tap(find.text('Finish'));
    await tester.pump();

    expect(find.text('Breath and Insight Timer'), findsNothing);
    expect(find.text('Timers'), findsWidgets);
    expect(find.text('Stats'), findsOneWidget);
  });
}
