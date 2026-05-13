part of 'main.dart';

const _recentPranayamaCollapsedKey = 'recentPranayamaCollapsed';
const _recentPranayamaPresetIdsKey = 'recentPranayamaPresetIds';
const _pranayamaEntriesKey = 'pranayamaEntries';
const _pranayamaLeadDuration = Duration(seconds: 1);

class PranayamaPreset {
  const PranayamaPreset({
    required this.id,
    required this.name,
    required this.duration,
    required this.inBreath,
    required this.firstHold,
    required this.outBreath,
    required this.secondHold,
    this.note = '',
  });

  final String id;
  final String name;
  final String note;
  final Duration? duration;
  final Duration inBreath;
  final Duration firstHold;
  final Duration outBreath;
  final Duration secondHold;

  bool get isInfinite => duration == null;

  Duration get cycleDuration => inBreath + firstHold + outBreath + secondHold;

  PranayamaPreset copyWith({
    String? id,
    String? name,
    String? note,
    Duration? duration,
    bool clearDuration = false,
    Duration? inBreath,
    Duration? firstHold,
    Duration? outBreath,
    Duration? secondHold,
  }) {
    return PranayamaPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      note: note ?? this.note,
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
  duration: Duration(minutes: 12, seconds: 30),
  inBreath: Duration(seconds: 6),
  firstHold: Duration.zero,
  outBreath: Duration(seconds: 8),
  secondHold: Duration.zero,
);

const _boxBreathingPranayamaPreset = PranayamaPreset(
  id: 'pranayama-box-breathing',
  name: 'Box breathing',
  note: 'Even rhythm',
  duration: Duration(minutes: 10),
  inBreath: Duration(seconds: 4),
  firstHold: Duration(seconds: 4),
  outBreath: Duration(seconds: 4),
  secondHold: Duration(seconds: 4),
);

const _gentlePranayamaPreset = PranayamaPreset(
  id: 'pranayama-gentle-breath',
  name: 'Gentle breath',
  note: 'No fixed ending',
  duration: null,
  inBreath: Duration(seconds: 5),
  firstHold: Duration.zero,
  outBreath: Duration(seconds: 5),
  secondHold: Duration.zero,
);

const _balancingPranayamaFolder = PranayamaFolder(
  name: 'Balancing',
  presets: [_boxBreathingPranayamaPreset],
);

const _fourFiveHrvBreathingPreset = PranayamaPreset(
  id: 'pranayama-4-5-hrv-breathing',
  name: '4/5 HRV Breathing',
  note: '',
  duration: Duration(minutes: 15),
  inBreath: Duration(seconds: 4),
  firstHold: Duration.zero,
  outBreath: Duration(seconds: 5),
  secondHold: Duration.zero,
);

const _fiveSixHrvBreathingPreset = PranayamaPreset(
  id: 'pranayama-5-6-hrv-breathing',
  name: '5/6 HRV Breathing',
  note: '',
  duration: Duration(minutes: 15),
  inBreath: Duration(seconds: 5),
  firstHold: Duration.zero,
  outBreath: Duration(seconds: 6),
  secondHold: Duration.zero,
);

const _sixSevenHrvBreathingPreset = PranayamaPreset(
  id: 'pranayama-6-7-hrv-breathing',
  name: '6/7 HRV Breathing',
  note: '',
  duration: Duration(minutes: 15),
  inBreath: Duration(seconds: 6),
  firstHold: Duration.zero,
  outBreath: Duration(seconds: 7),
  secondHold: Duration.zero,
);

const _fourFiveSixBpvBreathingPreset = PranayamaPreset(
  id: 'pranayama-4-5-6-bpv-breathing',
  name: '4/5/6 BPV Breathing',
  note: '',
  duration: Duration(minutes: 15),
  inBreath: Duration(seconds: 4),
  firstHold: Duration(seconds: 5),
  outBreath: Duration(seconds: 6),
  secondHold: Duration.zero,
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

Duration _pranayamaCycleDuration(PranayamaPreset preset) {
  final cycleDuration = preset.cycleDuration;
  return cycleDuration <= Duration.zero
      ? const Duration(seconds: 1)
      : cycleDuration;
}

Duration? _effectivePranayamaDuration(PranayamaPreset preset) {
  final targetDuration = preset.duration;
  if (targetDuration == null) {
    return null;
  }

  // A finite pranayama session should never stop mid-breath. The displayed
  // clock is allowed to run past the target until the current cycle completes.
  final cycleDuration = _pranayamaCycleDuration(preset);
  final cycleMilliseconds = cycleDuration.inMilliseconds;
  final cycleCount = (targetDuration.inMilliseconds / cycleMilliseconds).ceil();
  final clampedCycleCount = cycleCount.clamp(1, 1 << 30).toInt();
  return Duration(milliseconds: cycleMilliseconds * clampedCycleCount);
}

enum _PranayamaSoundPhase { inhale, exhale, silent }

String _pranayamaToneCacheKey(PranayamaPreset preset) {
  return [
    preset.inBreath.inMilliseconds,
    preset.firstHold.inMilliseconds,
    preset.outBreath.inMilliseconds,
    preset.secondHold.inMilliseconds,
  ].join('-');
}

Uint8List _generatePranayamaCycleToneBytes(PranayamaPreset preset) {
  // Generate one full loop instead of scheduling separate inhale/exhale clips.
  // That keeps no-hold presets smooth: the fade-out is baked into the phase,
  // and the player only has to loop one already-buffered WAV byte source.
  const sampleRate = 48000;
  const bytesPerSample = 2;
  const channelCount = 1;
  final frameCount = math.max(
    1,
    _pranayamaCycleDuration(preset).inMicroseconds * sampleRate ~/ 1000000,
  );
  final dataSize = frameCount * bytesPerSample * channelCount;
  final bytes = Uint8List(44 + dataSize);
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
  byteData.setUint16(22, channelCount, Endian.little);
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(
    28,
    sampleRate * channelCount * bytesPerSample,
    Endian.little,
  );
  byteData.setUint16(32, channelCount * bytesPerSample, Endian.little);
  byteData.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  byteData.setUint32(40, dataSize, Endian.little);

  final phases = [
    (_PranayamaSoundPhase.inhale, preset.inBreath),
    (_PranayamaSoundPhase.silent, preset.firstHold),
    (_PranayamaSoundPhase.exhale, preset.outBreath),
    (_PranayamaSoundPhase.silent, preset.secondHold),
  ];
  var frameOffset = 0;

  for (final (phase, duration) in phases) {
    final phaseFrameCount = math.max(
      0,
      duration.inMicroseconds * sampleRate ~/ 1000000,
    );
    final fadeFrameCount = math.min(
      phaseFrameCount ~/ 2,
      (sampleRate * 0.45).round(),
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
      final time = absoluteFrame / sampleRate;
      final sample =
          0.70 * math.sin(2 * math.pi * frequency * time) +
          0.20 * math.sin(2 * math.pi * frequency * 2 * time) +
          0.10 * math.sin(2 * math.pi * frequency * 3 * time);
      final scaledSample = (sample * envelope * 0.32 * 32767)
          .clamp(-32767.0, 32767.0)
          .round();
      byteData.setInt16(
        44 + absoluteFrame * bytesPerSample,
        scaledSample,
        Endian.little,
      );
    }
    frameOffset += phaseFrameCount;
  }

  return bytes;
}
