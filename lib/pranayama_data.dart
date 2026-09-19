part of 'main.dart';

const _recentPranayamaCollapsedKey = 'recentPranayamaCollapsed';
const _recentPranayamaPresetIdsKey = 'recentPranayamaPresetIds';
const _pranayamaEntriesKey = 'pranayamaEntries';
const _pranayamaRemoteControlEnabledKey = 'pranayamaRemoteControlEnabled';
const _pranayamaRemoteCommandKeysKey = 'pranayamaRemoteCommandKeys';
const _pranayamaLeadDuration = Duration(seconds: 1);

enum PranayamaRemoteCommand {
  toggleStartStop,
  increaseBreathLengths,
  decreaseBreathLengths,
  nextSegment,
  previousSegment,
}

enum PranayamaRemoteInputType {
  flutterLogicalKey,
  androidKeyCode,
  androidMotion,
}

const _androidMotionVerticalScrollPositiveCode = 1;
const _androidMotionVerticalScrollNegativeCode = 2;
const _androidMotionHorizontalScrollPositiveCode = 3;
const _androidMotionHorizontalScrollNegativeCode = 4;
const _androidMotionPointerPrimaryClickCode = 101;
const _androidMotionPointerSecondaryClickCode = 102;
const _androidMotionPointerMiddleClickCode = 103;
const _androidMotionPointerBackClickCode = 104;
const _androidMotionPointerForwardClickCode = 105;
const _androidMotionExternalTouchTapCode = 201;
const _androidMotionExternalTouchSwipeUpCode = 202;
const _androidMotionExternalTouchSwipeDownCode = 203;
const _androidMotionExternalTouchSwipeLeftCode = 204;
const _androidMotionExternalTouchSwipeRightCode = 205;

class PranayamaRemoteInputBinding {
  const PranayamaRemoteInputBinding({required this.type, required this.code});

  const PranayamaRemoteInputBinding.flutterLogicalKey(int keyId)
    : type = PranayamaRemoteInputType.flutterLogicalKey,
      code = keyId;

  const PranayamaRemoteInputBinding.androidKeyCode(int keyCode)
    : type = PranayamaRemoteInputType.androidKeyCode,
      code = keyCode;

  const PranayamaRemoteInputBinding.androidMotion(int motionCode)
    : type = PranayamaRemoteInputType.androidMotion,
      code = motionCode;

  final PranayamaRemoteInputType type;
  final int code;

  Object encode() {
    return {'type': type.name, 'code': code};
  }

  static PranayamaRemoteInputBinding? decode(Object? encoded) {
    if (encoded is int && encoded > 0) {
      return PranayamaRemoteInputBinding.flutterLogicalKey(encoded);
    }

    if (encoded is! Map<String, Object?>) {
      return null;
    }

    final typeName = encoded['type'];
    final code = encoded['code'];
    if (typeName is! String || code is! int || code <= 0) {
      return null;
    }

    PranayamaRemoteInputType? type;
    for (final candidate in PranayamaRemoteInputType.values) {
      if (candidate.name == typeName) {
        type = candidate;
        break;
      }
    }
    if (type == null) {
      return null;
    }

    return PranayamaRemoteInputBinding(type: type, code: code);
  }

  @override
  bool operator ==(Object other) {
    return other is PranayamaRemoteInputBinding &&
        other.type == type &&
        other.code == code;
  }

  @override
  int get hashCode => Object.hash(type, code);
}

String _pranayamaRemoteCommandLabel(PranayamaRemoteCommand command) {
  return switch (command) {
    PranayamaRemoteCommand.toggleStartStop => 'Start/stop pranayama',
    PranayamaRemoteCommand.increaseBreathLengths =>
      'Increase breath lengths by 10%',
    PranayamaRemoteCommand.decreaseBreathLengths =>
      'Decrease breath lengths by 10%',
    PranayamaRemoteCommand.nextSegment => 'Next segment',
    PranayamaRemoteCommand.previousSegment => 'Previous segment',
  };
}

Map<String, Object> _encodePranayamaRemoteCommandKeys(
  Map<PranayamaRemoteCommand, PranayamaRemoteInputBinding> commandKeys,
) {
  return {
    for (final entry in commandKeys.entries)
      entry.key.name: entry.value.encode(),
  };
}

Map<PranayamaRemoteCommand, PranayamaRemoteInputBinding>
_decodePranayamaRemoteCommandKeys(String? encodedCommandKeys) {
  if (encodedCommandKeys == null) {
    return const {};
  }

  try {
    final decoded = jsonDecode(encodedCommandKeys);
    if (decoded is! Map<String, Object?>) {
      return const {};
    }

    final commandKeys = <PranayamaRemoteCommand, PranayamaRemoteInputBinding>{};
    for (final command in PranayamaRemoteCommand.values) {
      final binding = PranayamaRemoteInputBinding.decode(decoded[command.name]);
      if (binding != null) {
        commandKeys[command] = binding;
      }
    }
    return commandKeys;
  } on FormatException {
    return const {};
  } on TypeError {
    return const {};
  }
}

