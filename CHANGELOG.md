# Changelog

## 1.0.5

### Optional Pranayama Remote Control

- Added configurable commands for Bluetooth rings, media remotes, and keyboards:
  start/stop, lengthen all breath phases by 10%, shorten them by dividing by 1.1,
  and move to the next or previous segment.
- Added key/gesture capture, Android media-button handling, input diagnostics,
  and an optional Android accessibility input service. The service does not
  inspect screen content and is enabled only through Android settings.
- In remote mode, segment durations are ignored until a segment-change or stop
  command. Touchscreen controls remain available. The default mode is unchanged.
- Breath-length and segment changes are queued for the next complete cycle.
  Upcoming phase lengths are shown beside the current values until they apply.
- Double gestures have a 500 ms recognition window so they do not also trigger
  the corresponding single-gesture command.

### Audio and Presets

- Migrated bells and generated breathing tones to a shared SoLoud backend.
  Breathing graphics and audio use the same engine clock, with buffered,
  scheduled multi-cycle clips and silent waveform boundaries.
- Corrected scheduling across finite segments and preset changes, preventing
  an old pattern from overrunning the next segment or overlapping a new preset.
- Preserved legacy bell asset paths and remapped them when loading audio.
- Added the default HRV & HPV Breathing preset: 12 minutes of 5-0-7-0 followed
  by 5 minutes of 5-6-7-0. Existing presets are not overwritten; use Reinstall
  default presets to add missing defaults to an existing installation.

### Fixes and Upgrade Safety

- Fixed one-time intermediate bells being missed when a timer callback arrived
  a fraction of a second late (GitHub issue #1). Repeating bells and start/end
  bell priority are retained.
- Made the Stats and session-summary streak counts agree when today is already
  part of the streak.
- Added regression coverage for callback delays, saved-data upgrades, remote
  mode being opt-in, timed segment completion, and audio chunk boundaries.
- No application ID, storage-key, log-format, preset-format, or signing-policy
  changes. Remote bindings are additional optional preferences, and live breath
  adjustments do not overwrite saved presets.

### Distribution

- Version 1.0.5 uses base build number 6 and Android ABI version codes 61
  (ARMv7), 62 (ARM64), and 63 (x86_64).
- Flutter remains pinned to 3.44.1. SoLoud is updated to 4.1.7, including its
  source-only Android build fix; optional precompiled Xiph codecs are disabled.
- F-Droid builds remain unsigned upstream; F-Droid signs and publishes updates.
  GitHub publication does not make an update immediately available in F-Droid.
