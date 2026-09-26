# iOS build and testing

The iOS preparation work lives on `codex/ios-validation`. It does not publish an
App Store release or change the Android/F-Droid release. The Flutter version is
read from `.fvmrc`; dependencies remain pinned by `pubspec.lock`.

## Automated checks from Linux

The `iOS validation` GitHub Actions workflow uses a standard hosted macOS runner,
Xcode, CocoaPods and CMake. No Apple account or signing secrets are required.
It runs analysis and the existing regression tests, compiles an unsigned ARM64
iPhone release, and runs `integration_test/ios_smoke_test.dart` on a disposable
iPhone simulator with the actual native plugins, not mocks.

The smoke test exercises meditation start/pause/finish, summary and log storage,
generated pranayama audio, segment transitions, pause/resume, navigation between
tabs, natural completion, stats, and saved preferences. Native SoLoud voice and
engine-clock checks detect silent fallback after initialization failures. These
checks do not measure sound quality or acoustic synchronization.

The existing breathing scheduler queues whole cycles only. After a mid-cycle
pause/resume it can remain silent until the next cycle boundary; if paused in
the final cycle, there may be no further tone before completion. The native test
checks resumption at the next boundary, not instantaneous mid-tone resumption.
This behavior is shared with the other platforms and merits a separate audio
follow-up if seamless pause/resume is required.

Artifacts include the unsigned device app, a simulator app, screenshots, the
resolved CocoaPods lockfile, and integration test output. Artifacts expire after
14 days; download any needed for long-term comparison.

**An unsigned device app is not installable on an ordinary iPhone.** The simulator
app only runs on a Mac with a compatible iOS Simulator. Neither is a TestFlight
release or a signed IPA.

## Reproduce on a Mac

Install Xcode and its iOS platform/simulator, CocoaPods, CMake, and the Flutter
version in `.fvmrc`. Keep using CocoaPods for this validated configuration:

```sh
flutter config --no-enable-swift-package-manager
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --release --no-codesign --no-pub
```

For simulator tests, create a **disposable** simulator and obtain its ID with
`flutter devices`. The smoke test clears app preferences and logs. Do not run it
against an installation containing personal data.

```sh
flutter drive --no-pub --dart-define=DISPOSABLE_TEST_DEVICE=true \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/ios_smoke_test.dart -d SIMULATOR_ID
```

For manual simulator use instead:

```sh
flutter run -d SIMULATOR_ID
```

## iOS-specific configuration

- iOS 14 is the minimum supported version (required by the file-picker plugin).
  `ios/Podfile` disables optional prebuilt Xiph codecs with
  `NO_XIPH_LIBS=1`. MP3 bells and generated WAV audio do not need those codecs.
- The host AppDelegate registers an audio-session channel with Flutter's implicit
  engine. Playback activates an `AVAudioSession` using the playback category;
  it mixes with other audio, does not request microphone access, and is eligible
  for background playback via `UIBackgroundModes: audio`.
- File import filters supply Apple's uniform type identifiers as well as the
  extensions used by other platforms.
- Android background permission and accessibility setup links are hidden on iOS.
  Meditation has an explicit back button on iOS to minimize a running session,
  since iPhones do not have Android's system Back button.
- The existing iOS bundle identifier is
  `com.breathandinsight.breathAndInsightTimer`. A publisher must register an
  appropriate identifier and select their signing team before device distribution.
  Do not change an already-distributed bundle identifier without migration planning.

## Still required before an iPhone release

The following are not established by a simulator build:

1. **Physical-device audio:** listen to all bells and both breathing tones; test
   sustained audio/visual synchronization, pauses and segment transitions, speaker
   and Bluetooth headphones, interruptions/calls, and reconnecting audio devices.
2. **Locked-screen behavior:** active audio is configured for background playback,
   but `BackgroundTimerService` is Android-only. A silent meditation interval is
   not guaranteed to keep Dart timers running on iOS. Background bell scheduling
   needs a separate iOS implementation and real-device verification. Do not claim
   Android-equivalent locked-screen timer behavior based on these checks.
3. **Bluetooth ring:** Android's native media/accessibility/touch bridges do not
   exist on iOS. Flutter keyboard events may work with some devices while focused,
   but the ring and lock-screen controls have not been validated or ported.
4. **Files and lifecycle:** use the native Files interface to import/export CSV and
   JSON, reopen the app to check persisted logs/presets, and test an in-place upgrade.
5. **Usability:** small/large iPhones, iPad, rotation, large text, VoiceOver, safe
   areas, and the on-screen keyboard in every editor.
6. **Distribution:** signing/provisioning, TestFlight or publisher onboarding,
   privacy/store metadata, screenshots, licence review, and store approval.

No signing keys, certificates, Apple account passwords, or provisioning profiles
belong in this public repository. Use protected CI secrets for a future signed
distribution workflow, and never expose them to untrusted pull requests.
