part of 'main.dart';

const _recentPranayamaCollapsedKey = 'recentPranayamaCollapsed';
const _recentPranayamaPresetIdsKey = 'recentPranayamaPresetIds';
const _pranayamaEntriesKey = 'pranayamaEntries';
const _pranayamaLeadDuration = Duration(seconds: 1);
const _maxGeneratedPranayamaToneClipDuration = Duration(minutes: 20);

class PranayamaPreset {
  const PranayamaPreset({
    required this.id,
    required this.name,
    required this.segments,
    this.note = '',
  });

  final String id;
  final String name;
  final String note;
  final List<PranayamaSegment> segments;

  PranayamaSegment get firstSegment => segments.first;
  PranayamaSegment get lastSegment => segments.last;

  // Compatibility getters keep older UI/helper code readable while the preset
  // model moves from "one rhythm" to "a sequence of rhythms".
  Duration? get duration {
    if (segments.isEmpty || lastSegment.isInfinite) {
      return null;
    }

    return segments.fold<Duration>(
      Duration.zero,
      (total, segment) => total + (segment.duration ?? Duration.zero),
    );
  }

  Duration get inBreath => firstSegment.inBreath;
  Duration get firstHold => firstSegment.firstHold;
  Duration get outBreath => firstSegment.outBreath;
  Duration get secondHold => firstSegment.secondHold;

  bool get isInfinite => segments.isEmpty || lastSegment.isInfinite;

  Duration get cycleDuration => firstSegment.cycleDuration;

  PranayamaPreset copyWith({
    String? id,
    String? name,
    String? note,
    List<PranayamaSegment>? segments,
  }) {
    return PranayamaPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      note: note ?? this.note,
      segments: segments ?? this.segments,
    );
  }
}

class PranayamaSegment {
  const PranayamaSegment({
    required this.id,
    required this.duration,
    required this.inBreath,
    required this.firstHold,
    required this.outBreath,
    required this.secondHold,
  });

  final String id;
  final Duration? duration;
  final Duration inBreath;
  final Duration firstHold;
  final Duration outBreath;
  final Duration secondHold;

  bool get isInfinite => duration == null;

  Duration get cycleDuration => inBreath + firstHold + outBreath + secondHold;

  PranayamaSegment copyWith({
    String? id,
    Duration? duration,
    bool clearDuration = false,
    Duration? inBreath,
    Duration? firstHold,
    Duration? outBreath,
    Duration? secondHold,
  }) {
    return PranayamaSegment(
      id: id ?? this.id,
      duration: clearDuration ? null : duration ?? this.duration,
      inBreath: inBreath ?? this.inBreath,
      firstHold: firstHold ?? this.firstHold,
      outBreath: outBreath ?? this.outBreath,
      secondHold: secondHold ?? this.secondHold,
    );
  }
}

class PranayamaFolder {
  const PranayamaFolder({required this.name, required this.presets});

  final String name;
  final List<PranayamaPreset> presets;

  PranayamaFolder withPresets(List<PranayamaPreset> presets) {
    return PranayamaFolder(name: name, presets: presets);
  }

  PranayamaFolder withName(String name) {
    return PranayamaFolder(name: name, presets: presets);
  }
}

sealed class PranayamaBrowserEntry {
  const PranayamaBrowserEntry();

  String get id;
}

class PranayamaSessionSnapshot {
  const PranayamaSessionSnapshot({
    required this.preset,
    required this.elapsed,
    required this.isPaused,
  });

  static const empty = PranayamaSessionSnapshot(
    preset: null,
    elapsed: Duration.zero,
    isPaused: false,
  );

  final PranayamaPreset? preset;
  final Duration elapsed;
  final bool isPaused;

  bool get isActive => preset != null;
}

class PranayamaPresetEntry extends PranayamaBrowserEntry {
  const PranayamaPresetEntry(this.preset);

  final PranayamaPreset preset;