String _pranayamaRemoteInputBindingLabel(PranayamaRemoteInputBinding binding) {
  return switch (binding.type) {
    PranayamaRemoteInputType.flutterLogicalKey => _logicalKeyboardKeyLabel(
      binding.code,
    ),
    PranayamaRemoteInputType.androidKeyCode => _androidKeyCodeLabel(
      binding.code,
    ),
    PranayamaRemoteInputType.androidMotion => _androidMotionLabel(binding.code),
  };
}

String _logicalKeyboardKeyLabel(int keyId) {
  final key = LogicalKeyboardKey(keyId);
  if (key.keyLabel.trim().isNotEmpty) {
    return key.keyLabel;
  }
  return key.debugName ?? 'Key 0x${keyId.toRadixString(16)}';
}

String _androidKeyCodeLabel(int keyCode) {
  return switch (keyCode) {
    4 => 'Android Back',
    24 => 'Volume up',
    25 => 'Volume down',
    79 => 'Headset hook',
    85 => 'Media play/pause',
    86 => 'Media stop',
    87 => 'Media next',
    88 => 'Media previous',
    89 => 'Media rewind',
    90 => 'Media fast forward',
    126 => 'Media play',
    127 => 'Media pause',
    _ => 'Android key $keyCode',
  };
}

String _androidMotionLabel(int motionCode) {
  return switch (motionCode) {
    _androidMotionVerticalScrollPositiveCode => 'Android scroll up',
    _androidMotionVerticalScrollNegativeCode => 'Android scroll down',
    _androidMotionHorizontalScrollPositiveCode => 'Android horizontal scroll +',
    _androidMotionHorizontalScrollNegativeCode => 'Android horizontal scroll -',
    _androidMotionPointerPrimaryClickCode => 'Android pointer primary click',
    _androidMotionPointerSecondaryClickCode =>
      'Android pointer secondary click',
    _androidMotionPointerMiddleClickCode => 'Android pointer middle click',
    _androidMotionPointerBackClickCode => 'Android pointer back click',
    _androidMotionPointerForwardClickCode => 'Android pointer forward click',
    _androidMotionExternalTouchTapCode => 'External touch tap',
    _androidMotionExternalTouchSwipeUpCode => 'External touch swipe up',
    _androidMotionExternalTouchSwipeDownCode => 'External touch swipe down',
    _androidMotionExternalTouchSwipeLeftCode => 'External touch swipe left',
    _androidMotionExternalTouchSwipeRightCode => 'External touch swipe right',
    _ => 'Android motion $motionCode',
  };
}

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
    this.manualSegmentIndex,
    this.pendingPreset,
    this.pendingSegmentIndex,
    this.remoteControlActive = false,
  });

  static const empty = PranayamaSessionSnapshot(
    preset: null,
    elapsed: Duration.zero,
    isPaused: false,
    manualSegmentIndex: null,
    pendingPreset: null,
    pendingSegmentIndex: null,
    remoteControlActive: false,
  );

  final PranayamaPreset? preset;
  final Duration elapsed;
  final bool isPaused;
  final int? manualSegmentIndex;
  final PranayamaPreset? pendingPreset;
  final int? pendingSegmentIndex;
  final bool remoteControlActive;

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

