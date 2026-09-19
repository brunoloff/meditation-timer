import 'package:breath_and_insight_timer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> seedDays(List<int> offsets, {bool zeroMinutes = false}) async {
    final today = DateTime.now();
    await const MeditationLogStore().applyChanges(
      additions: [
        for (var index = 0; index < offsets.length; index++)
          MeditationLogEntry(
            id: 'streak-$index',
            startedAt: DateTime(
              today.year,
              today.month,
              today.day - offsets[index],
              12,
            ),
            duration: Duration(minutes: zeroMinutes ? 0 : 20),
            preset: 'Practice',
            activity: 'Meditation',
          ),
      ],
      deletedIds: {},
    );
  }

  Future<void> openStats(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('stats-tab-button')));
    await tester.pumpAndSettle();
  }

  void expectStreak(WidgetTester tester, int days) {
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('streak-length-value')))
          .data,
      '$days',
    );
  }

  testWidgets('summary and stats agree on the 1000th practice day', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seedDays([for (var day = 1; day <= 999; day++) day]);
    await tester.pumpWidget(
      MaterialApp(home: MeditationSessionScreen(playBells: false)),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.tap(find.text('Log & Finish early (no bell)'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('summary-value-Your streak has increased to:'),
            ),
          )
          .data,
      '1000',
    );
    await tester.tap(find.byKey(const ValueKey('summary-continue-button')));
    await tester.pumpAndSettle();
    await openStats(tester);
    expectStreak(tester, 1000);
  });

  for (final scenario in [
    (name: 'no logs', days: <int>[], expected: 0),
    (name: 'before today\'s first session', days: [1, 2, 3], expected: 3),
    (name: 'today only', days: [0], expected: 1),
    (name: 'multiple sessions today', days: [0, 0, 1, 2], expected: 3),
    (name: 'a gap yesterday', days: [0, 2, 3], expected: 1),
    (name: 'a broken streak', days: [2, 3], expected: 0),
    (
      name: 'future logs do not extend the streak',
      days: [-1, 0, 1],
      expected: 2,
    ),
  ]) {
    testWidgets('stats streak handles ${scenario.name}', (tester) async {
      await seedDays(scenario.days);
      await tester.pumpWidget(const BreathAndInsightTimerApp());
      await tester.pump();
      await openStats(tester);
      expectStreak(tester, scenario.expected);
    });
  }

  testWidgets('repair and streak details include a zero-minute log today', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seedDays([0, 1, 3], zeroMinutes: true);
    await tester.pumpWidget(const BreathAndInsightTimerApp());
    await tester.pump();
    await openStats(tester);
    expectStreak(tester, 2);
    await tester.tap(find.byKey(const ValueKey('streak-details-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Zero-minute days: 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('repair-streak-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('rise from 2 to 4.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirm-repair-streak-button')),
    );
    await tester.pumpAndSettle();
    expectStreak(tester, 4);
    expect(find.text('Zero-minute days: 4'), findsWidgets);
  });
}