  @override
  String get id => 'pranayama-preset-${preset.id}';
}

class PranayamaFolderEntry extends PranayamaBrowserEntry {
  const PranayamaFolderEntry(this.folder);

  final PranayamaFolder folder;

  @override
  String get id => 'pranayama-folder-${folder.name}';
}

const _sixEightPranayamaPreset = PranayamaPreset(
  id: 'pranayama-6-in-8-out',
  name: '6 in 8 out',
  note: 'Long exhale',
  segments: [
    PranayamaSegment(
      id: 'segment-6-in-8-out',
      duration: Duration(minutes: 12, seconds: 30),
      inBreath: Duration(seconds: 6),
      firstHold: Duration.zero,
      outBreath: Duration(seconds: 8),
      secondHold: Duration.zero,
    ),
  ],
);

const _boxBreathingPranayamaPreset = PranayamaPreset(
  id: 'pranayama-box-breathing',
  name: 'Box breathing',
  note: 'Even rhythm',
  segments: [
    PranayamaSegment(
      id: 'segment-box-breathing',
      duration: Duration(minutes: 10),
      inBreath: Duration(seconds: 4),
      firstHold: Duration(seconds: 4),
      outBreath: Duration(seconds: 4),
      secondHold: Duration(seconds: 4),
    ),
  ],
);

const _gentlePranayamaPreset = PranayamaPreset(
  id: 'pranayama-gentle-breath',
  name: 'Gentle breath',
  note: 'No fixed ending',
  segments: [
    PranayamaSegment(
      id: 'segment-gentle-breath',
      duration: null,
      inBreath: Duration(seconds: 5),
      firstHold: Duration.zero,
      outBreath: Duration(seconds: 5),
      secondHold: Duration.zero,
    ),
  ],
);

const _balancingPranayamaFolder = PranayamaFolder(
  name: 'Balancing',
  presets: [_boxBreathingPranayamaPreset],
);

const _fourFiveHrvBreathingPreset = PranayamaPreset(
  id: 'pranayama-4-5-hrv-breathing',
  name: '4/5 HRV Breathing',
  note: '',
  segments: [
    PranayamaSegment(
      id: 'segment-4-5-hrv-breathing',
      duration: Duration(minutes: 15),
      inBreath: Duration(seconds: 4),
      firstHold: Duration.zero,
      outBreath: Duration(seconds: 5),
      secondHold: Duration.zero,
    ),
  ],
);

const _fiveSixHrvBreathingPreset = PranayamaPreset(
  id: 'pranayama-5-6-hrv-breathing',
  name: '5/6 HRV Breathing',
  note: '',
  segments: [
    PranayamaSegment(
      id: 'segment-5-6-hrv-breathing',
      duration: Duration(minutes: 15),
      inBreath: Duration(seconds: 5),
      firstHold: Duration.zero,
      outBreath: Duration(seconds: 6),
      secondHold: Duration.zero,
    ),
  ],
);

const _sixSevenHrvBreathingPreset = PranayamaPreset(
  id: 'pranayama-6-7-hrv-breathing',
  name: '6/7 HRV Breathing',
  note: '',
  segments: [
    PranayamaSegment(
      id: 'segment-6-7-hrv-breathing',
      duration: Duration(minutes: 15),
      inBreath: Duration(seconds: 6),
      firstHold: Duration.zero,
      outBreath: Duration(seconds: 7),
      secondHold: Duration.zero,
    ),
  ],
);

const _fourFiveSixBpvBreathingPreset = PranayamaPreset(
  id: 'pranayama-4-5-6-bpv-breathing',
  name: '4/5/6 BPV Breathing',
  note: '',
  segments: [
    PranayamaSegment(
      id: 'segment-4-5-6-bpv-breathing',
      duration: Duration(minutes: 15),
      inBreath: Duration(seconds: 4),
      firstHold: Duration(seconds: 5),
      outBreath: Duration(seconds: 6),
      secondHold: Duration.zero,
    ),
  ],
);

