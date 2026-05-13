# Bruno's Meditation Timer

Bruno's Meditation Timer is a simple, offline Flutter app for meditation and
pranayama practice. It supports meditation timer presets with bells, guided
pranayama presets, local session logs, CSV import/export, streak tracking, and
basic practice statistics.

The Android launcher label is `Meditation Timer`.

## License

The app source code is licensed under the GNU General Public License version 3.
See [LICENSE](LICENSE).

Bundled bell sounds are listed in
[assets/audio/bells/default-sounds.json](assets/audio/bells/default-sounds.json)
with source URLs and license notes. Most bundled sounds are CC0 Freesound
assets; one bundled bell uses the Pixabay Content License and is included only
as an app sound, not redistributed as standalone content.

## Privacy

The app is designed to work offline. It does not require an account and does not
include ads, analytics, crash reporting SDKs, or tracking services.

The only network-facing behavior in the app is user-initiated link opening from
the acknowledgements and background-timer help screens.

## F-Droid Preparation

The repository includes Fastlane metadata under
[fastlane/metadata/android/en-US](fastlane/metadata/android/en-US).

For an F-Droid submission, the source repository must be publicly reachable and
tagged. The F-Droid metadata in fdroiddata should use the full commit hash for
the release commit rather than relying only on a branch or tag name.

Useful local checks:

```sh
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
```

Release APKs are left unsigned by the checked-in Android Gradle configuration so
F-Droid can build and sign them in its own environment.
