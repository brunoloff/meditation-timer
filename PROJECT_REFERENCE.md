# Bruno's Meditation Timer Project Reference

This document is for future development sessions. It records what the app does,
where the main code lives, and the design choices that are easiest to lose after
context resets.

## Product Shape

Bruno's Meditation Timer is a Flutter app for meditation and breath practice.
The current target platforms are Android and iOS, with Linux/Chrome useful for
development testing.

The app has four top-level tabs:

- Timers
- Pranayama
- Stats
- Settings

The tab bar scrolls away with the page content. Full-screen flows such as
meditation sessions, timer editing, pranayama preset editing, sound selection,
and log editing hide the tab bar.

The visual style is intentionally quiet:

- Black tab bar.
- Near-black gray content surface.
- White primary text.
- Muted gray secondary text.
- Simple list rows and small icon controls.
- No marketing page, hero section, or decorative artwork inside the app.

## File Map

The app still uses Dart `part` files under a single library rooted at
`lib/main.dart`.

- `lib/main.dart`
  - Imports packages and declares the app.
  - Owns the `part` declarations for the rest of the app.

- `lib/main_screen.dart`
  - Owns the home tabs and most cross-tab state.
  - Important: pranayama session state lives here so it survives route pushes
    while the user starts a meditation timer.
  - Handles settings actions such as logs import/export, preset import/export,
    reinstalling default presets, background guide links, and sound toggles.

- `lib/timer_data.dart`
  - Timer model types.
  - Bell sound constants.
  - Default timer presets.
  - Shared constants and home tab enum.

- `lib/tabs.dart`
  - Timers tab, Stats tab, Settings tab, timer list rows, timer JSON
    encoding/decoding, and stats charts.

- `lib/pranayama_data.dart`
  - Pranayama model types.
  - Default pranayama presets.
  - Effective pranayama duration logic.
  - Procedural pranayama tone generation.

- `lib/pranayama_tab.dart`
  - Pranayama tab UI.
  - Inline pranayama guide widget and graph painter.
  - Pranayama preset editor.
  - Pranayama list persistence encoding/decoding.

- `lib/edit_timer_screen.dart`
  - Timer create/edit screen.
  - Duration normalization.
  - Start, end, and intermediate bell editing.

- `lib/select_sound_screen.dart`
  - Sound selection screen.
  - Loads `assets/audio/bells/default-sounds.json`.
  - Provides tag filtering and preview playback.

- `lib/meditation_screen.dart`
  - Running meditation session screen.
  - Pause, finish, discard, summary screen.
  - Bell playback, wake lock, background timer service integration.

- `lib/meditation_logs.dart`
  - Log model and persistence.
  - CSV import/export compatible with the imported Insight Timer style CSV.
  - Duplicate log detection.

- `lib/logs_screen.dart`
  - View and edit logs screen.
  - Lazy/paged browsing, filtering, unsaved edit handling.

- `lib/background_timer_service.dart`
  - Android background execution wrapper.
  - Ref-counted because meditation and pranayama can run at the same time.

- `assets/default-presets.json`
  - Public JSON bundle for reinstalling defaults.
  - Reuses the same timer/pranayama entry JSON shapes used by persistence.

- `assets/audio/bells/default-sounds.json`
  - Public metadata for bundled bell sounds.

## Timers

A meditation timer has:

- `id`
- `name`
- `note`
- `activity`
- `duration`, where `null` means infinite
- optional starting bell
- optional ending bell
- ordered intermediate bells

Intermediate bells have:

- first ring time
- bell sound
- optional repeat interval

Intermediate bell precedence matters. On a given second, if several intermediate
bells are due, only the first in the timer's ordered list plays. Starting and
ending bells take precedence over intermediate bells at `0:00` and at the end.

Default timers:

- `Infinite meditation`
  - Infinite duration.
  - Note: `Bells every 5m`.
  - Starting bell: High and Long Meditation Bell.
  - Ending bell: Low and Long Singing Bowl.
  - Intermediate bells:
    - Wahwah Bowl every 30 minutes.
    - Hard-Struck Bowl in E-flat every 15 minutes.
    - Knock on wood every 5 minutes.

- `Quick 20 minutes`
  - 20 minute duration.
  - Same start and end bells as above.
  - No intermediate bells.

- `Long sessions`
  - Folder containing `1 hour`.
  - Same start and end bells as above.
  - No intermediate bells.

The Timers tab has:

- Recent timers, backed by stable timer IDs.
- Editable timer/folder list.
- A single folder level.
- Drag reordering across top level and folders.
- Folder rename and deletion.
- Timer deletion with confirmation.