const _forrestKnutsonPranayamaFolder = PranayamaFolder(
  name: 'Forrest Knutson',
  presets: [
    _fourFiveHrvBreathingPreset,
    _fiveSixHrvBreathingPreset,
    _sixSevenHrvBreathingPreset,
    _fourFiveSixBpvBreathingPreset,
  ],
);

const _defaultPranayamaEntries = [
  PranayamaPresetEntry(_sixEightPranayamaPreset),
  PranayamaPresetEntry(_gentlePranayamaPreset),
  PranayamaFolderEntry(_balancingPranayamaFolder),
  PranayamaFolderEntry(_forrestKnutsonPranayamaFolder),
];

String _newPranayamaPresetId() {
  return 'pranayama-${DateTime.now().microsecondsSinceEpoch}';
}

String _legacyPranayamaPresetId(String name) {
  final slug = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? _newPranayamaPresetId() : 'pranayama-$slug';
}

Duration _pranayamaCycleDurationForSegment(PranayamaSegment segment) {
  final cycleDuration = segment.cycleDuration;
  return cycleDuration <= Duration.zero
      ? const Duration(seconds: 1)
      : cycleDuration;
}

Duration? _effectivePranayamaDuration(PranayamaPreset preset) {
  var total = Duration.zero;
  for (final segment in preset.segments) {
    final segmentDuration = _effectivePranayamaSegmentDuration(segment);
    if (segmentDuration == null) {
      return null;
    }
    total += segmentDuration;
  }

  return total;
}

@visibleForTesting
Duration? effectivePranayamaDurationForTesting(PranayamaPreset preset) {
  return _effectivePranayamaDuration(preset);
}

@visibleForTesting
PranayamaSegmentPosition pranayamaSegmentAtElapsedForTesting(
  PranayamaPreset preset,
  Duration elapsed,
) {
  return _pranayamaSegmentAtElapsed(preset, elapsed);
}

Duration? _effectivePranayamaSegmentDuration(PranayamaSegment segment) {
  final targetDuration = segment.duration;
  if (targetDuration == null) {
    return null;
  }

  // A finite segment should never stop mid-breath. The displayed clock is
  // allowed to run past the target until the current cycle completes.
  final cycleDuration = _pranayamaCycleDurationForSegment(segment);
  final cycleMilliseconds = cycleDuration.inMilliseconds;
  final cycleCount = (targetDuration.inMilliseconds / cycleMilliseconds).ceil();
  final clampedCycleCount = cycleCount.clamp(1, 1 << 30).toInt();
  return Duration(milliseconds: cycleMilliseconds * clampedCycleCount);
}

class PranayamaSegmentPosition {
  const PranayamaSegmentPosition({
    required this.segment,
    required this.index,
    required this.localElapsed,
    required this.segmentStart,
  });

  final PranayamaSegment segment;
  final int index;
  final Duration localElapsed;
  final Duration segmentStart;
}

PranayamaSegmentPosition _pranayamaSegmentAtElapsed(
  PranayamaPreset preset,
  Duration elapsed,
) {
  final clampedElapsed = elapsed.isNegative ? Duration.zero : elapsed;
  var segmentStart = Duration.zero;

  for (var index = 0; index < preset.segments.length; index += 1) {
    final segment = preset.segments[index];
    final effectiveDuration = _effectivePranayamaSegmentDuration(segment);
    if (effectiveDuration == null ||
        clampedElapsed < segmentStart + effectiveDuration) {
      return PranayamaSegmentPosition(
        segment: segment,
        index: index,
        localElapsed: clampedElapsed - segmentStart,
        segmentStart: segmentStart,
      );
    }
    segmentStart += effectiveDuration;
  }

  final fallbackIndex = math.max(0, preset.segments.length - 1);
  final fallbackSegment = preset.segments[fallbackIndex];
  return PranayamaSegmentPosition(
    segment: fallbackSegment,
    index: fallbackIndex,
    localElapsed: Duration.zero,
    segmentStart: segmentStart,
  );
}

