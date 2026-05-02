import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const BreathAndInsightTimerApp());
}

class BreathAndInsightTimerApp extends StatelessWidget {
  const BreathAndInsightTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Breath and Insight Timer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Colors.black,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

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
const _soundEnabledKey = 'soundEnabled';
const _bellAssetRoot = 'audio/bells';

class BellSound {
  const BellSound({required this.name, required this.assetPath});

  final String name;
  final String assetPath;
}

class MeditationTimerPreset {
  const MeditationTimerPreset({
    required this.name,
    required this.duration,
    required this.startingBell,
    required this.endingBell,
  });

  final String name;
  final Duration? duration;
  final BellSound startingBell;
  final BellSound endingBell;

  bool get isInfinite => duration == null;
}

class TimerFolder {
  const TimerFolder({required this.name, required this.timers});

  final String name;
  final List<MeditationTimerPreset> timers;
}

const _woodKnock = BellSound(
  name: 'Wood knock',
  assetPath: '$_bellAssetRoot/wood-knock.mp3',
);

const _singingBowlLong1 = BellSound(
  name: 'Singing bowl long 1',
  assetPath: '$_bellAssetRoot/singing-bowl--long--1.mp3',
);

const _singingBowlLong2 = BellSound(
  name: 'Singing bowl long 2',
  assetPath: '$_bellAssetRoot/singing-bowl--long--2.mp3',
);

const _singingBowlVeryLong1 = BellSound(
  name: 'Singing bowl very long 1',
  assetPath: '$_bellAssetRoot/singing-bowl--very-long--1.mp3',
);

const _twentyMinuteTimer = MeditationTimerPreset(
  name: '20 minutes',
  duration: Duration(minutes: 20),
  startingBell: _woodKnock,
  endingBell: _singingBowlLong1,
);

const _timers = [
  _twentyMinuteTimer,
  MeditationTimerPreset(
    name: 'Infinite meditation',
    duration: null,
    startingBell: _woodKnock,
    endingBell: _singingBowlVeryLong1,
  ),
];

const _oneHourTimer = MeditationTimerPreset(
  name: '1 hour',
  duration: Duration(hours: 1),
  startingBell: _singingBowlLong2,
  endingBell: _singingBowlVeryLong1,
);

const _timerFolders = [
  TimerFolder(name: 'Long sessions', timers: [_oneHourTimer]),
];

const _recentTimers = [_twentyMinuteTimer, _oneHourTimer];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeTab _selectedTab = HomeTab.timers;
  bool _recentTimersCollapsed = false;
  bool _soundEnabled = true;
  final AudioPlayer _settingsAudioPlayer = AudioPlayer();
  final Set<String> _expandedFolders = <String>{};

  @override
  void initState() {
    super.initState();
    _loadHomeSettings();
  }

  @override
  void dispose() {
    _settingsAudioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadHomeSettings() async {
    final preferences = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      _recentTimersCollapsed =
          preferences.getBool(_recentTimersCollapsedKey) ?? false;
      _soundEnabled = preferences.getBool(_soundEnabledKey) ?? true;
    });
  }

  void _selectTab(HomeTab tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  Future<void> _toggleRecentTimers() async {
    final nextValue = !_recentTimersCollapsed;
    setState(() {
      _recentTimersCollapsed = nextValue;
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_recentTimersCollapsedKey, nextValue);
  }

  Future<void> _setSoundEnabled({required bool enabled}) async {
    setState(() {
      _soundEnabled = enabled;
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_soundEnabledKey, enabled);
  }

  Future<void> _testSound() async {
    if (!_soundEnabled) {
      return;
    }

    await _settingsAudioPlayer.play(AssetSource(_woodKnock.assetPath));
  }

  void _toggleFolder(String folderName) {
    setState(() {
      if (_expandedFolders.contains(folderName)) {
        _expandedFolders.remove(folderName);
      } else {
        _expandedFolders.add(folderName);
      }
    });
  }

  void _startTimer(MeditationTimerPreset timer) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MeditationSessionScreen(timer: timer, playBells: _soundEnabled),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: _HomeTabBar(
                  selectedTab: _selectedTab,
                  onTabSelected: _selectTab,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Divider(height: 1, thickness: 1, color: _dividerColor),
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: _homeSurfaceColor,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                  child: _selectedTab == HomeTab.timers
                      ? _TimersTab(
                          recentTimersCollapsed: _recentTimersCollapsed,
                          expandedFolders: _expandedFolders,
                          onToggleRecentTimers: _toggleRecentTimers,
                          onToggleFolder: _toggleFolder,
                          onStartTimer: _startTimer,
                        )
                      : _selectedTab == HomeTab.stats
                      ? const _StatsTab()
                      : _SettingsTab(
                          soundEnabled: _soundEnabled,
                          onSoundEnabledChanged: (enabled) =>
                              _setSoundEnabled(enabled: enabled),
                          onTestSound: _testSound,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTabBar extends StatelessWidget {
  const _HomeTabBar({required this.selectedTab, required this.onTabSelected});

  final HomeTab selectedTab;
  final ValueChanged<HomeTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tab in [HomeTab.timers, HomeTab.stats])
          Expanded(
            child: _HomeTextTabButton(
              tab: tab,
              isSelected: tab == selectedTab,
              onPressed: () => onTabSelected(tab),
            ),
          ),
        _HomeSettingsTabButton(
          isSelected: selectedTab == HomeTab.settings,
          onPressed: () => onTabSelected(HomeTab.settings),
        ),
      ],
    );
  }
}

class _HomeTextTabButton extends StatelessWidget {
  const _HomeTextTabButton({
    required this.tab,
    required this.isSelected,
    required this.onPressed,
  });

  final HomeTab tab;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: ValueKey('${tab.name}-tab-button'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : const Color(0xFF77777C),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tab.label),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 2,
            width: isSelected ? 56 : 0,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _HomeSettingsTabButton extends StatelessWidget {
  const _HomeSettingsTabButton({
    required this.isSelected,
    required this.onPressed,
  });

  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('settings-tab-button'),
      onPressed: onPressed,
      tooltip: 'Settings',
      color: isSelected ? Colors.white : const Color(0xFF77777C),
      iconSize: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      icon: const Icon(Icons.settings_outlined),
    );
  }
}