## Meditation Sessions

The meditation screen shows:

- Top title: the timer's `activity` field.
- Center time:
  - Finite timers count down.
  - Infinite timers count up.
- Pause button while running.
- Resume, finish, and discard controls while paused.

Finish behavior:

- Timed natural completion always plays the ending bell and then shows summary.
- Manual `Log & Finish` can play the ending bell or skip the bell.
- Discard never logs and does not play the ending bell.
- For finite timers, buttons say `Log & Finish early`.
- For infinite timers, buttons say `Log & Finish`.
- If an ending bell is still ringing on the summary screen, the final `Finish`
  action waits for it to complete before leaving the route.

After a non-discarded finish, the summary screen shows:

- Completed duration.
- Total practice time today.
- Streak language and streak length.
- Finish.
- Discard session (delete log).

The session is logged only when the user finishes from summary. Discarding from
summary deletes the pending log entry.

Important route detail:

When a meditation session ends and it was pushed from `HomeScreen`, it pops the
route instead of constructing a fresh `HomeScreen`. This preserves concurrent
pranayama state and audio.

## Screen Dimming And Wake Behavior

Meditation sessions enable wake lock while active.

During a meditation screen:

- Tapping the screen outside the pause button toggles a black overlay.
- This is meant as a battery-saving dim state.
- The screen can auto-reveal around bells.
- The preference `Turn screen back on near playing audio` controls that
  auto-reveal behavior.

The app uses `wakelock_plus` for wake lock and `flutter_background` for Android
background execution.

## Pranayama

The Pranayama tab can run a pranayama session inline without leaving the tab.
This is intentional: users can start pranayama, switch to Timers, and start a
meditation timer at the same time.

A pranayama preset has:

- `id`
- `name`
- `note`
- `duration`, where `null` means infinite
- in-breath seconds
- first hold seconds
- out-breath seconds
- second hold seconds

Default pranayama presets include:

- `6 in 8 out`
- `Gentle breath`
- `Balancing`
  - `Box breathing`
- `Forrest Knutson`
  - `4/5 HRV Breathing`, 15 minutes.
  - `5/6 HRV Breathing`, 15 minutes.
  - `6/7 HRV Breathing`, 15 minutes.
  - `4/5/6 BPV Breathing`, 15 minutes.

The pranayama guide graph:

- Has a dashed red lead-in segment.
- Has a solid active breath shape.
- Has a dashed red lead-out segment.
- Uses proportional segment widths based on phase durations.
- Uses a green dot during the active breath cycle.
- Uses red dots for lead-in and lead-out transition periods.
- Does not show a lead-out red dot on the first cycle.
- Does not show a lead-in red dot before the last finite cycle.

Finite pranayama sessions do not stop mid-cycle. The effective duration is the
first complete breath-cycle boundary at or after the requested duration.

## Pranayama Audio

Pranayama audio is procedurally generated in memory.

There are no required pranayama audio asset files. Earlier generated WAV files
such as `inhale-tone.wav` and `exhale-tone.wav` are obsolete leftovers if they
appear untracked in the workspace.

The current implementation generates one full breath-cycle WAV byte buffer:

- Inhale tone.
- First hold silence.
- Exhale tone.
- Second hold silence.

Why one full cycle?

- Separate inhale/exhale clip scheduling caused clipping and phase-boundary
  glitches, especially for no-hold presets.
- A single generated loop lets fade-in and fade-out be baked into the waveform.
- The audio player only needs to loop one already-buffered source.

Why the small startup delay?

- On some backends, the first `play` call resolves before audible playback is
  fully aligned with the visual clock.
- The app starts the visual clock only after the audio command completes and a
  tiny warmup delay has passed.
- Generation counters make stale async audio startup harmless if the user
  pauses, stops, or changes presets during startup.

## Bells And Sounds

Bell sound metadata lives in `assets/audio/bells/default-sounds.json`.

Bell assets are selected through a dedicated sound-selection screen rather than
plain dropdowns. The screen supports:

- None.
- Sound list.
- Tag filters.
- Preview playback.

Timer sound fields that use the selector:

- Starting bell.
- Ending bell.
- Intermediate bell.

Bundled sound constants also exist in `lib/timer_data.dart` so timers can refer
to known sounds without loading JSON first.

## Logs

Meditation log entries have:

- `id`
- `startedAt`
- `duration`
- `preset`
- `activity`

Logs are persisted via `SharedPreferences`.

