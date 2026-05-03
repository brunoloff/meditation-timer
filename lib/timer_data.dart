part of 'main.dart';

enum HomeTab {
  timers('Timers'),
  stats('Stats'),
  settings('Settings');

  const HomeTab(this.label);

  final String label;
}

const _homeSurfaceColor = Color(0xFF101012);
const _mutedTextColor = Color(0xFF77777C);
const _dividerColor = Color(0xFF2A2A2E);
const _recentTimersCollapsedKey = 'recentTimersCollapsed';
const _recentTimerIdsKey = 'recentTimerIds';
const _recentTimerLimitKey = 'recentTimerLimit';
const _soundEnabledKey = 'soundEnabled';
const _turnScreenOnNearAudioKey = 'turnScreenOnNearAudio';
const _timerEntriesKey = 'timerEntries';
const _meditationLogsKey = 'meditationLogs';
const _bellAssetRoot = 'audio/bells';

class BellSound {
  const BellSound({
    required this.name,
    required this.assetPath,
    this.tags = const [],
    this.info = '',
    this.url = '',
  });

  final String name;
  final String assetPath;
  final List<String> tags;
  final String info;
  final String url;

  @override
  bool operator ==(Object other) {
    return other is BellSound && other.assetPath == assetPath;
  }

  @override
  int get hashCode => assetPath.hashCode;
}

class MeditationTimerPreset {
  const MeditationTimerPreset({
    required this.id,
    required this.name,
    required this.duration,
    required this.startingBell,
    required this.endingBell,
    this.note = '',
    this.activity = 'Meditation',
    this.intermediateBells = const [],
  });

  final String id;
  final String name;
  final Duration? duration;
  final BellSound? startingBell;
  final BellSound? endingBell;
  final String note;
  final String activity;
  final List<IntermediateBell> intermediateBells;

  bool get isInfinite => duration == null;

  MeditationTimerPreset copyWith({
    String? id,
    String? name,
    Duration? duration,
    bool clearDuration = false,
    BellSound? startingBell,
    bool clearStartingBell = false,
    BellSound? endingBell,
    bool clearEndingBell = false,
    String? note,
    String? activity,
    List<IntermediateBell>? intermediateBells,
  }) {
    return MeditationTimerPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      duration: clearDuration ? null : duration ?? this.duration,
      startingBell: clearStartingBell
          ? null
          : startingBell ?? this.startingBell,
      endingBell: clearEndingBell ? null : endingBell ?? this.endingBell,
      note: note ?? this.note,
      activity: activity ?? this.activity,
      intermediateBells: intermediateBells ?? this.intermediateBells,
    );
  }
}

class IntermediateBell {
  const IntermediateBell({
    required this.startTime,
    required this.bell,
    this.repeatInterval,
  });

  final Duration startTime;
  final BellSound bell;
  final Duration? repeatInterval;

  bool get repeats => repeatInterval != null;

  IntermediateBell copyWith({
    Duration? startTime,
    BellSound? bell,
    Duration? repeatInterval,
    bool clearRepeatInterval = false,
  }) {
    return IntermediateBell(
      startTime: startTime ?? this.startTime,
      bell: bell ?? this.bell,
      repeatInterval: clearRepeatInterval
          ? null
          : repeatInterval ?? this.repeatInterval,
    );
  }
}

class TimerFolder {
  const TimerFolder({required this.name, required this.timers});

  final String name;
  final List<MeditationTimerPreset> timers;

  TimerFolder withTimers(List<MeditationTimerPreset> timers) {
    return TimerFolder(name: name, timers: timers);
  }

  TimerFolder withName(String name) {
    return TimerFolder(name: name, timers: timers);
  }
}

sealed class TimerBrowserEntry {
  const TimerBrowserEntry();

  String get id;
}

class TimerPresetEntry extends TimerBrowserEntry {
  const TimerPresetEntry(this.timer);

  final MeditationTimerPreset timer;

  @override
  String get id => 'timer-${timer.name}';
}

class TimerFolderEntry extends TimerBrowserEntry {
  const TimerFolderEntry(this.folder);

  final TimerFolder folder;

  @override
  String get id => 'folder-${folder.name}';
}