class _TimersTab extends StatelessWidget {
  const _TimersTab({
    required this.recentTimersCollapsed,
    required this.expandedFolders,
    required this.onToggleRecentTimers,
    required this.onToggleFolder,
    required this.onStartTimer,
  });

  final bool recentTimersCollapsed;
  final Set<String> expandedFolders;
  final VoidCallback onToggleRecentTimers;
  final ValueChanged<String> onToggleFolder;
  final ValueChanged<MeditationTimerPreset> onStartTimer;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('timers-tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Recent timers',
          actionLabel: recentTimersCollapsed ? 'Expand' : 'Minimize',
          actionText: recentTimersCollapsed ? '+' : '-',
          onActionPressed: onToggleRecentTimers,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: recentTimersCollapsed
              ? const SizedBox(
                  key: ValueKey('recent-timers-collapsed'),
                  height: 8,
                )
              : Column(
                  key: const ValueKey('recent-timers-expanded'),
                  children: [
                    const SizedBox(height: 12),
                    for (final timer in _recentTimers)
                      _TimerRow(timer: timer, onTap: () => onStartTimer(timer)),
                  ],
                ),
        ),
        const SizedBox(height: 28),
        const _SectionHeader(title: 'Timers'),
        const SizedBox(height: 12),
        for (final timer in _timers)
          _TimerRow(timer: timer, onTap: () => onStartTimer(timer)),
        for (final folder in _timerFolders) ...[
          _FolderRow(
            folder: folder,
            isExpanded: expandedFolders.contains(folder.name),
            onTap: () => onToggleFolder(folder.name),
          ),
          if (expandedFolders.contains(folder.name))
            for (final timer in folder.timers)
              _TimerRow(
                timer: timer,
                isNested: true,
                onTap: () => onStartTimer(timer),
              ),
        ],
        const SizedBox(height: 420),
      ],
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(key: ValueKey('stats-tab'), height: 760);
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.soundEnabled,
    required this.onSoundEnabledChanged,
    required this.onTestSound,
  });

  final bool soundEnabled;
  final ValueChanged<bool> onSoundEnabledChanged;
  final VoidCallback onTestSound;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('settings-tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Settings'),
        const SizedBox(height: 12),
        Material(
          color: const Color(0xFF19191D),
          borderRadius: BorderRadius.circular(8),
          child: SwitchListTile(
            key: const ValueKey('sound-enabled-switch'),
            value: soundEnabled,
            onChanged: onSoundEnabledChanged,
            title: const Text(
              'Sound',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            subtitle: const Text(
              'Play starting and ending bells',
              style: TextStyle(
                color: _mutedTextColor,
                fontSize: 13,
                letterSpacing: 0,
              ),
            ),
            activeThumbColor: Colors.white,
            activeTrackColor: Color(0xFF6E6E76),
            inactiveThumbColor: Color(0xFF77777C),
            inactiveTrackColor: Color(0xFF2A2A2E),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            key: const ValueKey('test-sound-button'),
            onPressed: soundEnabled ? onTestSound : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF2A2A2E),
              foregroundColor: Colors.black,
              disabledForegroundColor: const Color(0xFF77777C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            icon: const Icon(Icons.volume_up_outlined),
            label: const Text('Test sound'),
          ),
        ),
        const SizedBox(height: 660),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.actionText,
    this.onActionPressed,
  });

  final String title;
  final String? actionLabel;
  final String? actionText;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
        if (onActionPressed != null)
          IconButton(
            key: ValueKey('${title.toLowerCase().replaceAll(' ', '-')}-toggle'),
            onPressed: onActionPressed,
            tooltip: actionLabel,
            color: Colors.white,
            iconSize: 28,
            icon: Text(
              actionText ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w300,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
      ],
    );
  }
}

class _TimerRow extends StatelessWidget {
  const _TimerRow({
    required this.timer,
    required this.onTap,
    this.isNested = false,
  });

