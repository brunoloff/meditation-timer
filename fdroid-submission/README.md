# F-Droid Submission Notes

This directory contains a draft fdroiddata metadata file for:

`com.wordpress.brunoloff.meditationtimer`

Copy the YAML file into your fdroiddata fork at:

`metadata/com.wordpress.brunoloff.meditationtimer.yml`

## Upstream Release

The app repository is:

`https://github.com/brunoloff/meditation-timer.git`

The release metadata currently targets:

- version name: `1.0.5`
- base build number: `6`
- ABI version codes: `61`, `62`, `63`
- tag: `v1.0.5`

The in-repository template references the release tag to avoid embedding its own
commit hash. Before submitting to fdroiddata, resolve it with
`git rev-list -n 1 v1.0.5` and use that full hash in the three new build entries.
Do not change the older build entries or move a published release tag.

## Official F-Droid Workflow Summary

The official quick-start guide says to:

1. Register on GitLab and fork `https://gitlab.com/fdroid/fdroiddata`.
2. Clone your fdroiddata fork.
3. Create a new branch named after the app id.
4. Add `metadata/<applicationId>.yml`.
5. Clone `fdroidserver`.
6. Run the fdroidserver build container with both repos mounted.
7. Inside the container, run:
   - `fdroid readmeta`
   - `fdroid rewritemeta <applicationId>`
   - `fdroid checkupdates --allow-dirty <applicationId>`
   - `fdroid lint <applicationId>`
   - `fdroid build <applicationId>`
8. Commit the metadata file in your fdroiddata fork and open a merge request.

See:

- https://f-droid.org/docs/Submitting_to_F-Droid_Quick_Start_Guide/
- https://f-droid.org/docs/Inclusion_How-To/
- https://f-droid.org/docs/Build_Metadata_Reference/

## Notes

The app repo pins the Flutter version in `.github/workflows/release.yml`:

`flutter-version: '3.44.1'`

The fdroiddata metadata uses `srclibs: flutter@stable`, extracts that pinned
version during `prebuild`, and then runs `git -C $$flutter$$ checkout -f
$flutterVersion`. This follows the F-Droid Flutter template.

Version 1.0.5 declares NDK r28c for the native SoLoud engine. The app's
`android/gradle.properties` disables optional precompiled Xiph codecs with
`NO_XIPH_LIBS=true`. Keep `.pub-cache` in `scandelete` so unused downloaded
binaries are removed by the scanner; MP3/WAV support is compiled from source.

Test all three new builds, not only the last ABI:

```sh
fdroid rewritemeta com.wordpress.brunoloff.meditationtimer
fdroid lint com.wordpress.brunoloff.meditationtimer
fdroid build -v -t --refresh-scanner --no-tarball com.wordpress.brunoloff.meditationtimer:61 com.wordpress.brunoloff.meditationtimer:62 com.wordpress.brunoloff.meditationtimer:63
```

The recipe retains tag-based autoupdates and the `base * 10 + ABI` version-code
scheme. Future updates can normally be triggered by a version bump and tag, but
this native-engine change also adds an NDK requirement to the build recipe.
