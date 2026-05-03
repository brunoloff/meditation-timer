part of 'main.dart';

const _recentPranayamaCollapsedKey = 'recentPranayamaCollapsed';
const _recentPranayamaPresetIdsKey = 'recentPranayamaPresetIds';
const _pranayamaEntriesKey = 'pranayamaEntries';

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

const _defaultPranayamaEntries = [
  PranayamaPresetEntry(_sixEightPranayamaPreset),
  PranayamaPresetEntry(_gentlePranayamaPreset),
  PranayamaFolderEntry(_balancingPranayamaFolder),
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