enum _PranayamaSoundPhase { inhale, exhale, silent }

String _pranayamaToneCacheKeyForSegment(PranayamaSegment segment) {
  return [
    segment.duration?.inMilliseconds ?? 'infinite',
    segment.inBreath.inMilliseconds,
    segment.firstHold.inMilliseconds,
    segment.outBreath.inMilliseconds,
    segment.secondHold.inMilliseconds,
  ].join('-');
}

class _PranayamaToneClip {
  const _PranayamaToneClip({
    required this.bytes,
    required this.duration,
    required this.releaseMode,
  });

  final Uint8List bytes;
  final Duration duration;
  final ReleaseMode releaseMode;
}

Duration _pranayamaToneClipDurationForSegment(PranayamaSegment segment) {
  final cycleDuration = _pranayamaCycleDurationForSegment(segment);
  final cycleMilliseconds = math.max(1, cycleDuration.inMilliseconds);
  final effectiveDuration = _effectivePranayamaSegmentDuration(segment);
  final desiredDuration =
      effectiveDuration == null ||
          effectiveDuration > _maxGeneratedPranayamaToneClipDuration
      ? _maxGeneratedPranayamaToneClipDuration
      : effectiveDuration;
  final cycleCount = math.max(
    1,
    desiredDuration.inMilliseconds ~/ cycleMilliseconds,
  );
  return Duration(milliseconds: cycleMilliseconds * cycleCount);
}

@visibleForTesting
Duration pranayamaToneClipDurationForTesting(PranayamaSegment segment) {
  return _pranayamaToneClipDurationForSegment(segment);
}

_PranayamaToneClip _generatePranayamaToneClip(PranayamaSegment segment) {
  // The visual guide runs from wall-clock time. If audio loops every breath
  // cycle, tiny platform loop delays can accumulate until the tone lags behind
  // the dot. Instead, generate a longer whole-cycle WAV clip. Finite segments
  // up to the cap play once; infinite or very long segments loop far less often.
  final cycleBytes = _generatePranayamaCycleToneBytes(segment);
  final cycleDataSize = cycleBytes.length - _wavHeaderLength;
  final clipDuration = _pranayamaToneClipDurationForSegment(segment);
  final cycleDuration = _pranayamaCycleDurationForSegment(segment);
  final cycleCount = math.max(
    1,
    clipDuration.inMilliseconds ~/ math.max(1, cycleDuration.inMilliseconds),
  );
  final dataSize = cycleDataSize * cycleCount;
  final bytes = Uint8List(_wavHeaderLength + dataSize);
  _writeWavHeader(bytes, dataSize: dataSize);

  for (var cycleIndex = 0; cycleIndex < cycleCount; cycleIndex += 1) {
    bytes.setRange(
      _wavHeaderLength + cycleIndex * cycleDataSize,
      _wavHeaderLength + (cycleIndex + 1) * cycleDataSize,
      cycleBytes,
      _wavHeaderLength,
    );
  }

  final effectiveDuration = _effectivePranayamaSegmentDuration(segment);
  final shouldLoop =
      effectiveDuration == null || clipDuration < effectiveDuration;
  return _PranayamaToneClip(
    bytes: bytes,
    duration: clipDuration,
    releaseMode: shouldLoop ? ReleaseMode.loop : ReleaseMode.stop,
  );
}

const _pranayamaToneSampleRate = 24000;
const _pranayamaToneBytesPerSample = 2;
const _pranayamaToneChannelCount = 1;
const _wavHeaderLength = 44;