  final MeditationTimerPreset timer;
  final VoidCallback onTap;
  final bool isNested;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: isNested ? 28 : 0, bottom: 10),
      child: Material(
        color: const Color(0xFF19191D),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('timer-${timer.name}-${isNested ? 'nested' : 'root'}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: Color(0xFFB7B7BC),
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timer.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timerDetails(timer),
                        style: const TextStyle(
                          color: _mutedTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.folder,
    required this.isExpanded,
    required this.onTap,
  });

  final TimerFolder folder;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('folder-${folder.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.folder_open_outlined
                      : Icons.folder_outlined,
                  color: const Color(0xFFB7B7BC),
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    folder.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MeditationSessionScreen extends StatefulWidget {
  const MeditationSessionScreen({
    super.key,
    this.timer = _twentyMinuteTimer,
    this.playBells = true,
  });

  final MeditationTimerPreset timer;
  final bool playBells;

  @override
  State<MeditationSessionScreen> createState() =>
      _MeditationSessionScreenState();
}

class _MeditationSessionScreenState extends State<MeditationSessionScreen> {
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _elapsed = Duration.zero;
  bool _isRunning = true;
  bool _isSessionActive = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
    if (widget.playBells) {
      unawaited(_playBell(widget.timer.startingBell));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final nextElapsed = _elapsed + const Duration(seconds: 1);
      final timerCompleted =
          !widget.timer.isInfinite && nextElapsed >= widget.timer.duration!;

      setState(() {
        _elapsed = nextElapsed;
        if (timerCompleted) {
          _isRunning = false;
        }
      });

      if (timerCompleted) {
        _timer?.cancel();
        if (widget.playBells) {
          unawaited(_playBell(widget.timer.endingBell));
        }
      }
    });
  }

  void _pauseSession() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resumeSession() {
    setState(() {
      _isRunning = true;
    });
    _startTimer();
  }

  void _finishSession() {
    if (widget.playBells) {
      unawaited(_playBell(widget.timer.endingBell));
    }
    _endSession();
  }

  void _discardSession() {
    _endSession();
  }

  void _endSession() {
    _timer?.cancel();
    setState(() {
      _isSessionActive = false;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _playBell(BellSound bell) async {
    await _audioPlayer.play(AssetSource(bell.assetPath));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSessionActive) {
      return const HomeScreen();
    }

    final displayedTime = _displayedSessionTime();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 72),
              const Center(
                child: Text(
                  'Meditation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF77777C),
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const Spacer(flex: 6),
              Center(
                child: Text(
                  _formatElapsed(displayedTime),
                  textAlign: TextAlign.center,
                  semanticsLabel: widget.timer.isInfinite
                      ? 'Elapsed time ${_formatElapsed(displayedTime)}'
                      : 'Time remaining ${_formatElapsed(displayedTime)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 84,
                    fontWeight: FontWeight.w300,
                    height: 1,
                    letterSpacing: 0,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Spacer(flex: 5),
              SizedBox(
                width: double.infinity,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [...previousChildren, ?currentChild],
                    );
                  },
                  child: _isRunning
                      ? _RunningControls(onPause: _pauseSession)
                      : _PausedControls(
                          onResume: _resumeSession,
                          onFinish: _finishSession,
                          onDiscard: _discardSession,
                        ),
                ),
              ),
              SizedBox(height: _isRunning ? 84 : 32),
            ],
          ),
        ),
      ),
    );
  }

  Duration _displayedSessionTime() {
    if (widget.timer.isInfinite) {
      return _elapsed;
    }

    final remaining = widget.timer.duration! - _elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class _RunningControls extends StatelessWidget {
  const _RunningControls({required this.onPause});

  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('running-controls'),
      onPressed: onPause,
      tooltip: 'Pause',
      iconSize: 72,
      color: Colors.white,
      icon: const Icon(Icons.pause_rounded),
    );
  }
}

class _PausedControls extends StatelessWidget {
  const _PausedControls({
    required this.onResume,
    required this.onFinish,
    required this.onDiscard,
  });

  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('paused-controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onResume,
          tooltip: 'Resume',
          iconSize: 72,
          color: Colors.white,
          icon: const Icon(Icons.play_arrow_rounded),
        ),
        const SizedBox(height: 96),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton(
            onPressed: onFinish,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            child: const Text('Finish'),
          ),
        ),
        const SizedBox(height: 28),
        TextButton(
          onPressed: onDiscard,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
          child: const Text('Discard session'),
        ),
      ],
    );
  }
}

String _formatElapsed(Duration elapsed) {
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }

  return '$minutes:$seconds';
}

String _timerDetails(MeditationTimerPreset timer) {
  final duration = timer.isInfinite
      ? 'Infinite'
      : _formatDuration(timer.duration!);

  return '$duration | ${timer.startingBell.name} -> ${timer.endingBell.name}';
}

String _formatDuration(Duration duration) {
  if (duration.inHours > 0 && duration.inMinutes.remainder(60) == 0) {
    final hours = duration.inHours;
    return hours == 1 ? '1 hour' : '$hours hours';
  }

  final minutes = duration.inMinutes;
  return minutes == 1 ? '1 minute' : '$minutes minutes';
}