const _woodKnock = BellSound(
  name: 'Knock on wood',
  assetPath: '$_bellAssetRoot/wood-knock.mp3',
  tags: ['wood', 'short'],
  info: 'Thank you to ripper351 on freesound.org',
  url: 'https://freesound.org/people/ripper351/sounds/151088/',
);

const _bellVeryLong = BellSound(
  name: 'High and Long Meditation Bell',
  assetPath: '$_bellAssetRoot/bell-very-long.mp3',
  tags: ['bell', 'long'],
  info: 'Thank you to fauxpress on freesound.org',
  url: 'https://freesound.org/people/fauxpress/sounds/42095/',
);

const _bowlInG = BellSound(
  name: 'Meditation Bowl in G(ish)',
  assetPath: '$_bellAssetRoot/bowl-in-G-ish.mp3',
  tags: ['bowl', 'medium length'],
  info: 'Thank you to Squidocto on freesound.org',
  url: 'https://freesound.org/people/Squidocto/sounds/255762/',
);

const _bowlWahwah = BellSound(
  name: 'Wahwah Bowl',
  assetPath: '$_bellAssetRoot/bowl-wahwah.mp3',
  tags: ['bowl', 'medium length'],
  info: 'Thank you to qubodup and Monkay on freesound.org',
  url: 'https://freesound.org/people/qubodup/sounds/169289/',
);

const _bowlGong = BellSound(
  name: 'Gong Bowl',
  assetPath: '$_bellAssetRoot/bowl-gong.mp3',
  tags: ['bowl', 'medium length'],
  info: 'Thank you to Zambolino on freesound.org, found on pixabay.com',
  url:
      'https://pixabay.com/sound-effects/film-special-effects-singing-bowl-gong-69238/',
);

const _bowlHardStruck = BellSound(
  name: 'Hard-Struck Bowl in E-flat',
  assetPath: '$_bellAssetRoot/bowl-hard-struck.mp3',
  tags: ['bowl', 'medium length'],
  info: 'Thank you to mttvn on freesound.org',
  url: 'https://freesound.org/people/mttvn/sounds/535950/',
);

const _bowlLowAndLong = BellSound(
  name: 'Low and Long Singing Bowl',
  assetPath: '$_bellAssetRoot/bowl-low-and-long.mp3',
  tags: ['bowl', 'long'],
  info: 'Thank you to mttvn on freesound.org',
  url: 'https://freesound.org/people/mttvn/sounds/535950/',
);

const _bellSounds = [
  _woodKnock,
  _bellVeryLong,
  _bowlInG,
  _bowlWahwah,
  _bowlGong,
  _bowlHardStruck,
  _bowlLowAndLong,
];

const _twentyMinuteTimer = MeditationTimerPreset(
  id: 'timer-20-minutes',
  name: '20 minutes',
  duration: Duration(minutes: 20),
  startingBell: _woodKnock,
  endingBell: _bellVeryLong,
);

const _infiniteTimer = MeditationTimerPreset(
  id: 'timer-infinite-meditation',
  name: 'Infinite meditation',
  duration: null,
  startingBell: _woodKnock,
  endingBell: _bowlLowAndLong,
);

const _oneHourTimer = MeditationTimerPreset(
  id: 'timer-1-hour',
  name: '1 hour',
  duration: Duration(hours: 1),
  startingBell: _bowlInG,
  endingBell: _bowlLowAndLong,
);

const _longSessionsFolder = TimerFolder(
  name: 'Long sessions',
  timers: [_oneHourTimer],
);

const _knownTimers = [_twentyMinuteTimer, _infiniteTimer, _oneHourTimer];
const _knownFolders = [_longSessionsFolder];

const _defaultTimerEntries = [
  TimerPresetEntry(_twentyMinuteTimer),
  TimerPresetEntry(_infiniteTimer),
  TimerFolderEntry(_longSessionsFolder),
];

const _defaultRecentTimerLimit = 3;
const _maxRecentTimerLimit = 20;

String _newTimerId() {
  return 'timer-${DateTime.now().microsecondsSinceEpoch}';
}

String _legacyTimerId(String name) {
  final slug = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? _newTimerId() : 'timer-$slug';
}