void _writeWavHeader(Uint8List bytes, {required int dataSize}) {
  final byteData = ByteData.sublistView(bytes);

  void writeAscii(int offset, String value) {
    for (var index = 0; index < value.length; index += 1) {
      bytes[offset + index] = value.codeUnitAt(index);
    }
  }

  writeAscii(0, 'RIFF');
  byteData.setUint32(4, 36 + dataSize, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, 1, Endian.little);
  byteData.setUint16(22, _pranayamaToneChannelCount, Endian.little);
  byteData.setUint32(24, _pranayamaToneSampleRate, Endian.little);
  byteData.setUint32(
    28,
    _pranayamaToneSampleRate *
        _pranayamaToneChannelCount *
        _pranayamaToneBytesPerSample,
    Endian.little,
  );
  byteData.setUint16(
    32,
    _pranayamaToneChannelCount * _pranayamaToneBytesPerSample,
    Endian.little,
  );
  byteData.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  byteData.setUint32(40, dataSize, Endian.little);
}

Uint8List _generatePranayamaCycleToneBytes(PranayamaSegment segment) {
  // Generate one complete breath cycle with fade-in/out baked into each voiced
  // phase, then repeat that exact PCM block for longer clips.
  final frameCount = math.max(
    1,
    _pranayamaCycleDurationForSegment(segment).inMicroseconds *
        _pranayamaToneSampleRate ~/
        1000000,
  );
  final dataSize =
      frameCount * _pranayamaToneBytesPerSample * _pranayamaToneChannelCount;
  final bytes = Uint8List(_wavHeaderLength + dataSize);
  final byteData = ByteData.sublistView(bytes);
  _writeWavHeader(bytes, dataSize: dataSize);

  final phases = [
    (_PranayamaSoundPhase.inhale, segment.inBreath),
    (_PranayamaSoundPhase.silent, segment.firstHold),
    (_PranayamaSoundPhase.exhale, segment.outBreath),
    (_PranayamaSoundPhase.silent, segment.secondHold),
  ];
  var frameOffset = 0;

  for (final (phase, duration) in phases) {
    final phaseFrameCount = math.max(
      0,
      duration.inMicroseconds * _pranayamaToneSampleRate ~/ 1000000,
    );
    final fadeFrameCount = math.min(
      phaseFrameCount ~/ 2,
      (_pranayamaToneSampleRate * 0.45).round(),
    );
    // Inhale sits noticeably higher than exhale, with two quiet harmonics to
    // avoid a sterile pure sine tone.
    final frequency = switch (phase) {
      _PranayamaSoundPhase.inhale => 330.0,
      _PranayamaSoundPhase.exhale => 247.0,
      _PranayamaSoundPhase.silent => 0.0,
    };

    for (var frame = 0; frame < phaseFrameCount; frame += 1) {
      final absoluteFrame = frameOffset + frame;
      if (absoluteFrame >= frameCount) {
        break;
      }

      final fadeIn = fadeFrameCount <= 0
          ? 1.0
          : (frame / fadeFrameCount).clamp(0.0, 1.0);
      final fadeOut = fadeFrameCount <= 0
          ? 1.0
          : ((phaseFrameCount - 1 - frame) / fadeFrameCount).clamp(0.0, 1.0);
      final envelope = phase == _PranayamaSoundPhase.silent
          ? 0.0
          : fadeIn * fadeOut;
      final time = absoluteFrame / _pranayamaToneSampleRate;
      final sample =
          0.70 * math.sin(2 * math.pi * frequency * time) +
          0.20 * math.sin(2 * math.pi * frequency * 2 * time) +
          0.10 * math.sin(2 * math.pi * frequency * 3 * time);
      final scaledSample = (sample * envelope * 0.32 * 32767)
          .clamp(-32767.0, 32767.0)
          .round();
      byteData.setInt16(
        _wavHeaderLength + absoluteFrame * _pranayamaToneBytesPerSample,
        scaledSample,
        Endian.little,
      );
    }
    frameOffset += phaseFrameCount;
  }

  return bytes;
}
