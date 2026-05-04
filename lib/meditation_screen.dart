part of 'main.dart';

class MeditationSessionScreen extends StatefulWidget {
  const MeditationSessionScreen({
    super.key,
    this.timer = _twentyMinuteTimer,
    this.playBells = true,
    this.turnScreenOnNearAudio = true,
    this.logStore = const MeditationLogStore(),
    this.backgroundTimerService = const BackgroundTimerService(),
    this.now = DateTime.now,
    this.setWakeLockEnabled = _setWakeLockEnabled,
    this.onBellPlayed,
    this.onSessionFinished,
  });

  final MeditationTimerPreset timer;
  final bool playBells;
  final bool turnScreenOnNearAudio;
  final MeditationLogStore logStore;
  final BackgroundTimerService backgroundTimerService;
  final DateTime Function() now;
  final Future<void> Function(bool enabled) setWakeLockEnabled;
  final ValueChanged<BellSound>? onBellPlayed;
  final ValueChanged<MeditationLogEntry>? onSessionFinished;

  @override
  State<MeditationSessionScreen> createState() =>
      _MeditationSessionScreenState();
}

class _MeditationSessionScreenState extends State<MeditationSessionScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _elapsed = Duration.zero;
  Duration _activeElapsedBeforeRun = Duration.zero;
  late final DateTime _startedAt;
  DateTime? _runStartedAt;
  int _lastProcessedElapsedSecond = 0;
  bool _isRunning = true;
  bool _isSessionActive = true;
  bool _isCompleting = false;
  bool _isSavingSummary = false;
  bool _prefersDisplayDimmed = false;
  bool _manuallyDimmedDuringRevealWindow = false;
  _MeditationSummary? _summary;
  MeditationLogEntry? _pendingEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startedAt = widget.now();
    _runStartedAt = _startedAt;
    unawaited(widget.setWakeLockEnabled(true));
    unawaited(widget.backgroundTimerService.start());
    _startTimer();
    if (widget.playBells && widget.timer.startingBell != null) {
      unawaited(_playBell(widget.timer.startingBell));
    } else if (widget.playBells) {
      unawaited(_playDueIntermediateBell(Duration.zero));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(widget.setWakeLockEnabled(false));
    unawaited(widget.backgroundTimerService.stop());
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isRunning && _summary == null) {
      _tickSession();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tickSession());
  }

  void _tickSession() {
    if (!_isRunning || _summary != null || _isCompleting) {
      return;
    }

    final nextElapsed = _currentElapsed();
    final timerCompleted =
        !widget.timer.isInfinite && nextElapsed >= widget.timer.duration!;
    final displayedElapsed = timerCompleted
        ? widget.timer.duration!
        : nextElapsed;
    final displayedElapsedSecond = displayedElapsed.inSeconds;

    setState(() {
      _elapsed = displayedElapsed;
      if (timerCompleted) {
        _isRunning = false;
      }
    });

    if (timerCompleted) {
      _timer?.cancel();
      _activeElapsedBeforeRun = displayedElapsed;
      _runStartedAt = null;
      _lastProcessedElapsedSecond = displayedElapsedSecond;
      unawaited(_completeSession(playEndingBell: true, forceEndingBell: true));
    } else if (widget.playBells &&
        displayedElapsedSecond > _lastProcessedElapsedSecond) {
      _lastProcessedElapsedSecond = displayedElapsedSecond;
      unawaited(_playDueIntermediateBell(displayedElapsed));
    }
  }

  void _toggleDisplayDimmed() {
    final shouldReveal = _shouldRevealDisplay(_sessionElapsedForDisplayState());
    final screenDimmed =
        _prefersDisplayDimmed &&
        (_manuallyDimmedDuringRevealWindow || !shouldReveal);
    setState(() {
      if (screenDimmed) {
        _prefersDisplayDimmed = false;
        _manuallyDimmedDuringRevealWindow = false;
      } else {
        _prefersDisplayDimmed = true;
        _manuallyDimmedDuringRevealWindow = shouldReveal;
      }
    });
  }

  void _pauseSession() {
    _timer?.cancel();
    _activeElapsedBeforeRun = _currentElapsed();
    _runStartedAt = null;
    setState(() {
      _elapsed = _activeElapsedBeforeRun;
      _isRunning = false;
    });
  }

  void _resumeSession() {
    _runStartedAt = widget.now();
    setState(() {
      _isRunning = true;
    });
    _startTimer();
  }

  Future<void> _completeSession({
    required bool playEndingBell,
    bool forceEndingBell = false,
  }) async {
    if (_isCompleting || _summary != null) {
      return;
    }

    _timer?.cancel();
    final completedElapsed = _completedElapsed();
    _activeElapsedBeforeRun = completedElapsed;
    _runStartedAt = null;
    setState(() {
      _elapsed = completedElapsed;
      _isCompleting = true;
      _isRunning = false;
    });

    if (playEndingBell &&
        (forceEndingBell || widget.playBells) &&
        widget.timer.endingBell != null) {
      unawaited(_playBell(widget.timer.endingBell));
    }

    final entry = MeditationLogEntry(
      id: _newLogId(),
      startedAt: _startedAt,
      duration: completedElapsed,
      preset: widget.timer.name,
      activity: widget.timer.activity,
    );
    final existingEntries = await widget.logStore.allEntries();

    if (!mounted) {
      return;
    }

    setState(() {
      _pendingEntry = entry;
      _summary = _summaryForCompletedSession(existingEntries, entry);
      _isCompleting = false;
    });
  }

  Future<void> _continueAfterSummary() async {
    if (_isSavingSummary) {
      return;
    }

    final entry = _pendingEntry;
    if (entry == null) {
      _endSession();
      return;
    }

    setState(() {
      _isSavingSummary = true;
    });

    if (widget.onSessionFinished != null) {
      widget.onSessionFinished!(entry);
    } else {
      await widget.logStore.append(entry);
    }

    if (!mounted) {
      return;
    }

    _endSession();
  }

  void _discardSession() {
    _endSession();
  }

  void _endSession() {
    _timer?.cancel();
    unawaited(widget.setWakeLockEnabled(false));
    unawaited(widget.backgroundTimerService.stop());
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSessionActive = false;
      _elapsed = Duration.zero;
      _activeElapsedBeforeRun = Duration.zero;
      _runStartedAt = null;
      _lastProcessedElapsedSecond = 0;
      _prefersDisplayDimmed = false;
      _manuallyDimmedDuringRevealWindow = false;
    });
  }

  Future<void> _playBell(BellSound? bell) async {
    if (bell == null) {
      return;
    }

    if (widget.onBellPlayed != null) {
      widget.onBellPlayed!(bell);
      return;
    }

    await _audioPlayer.play(AssetSource(bell.assetPath));
  }

  Future<void> _playDueIntermediateBell(Duration elapsed) async {
    for (final bell in widget.timer.intermediateBells) {
      if (_isIntermediateBellDue(bell, elapsed)) {
        await _playBell(bell.bell);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSessionActive) {
      return const HomeScreen();
    }

    final summary = _summary;
    if (summary != null) {
      return _MeditationSummaryScreen(
        summary: summary,
        isSaving: _isSavingSummary,
        onContinue: _continueAfterSummary,
        onDiscard: _discardSession,
      );
    }

    final displayedTime = _displayedSessionTime();
    final elapsedForDisplay = _sessionElapsedForDisplayState();
    final shouldReveal = _shouldRevealDisplay(elapsedForDisplay);
    final screenDimmed =
        _prefersDisplayDimmed &&
        (_manuallyDimmedDuringRevealWindow || !shouldReveal);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              key: const ValueKey('meditation-screen-toggle-zone'),
              behavior: HitTestBehavior.opaque,
              onTap: _toggleDisplayDimmed,
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
                    const Spacer(flex: 4),
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
                                isInfiniteTimer: widget.timer.isInfinite,
                                onFinishWithBell: () => unawaited(
                                  _completeSession(playEndingBell: true),
                                ),
                                onFinishWithoutBell: () => unawaited(
                                  _completeSession(playEndingBell: false),
                                ),
                                onDiscard: _discardSession,
                              ),
                      ),
                    ),
                    SizedBox(height: _isRunning ? 84 : 16),
                  ],
                ),
              ),
            ),
            if (screenDimmed)
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('meditation-display-dimmed-overlay'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleDisplayDimmed,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Duration _displayedSessionTime() {
    final elapsed = _sessionElapsedForDisplayState();
    if (widget.timer.isInfinite) {
      return elapsed;
    }

    final remaining = widget.timer.duration! - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration _sessionElapsedForDisplayState() {
    if (_isRunning) {
      return _currentElapsed();
    }

    return _elapsed;
  }

  bool _shouldRevealDisplay(Duration elapsed) {
    if (!widget.playBells || !widget.turnScreenOnNearAudio) {
      return false;
    }

    return _bellVisibilityWindows(widget.timer).any((window) {
      return elapsed >= window.start && elapsed <= window.end;
    });
  }

  Duration _currentElapsed() {
    final runStartedAt = _runStartedAt;
    if (!_isRunning || runStartedAt == null) {
      return _activeElapsedBeforeRun;
    }

    final elapsed =
        _activeElapsedBeforeRun + widget.now().difference(runStartedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Duration _completedElapsed() {
    final elapsed = _currentElapsed();
    if (!widget.timer.isInfinite && elapsed >= widget.timer.duration!) {
      return widget.timer.duration!;
    }

    return elapsed;
  }
}

Future<void> _setWakeLockEnabled(bool enabled) async {
  try {
    if (enabled) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  } on MissingPluginException {
    // Widget tests and unsupported platforms should not crash session timing.
  }
}

class _BellVisibilityWindow {
  const _BellVisibilityWindow({required this.start, required this.end});

  final Duration start;
  final Duration end;
}

List<_BellVisibilityWindow> _bellVisibilityWindows(
  MeditationTimerPreset timer,
) {
  const revealBeforeBell = Duration(seconds: 10);
  const revealAfterBell = Duration(seconds: 30);
  final windows = <_BellVisibilityWindow>[];

  void addWindow(Duration bellTime) {
    final start = bellTime - revealBeforeBell;
    windows.add(
      _BellVisibilityWindow(
        start: start.isNegative ? Duration.zero : start,
        end: bellTime + revealAfterBell,
      ),
    );
  }

  final timerDuration = timer.duration;
  if (timerDuration != null && timer.endingBell != null) {
    addWindow(timerDuration);
  }

  for (final bell in timer.intermediateBells) {
    if (timerDuration == null) {
      addWindow(bell.startTime);
      final repeatInterval = bell.repeatInterval;
      if (repeatInterval != null && repeatInterval.inSeconds > 0) {
        for (var repeatIndex = 1; repeatIndex <= 48; repeatIndex += 1) {
          addWindow(
            bell.startTime +
                Duration(
                  microseconds: repeatInterval.inMicroseconds * repeatIndex,
                ),
          );
        }
      }
      continue;
    }

    var bellTime = bell.startTime;
    final repeatInterval = bell.repeatInterval;
    while (bellTime < timerDuration) {
      addWindow(bellTime);
      if (repeatInterval == null || repeatInterval.inSeconds <= 0) {
        break;
      }
      bellTime += repeatInterval;
    }
  }

  return windows;
}

class _MeditationSummary {
  const _MeditationSummary({
    required this.completedDuration,
    required this.totalTimeToday,
    required this.streakLength,
    required this.streakAlreadyIncreasedToday,
  });

  final Duration completedDuration;
  final Duration totalTimeToday;
  final int streakLength;
  final bool streakAlreadyIncreasedToday;
}

class _MeditationSummaryScreen extends StatelessWidget {
  const _MeditationSummaryScreen({
    required this.summary,
    required this.isSaving,
    required this.onContinue,
    required this.onDiscard,
  });

  final _MeditationSummary summary;
  final bool isSaving;
  final VoidCallback onContinue;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final streakLabel = summary.streakAlreadyIncreasedToday
        ? 'Your streak today is:'
        : 'Your streak has increased to:';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Summary',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF77777C),
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(flex: 2),
              _SummaryMetric(
                label: 'You completed:',
                value: _formatElapsed(summary.completedDuration),
              ),
              const SizedBox(height: 44),
              _SummaryMetric(
                label: 'Total time today:',
                value: _formatElapsed(summary.totalTimeToday),
              ),
              const SizedBox(height: 44),
              _SummaryMetric(
                label: streakLabel,
                value: summary.streakLength.toString(),
              ),
              const Spacer(flex: 3),
              SizedBox(
                height: 56,
                child: FilledButton(
                  key: const ValueKey('summary-continue-button'),
                  onPressed: isSaving ? null : onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  child: Text(isSaving ? 'Saving...' : 'Continue'),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                key: const ValueKey('summary-discard-button'),
                onPressed: onDiscard,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
                child: const Text('Discard session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF77777C),
            fontSize: 18,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          key: ValueKey('summary-value-$label'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 54,
            fontWeight: FontWeight.w300,
            height: 1,
            letterSpacing: 0,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

bool _isIntermediateBellDue(IntermediateBell bell, Duration elapsed) {
  if (elapsed < bell.startTime) {
    return false;
  }

  if (elapsed == bell.startTime) {
    return true;
  }

  final repeatInterval = bell.repeatInterval;
  if (repeatInterval == null || repeatInterval.inSeconds <= 0) {
    return false;
  }

  final elapsedSinceStart = elapsed - bell.startTime;
  return elapsedSinceStart.inSeconds % repeatInterval.inSeconds == 0;
}

_MeditationSummary _summaryForCompletedSession(
  List<MeditationLogEntry> existingEntries,
  MeditationLogEntry completedEntry,
) {
  final todayDayNumber = _dayNumber(DateTime.now());
  final existingEntriesToday = existingEntries.where(
    (entry) => _dayNumber(entry.startedAt) == todayDayNumber,
  );
  final existingSecondsToday = existingEntriesToday.fold<int>(
    0,
    (total, entry) => total + entry.duration.inSeconds,
  );
  final completedSecondsToday =
      _dayNumber(completedEntry.startedAt) == todayDayNumber
      ? completedEntry.duration.inSeconds
      : 0;
  final entriesAfterCompletion = [completedEntry, ...existingEntries];

  return _MeditationSummary(
    completedDuration: completedEntry.duration,
    totalTimeToday: Duration(
      seconds: existingSecondsToday + completedSecondsToday,
    ),
    streakLength: _streakLengthThroughToday(entriesAfterCompletion),
    streakAlreadyIncreasedToday: existingEntriesToday.isNotEmpty,
  );
}

int _streakLengthThroughToday(List<MeditationLogEntry> entries) {
  final loggedDays = {for (final entry in entries) _dayNumber(entry.startedAt)};

  var cursor = _dayNumber(DateTime.now());
  var streakLength = 0;
  while (loggedDays.contains(cursor)) {
    streakLength += 1;
    cursor -= 1;
  }

  return streakLength;
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
    required this.isInfiniteTimer,
    required this.onFinishWithBell,
    required this.onFinishWithoutBell,
    required this.onDiscard,
  });

  final VoidCallback onResume;
  final bool isInfiniteTimer;
  final VoidCallback onFinishWithBell;
  final VoidCallback onFinishWithoutBell;
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
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: onFinishWithBell,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            child: Text(
              isInfiniteTimer
                  ? 'Finish (play bell)'
                  : 'Finish early (play bell)',
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: onFinishWithoutBell,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            child: Text(
              isInfiniteTimer ? 'Finish (no bell)' : 'Finish early (no bell)',
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: onDiscard,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 18,
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

String _formatClockDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _timerDetails(MeditationTimerPreset timer) {
  final duration = timer.isInfinite
      ? 'Infinite'
      : _formatDuration(timer.duration!);

  final note = timer.note.trim();
  return note.isEmpty ? duration : '$duration | $note';
}

String _formatDuration(Duration duration) {
  final parts = <String>[];
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    parts.add(hours == 1 ? '1 hour' : '$hours hours');
  }

  if (minutes > 0) {
    parts.add(minutes == 1 ? '1 minute' : '$minutes minutes');
  }

  if (seconds > 0 || parts.isEmpty) {
    parts.add(seconds == 1 ? '1 second' : '$seconds seconds');
  }

  return parts.join(' ');
}