const _hrvHpvBreathingPreset = PranayamaPreset(
  id: 'pranayama-hrv-hpv-breathing',
  name: 'HRV & HPV Breathing',
  note: '',
  segments: [
    PranayamaSegment(
      id: 'segment-hrv-hpv-breathing-hrv',
      duration: Duration(minutes: 12),
      inBreath: Duration(seconds: 5),
      firstHold: Duration.zero,
      outBreath: Duration(seconds: 7),
      secondHold: Duration.zero,
    ),
    PranayamaSegment(
      id: 'segment-hrv-hpv-breathing-hpv',
      duration: Duration(minutes: 5),
      inBreath: Duration(seconds: 5),
      firstHold: Duration(seconds: 6),
      outBreath: Duration(seconds: 7),
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
    _hrvHpvBreathingPreset,
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
  Duration elapsed, {
  int? forcedSegmentIndex,
}) {
  final clampedElapsed = elapsed.isNegative ? Duration.zero : elapsed;
  if (forcedSegmentIndex != null && preset.segments.isNotEmpty) {
    final index = forcedSegmentIndex
        .clamp(0, preset.segments.length - 1)
        .toInt();
    return PranayamaSegmentPosition(
      segment: preset.segments[index],
      index: index,
      localElapsed: clampedElapsed,
      segmentStart: _pranayamaSegmentStartForIndex(preset, index),
    );
  }

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

Duration _pranayamaSegmentStartForIndex(PranayamaPreset preset, int index) {
  var segmentStart = Duration.zero;
  final clampedIndex = index.clamp(0, preset.segments.length - 1).toInt();
  for (var cursor = 0; cursor < clampedIndex; cursor += 1) {
    final effectiveDuration = _effectivePranayamaSegmentDuration(
      preset.segments[cursor],
    );
    if (effectiveDuration == null) {
      return segmentStart;
    }
    segmentStart += effectiveDuration;
  }
  return segmentStart;
}

enum _PranayamaSoundPhase { inhale, exhale, silent }

String _pranayamaToneCacheKeyForSegment(PranayamaSegment segment) {
  return [
    segment.inBreath.inMilliseconds,
    segment.firstHold.inMilliseconds,
    segment.outBreath.inMilliseconds,
    segment.secondHold.inMilliseconds,
  ].join('-');
}

String _pranayamaToneChunkCacheKeyForSegment(
  PranayamaSegment segment,
  int cycleCount,
) {
  return '${_pranayamaToneCacheKeyForSegment(segment)}x$cycleCount';
}

class _PranayamaToneClip {
  const _PranayamaToneClip({required this.bytes, required this.duration});

  final Uint8List bytes;
  final Duration duration;
}

Duration _pranayamaToneClipDurationForSegment(PranayamaSegment segment) {
  return _pranayamaCycleDurationForSegment(segment);
}

@visibleForTesting
Duration pranayamaToneClipDurationForTesting(PranayamaSegment segment) {
  return _pranayamaToneClipDurationForSegment(segment);
}

@visibleForTesting
List<int> pranayamaToneBoundarySamplesForTesting(PranayamaSegment segment) {
  final clip = _generatePranayamaToneClip(segment);
  final byteData = ByteData.sublistView(clip.bytes);
  final lastSampleOffset = clip.bytes.length - _pranayamaToneBytesPerSample;
  return [
    byteData.getInt16(_wavHeaderLength, Endian.little),
    byteData.getInt16(lastSampleOffset, Endian.little),
  ];
}

@visibleForTesting
int pranayamaTonePeakSampleForTesting(PranayamaSegment segment) {
  final clip = _generatePranayamaToneClip(segment);
  final byteData = ByteData.sublistView(clip.bytes);
  var peak = 0;
  for (
    var offset = _wavHeaderLength;
    offset < clip.bytes.length;
    offset += _pranayamaToneBytesPerSample
  ) {
    peak = math.max(peak, byteData.getInt16(offset, Endian.little).abs());
  }
  return peak;
}

_PranayamaToneClip _generatePranayamaToneClip(PranayamaSegment segment) {
  // SoLoud schedules these one-cycle WAVs against its own audio clock. That
  // gives us exact phase boundaries without relying on platform loop timing.
  final clipDuration = _pranayamaToneClipDurationForSegment(segment);
  return _PranayamaToneClip(
    bytes: _generatePranayamaCycleToneBytes(segment),
    duration: clipDuration,
  );
}

_PranayamaToneClip _generatePranayamaToneChunkClip({
  required PranayamaSegment segment,
  required int cycleCount,
}) {
  final clampedCycleCount = math.max(1, cycleCount);
  final cycleClip = _generatePranayamaToneClip(segment);
  if (clampedCycleCount == 1) {
    return cycleClip;
  }

  // Remote-control transitions should only need to stop the one active voice
  // at the next breath boundary. Repeating complete PCM cycles in one WAV keeps
  // that voice active while avoiding a queue of delayed future voices that must
  // later be cancelled.
  final cycleDataSize = cycleClip.bytes.length - _wavHeaderLength;
  final dataSize = cycleDataSize * clampedCycleCount;
  final bytes = Uint8List(_wavHeaderLength + dataSize);
  _writeWavHeader(bytes, dataSize: dataSize);

  for (var cycleIndex = 0; cycleIndex < clampedCycleCount; cycleIndex += 1) {
    final writeOffset = _wavHeaderLength + cycleIndex * cycleDataSize;
    bytes.setRange(
      writeOffset,
      writeOffset + cycleDataSize,
      cycleClip.bytes,
      _wavHeaderLength,
    );
  }

  return _PranayamaToneClip(
    bytes: bytes,
    duration: Duration(
      microseconds: cycleClip.duration.inMicroseconds * clampedCycleCount,
    ),
  );
}

const _pranayamaToneSampleRate = _soloudOutputSampleRate;
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