CSV import/export is compatible with the imported Insight Timer style CSV:

- `Started At`
- `Duration`
- `Preset`
- `Activity`

Import skips duplicates. Duplicate detection is based on stable log identity
fields rather than just CSV row position.

The View and Edit Logs screen:

- Is its own route.
- Has close, save, and filter controls.
- Supports date filtering.
- Highlights unsaved changes.
- Confirms before leaving with unsaved edits.
- Browses logs lazily in pages so thousands of entries remain reasonable.

## Stats

The Stats tab currently includes:

- Open logs button near the top.
- Streak length.
- Expandable streak details.
- Repair streak action.
- Days, Weeks, Months chart selector.
- Optional per-day averaging for weeks and months.
- Bar chart using `fl_chart`.
- Summary statistics for the current streak and all data.

Current streak definition:

- Count consecutive days before/today according to the app's current logic where
  there is at least one log entry.
- A zero-minute log can repair a missing day.

Streak repair:

- Adds a zero-minute log entry on the last empty day before the current streak.
- The dialog previews the new streak length before confirming.

## Settings

Settings currently includes:

- Sound on/off.
- Test sound.
- Turn screen back on near playing audio.
- Background timer support.
- Background setup guide link.
- Recent timer count.
- Presets:
  - Reinstall default presets.
  - Import presets JSON.
  - Export presets JSON.
- Logs:
  - Import logs CSV.
  - Export logs CSV.
  - Purge all logs.
- About:
  - Acknowledgements.

Preset import/reinstall behavior:

- Uses the same JSON shape as persistence.
- Conflicts are detected by preset title, not ID.
- If conflicts exist, the app asks once whether to override all or ignore all.
- Missing imported presets are added.
- Missing folders are recreated only when needed.
- Existing unrelated user folders and presets are left alone.

## Persistence

The app uses `SharedPreferences` for the current alpha.

Important keys:

- `recentTimersCollapsed`
- `recentPranayamaCollapsed`
- `recentTimerIds`
- `recentPranayamaPresetIds`
- `recentTimerLimit`
- `soundEnabled`
- `turnScreenOnNearAudio`
- `timerEntries`
- `pranayamaEntries`
- `meditationLogs`

Persistence decoder strategy:

- Preset/browser trees are decoded all-or-nothing.
- Corrupt timer/pranayama browser trees fall back to defaults.
- Logs skip malformed individual entries, because preserving the rest of a long
  history is more important than rejecting everything.
- Negative imported/persisted durations are rejected.

Save-generation counters prevent older async saves from overwriting newer edits
after rapid reorder/edit operations.

## Background Execution

The app tries to keep sessions running if the phone screen is off or the app is
backgrounded.

Implementation notes:

- `BackgroundTimerService` wraps `flutter_background`.
- The service returns false on unsupported platforms rather than throwing.
- A static request count protects overlapping meditation and pranayama sessions.
- Background execution is only disabled when the final active requester stops.
- Users may still need OS-level battery/background permission adjustments.

The Settings tab includes a guide link to `https://dontkillmyapp.com/`.

## Testing

Run:

```sh
fvm flutter analyze
fvm flutter test
```

Useful tests cover:

- Tab switching.
- Timer editing, deleting, folder operations, reordering.
- Sound selection.
- Intermediate bell precedence.
- Meditation session pause/finish/summary/logging.
- Wake lock and background service calls.
- Screen dimming and reveal behavior.
- Logs import/export/purge/filter/dirty-state behavior.
- Stats chart/streak display.
- Pranayama inline sessions.
- Pranayama plus meditation route round trip.
- Default preset reinstall.

## Development Notes For Future Sessions

- Use `rg` for code search.
- Prefer keeping alpha changes small and covered by widget tests.
- Be careful not to replace the existing `HomeScreen` when ending pushed routes.
- Be careful with pranayama audio. The generation counters and warmup delay are
  there because real backends behaved badly without them.
- Do not reintroduce separate inhale/exhale audio clips unless there is a very
  strong reason and device testing proves it is stable.
- Do not assume a single active timer. Meditation and pranayama can overlap.
- If adding a new preset field, update:
  - Model class.
  - Editor.
  - Persistence encoder/decoder.
  - `assets/default-presets.json`.
  - Import/export merge behavior if needed.
  - Widget tests.
- If adding a new sound field, route it through `SelectSoundScreen`.
- If changing default presets, update both Dart defaults and
  `assets/default-presets.json` unless the default-loading strategy changes.
- Keep comments focused on invariants and platform quirks, not on obvious widget
  layout.
