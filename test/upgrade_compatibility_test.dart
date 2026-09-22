import 'dart:convert';

import 'package:breath_and_insight_timer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _segmentedPreset = PranayamaPreset(
  id: 'saved-breathing',
  name: 'Saved breathing',
  segments: [
    PranayamaSegment(
      id: 'first',
      duration: Duration(seconds: 10),
      inBreath: Duration(seconds: 2),
      firstHold: Duration.zero,
      outBreath: Duration(seconds: 2),
      secondHold: Duration.zero,
    ),
    PranayamaSegment(
      id: 'last',
      duration: Duration(seconds: 7),
      inBreath: Duration(seconds: 3),
      firstHold: Duration.zero,
      outBreath: Duration(seconds: 3),
      secondHold: Duration.zero,
    ),
  ],
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('timed audio chunks stop at each rounded segment boundary', () {
    const window = Duration(seconds: 45);
    expect(
      pranayamaAudioChunkCycleCountForTesting(
        _segmentedPreset,
        Duration.zero,
        window,
      ),
      3,
    );
    expect(
      pranayamaAudioChunkCycleCountForTesting(
        _segmentedPreset,
        const Duration(seconds: 8),
        window,
      ),
      1,
    );
    expect(
      pranayamaAudioChunkCycleCountForTesting(
        _segmentedPreset,
        const Duration(seconds: 12),
        window,
      ),
      2,
    );
    expect(
      pranayamaAudioChunkCycleCountForTesting(
        _segmentedPreset,
        const Duration(seconds: 18),
        window,
      ),
      1,
    );
    expect(
      pranayamaAudioChunkCycleCountForTesting(
        _segmentedPreset,
        const Duration(seconds: 8),
        window,
        forcedSegmentIndex: 0,
      ),
      11,
    );
  });

  testWidgets('upgrade preserves saved data and keeps remote control opt-in', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // These are the existing 1.0.4 storage keys and JSON structures.
    final saved = <String, Object>{
      'soundEnabled': false,
      'turnScreenOnNearAudio': false,
      'recentTimerLimit': 4,
      'recentTimersCollapsed': true,
      'recentPranayamaCollapsed': true,
      'recentTimerIds': jsonEncode(['saved-timer']),
      'recentPranayamaPresetIds': jsonEncode(['saved-breathing']),
      'timerEntries': jsonEncode([
        {
          'type': 'folder',
          'folder': 'My timers',
          'timers': [
            {
              'id': 'saved-timer',
              'name': 'My evening timer',
              'note': 'Keep me',
              'activity': 'Sitting',
              'durationSeconds': 1200,
              'preparationSeconds': 15,
              'startingBell': 'audio/bells/wood-knock.mp3',
              'endingBell': 'audio/bells/singing-bowl--long--2.mp3',
              'intermediateBells': [
                {
                  'startTimeSeconds': 300,
                  'bell': 'audio/bells/wood-knock.mp3',
                  'repeatIntervalSeconds': null,
                },
              ],
            },
          ],
        },
      ]),
      'pranayamaEntries': jsonEncode([
        {
          'type': 'preset',
          'preset': {
            'id': 'saved-breathing',
            'name': 'Saved breathing',
            'note': 'Custom sequence',
            'segments': [
              for (final segment in _segmentedPreset.segments)
                {
                  'id': segment.id,
                  'durationSeconds': segment.duration!.inSeconds,
                  'inBreathSeconds': segment.inBreath.inSeconds,
                  'firstHoldSeconds': 0,
                  'outBreathSeconds': segment.outBreath.inSeconds,
                  'secondHoldSeconds': 0,
                },
            ],
          },
        },
      ]),
      'meditationLogs': jsonEncode([
        {
          'id': 'saved-log',
          'startedAt': '2026-09-20T18:00:00.000',
          'durationSeconds': 1200,
          'preset': 'My evening timer',
          'activity': 'Sitting',
        },
      ]),
    };
    SharedPreferences.setMockInitialValues(saved);
    var now = DateTime(2026, 9, 22, 12);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(now: () => now)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My timers'));
    await tester.pumpAndSettle();
    expect(find.text('My evening timer'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('pranayama-remote-control-switch')),
          )
          .value,
      isFalse,
    );
    final preferences = await SharedPreferences.getInstance();
    for (final entry in saved.entries) {
      expect(preferences.get(entry.key), entry.value, reason: entry.key);
    }
    final logs = await const MeditationLogStore().allEntries();
    expect(logs.single.id, 'saved-log');
    expect(logs.single.duration, const Duration(minutes: 20));

    await tester.tap(find.byKey(const ValueKey('pranayama-tab-button')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('pranayama-Saved breathing-root')),
    );
    await tester.pump();
    expect(find.text('2.0s'), findsNWidgets(2));
    now = now.add(const Duration(seconds: 12));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('3.0s'), findsNWidgets(2));
    now = now.add(const Duration(seconds: 12));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Ready'), findsOneWidget);
    expect(
      preferences.getString('pranayamaEntries'),
      saved['pranayamaEntries'],
    );
    expect(preferences.getString('timerEntries'), saved['timerEntries']);
    expect(
      (await const MeditationLogStore().allEntries()).single.id,
      'saved-log',
    );
  });
}
