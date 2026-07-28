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
    this.onDetachedEndingBellRequested,
    this.onSessionFinished,
    this.onMinimizeRequested,
    this.onSessionClosed,
    this.onElapsedChanged,
    this.pranayamaSessionListenable,
    this.pranayamaEntries = const <PranayamaBrowserEntry>[],
    this.recentPranayamaPresets = const <PranayamaPreset>[],
    this.expandedPranayamaFolders = const <String>{},
    this.onStartPranayamaPreset,
    this.onTogglePranayamaPaused,
    this.onStopPranayama,
  });

  final MeditationTimerPreset timer;
  final bool playBells;
  final bool turnScreenOnNearAudio;
  final MeditationLogStore logStore;
  final BackgroundTimerService backgroundTimerService;
  final DateTime Function() now;
  final Future<void> Function(bool enabled) setWakeLockEnabled;
  final ValueChanged<BellSound>? onBellPlayed;
  final ValueChanged<BellSound>? onDetachedEndingBellRequested;
  final ValueChanged<MeditationLogEntry>? onSessionFinished;
  final VoidCallback? onMinimizeRequested;
  final VoidCallback? onSessionClosed;
  final ValueChanged<Duration>? onElapsedChanged;
  final ValueListenable<PranayamaSessionSnapshot>? pranayamaSessionListenable;
  final List<PranayamaBrowserEntry> pranayamaEntries;
  final List<PranayamaPreset> recentPranayamaPresets;
  final Set<String> expandedPranayamaFolders;
  final ValueChanged<PranayamaPreset>? onStartPranayamaPreset;
  final VoidCallback? onTogglePranayamaPaused;
  final VoidCallback? onStopPranayama;

  @override
  State<MeditationSessionScreen> createState() =>
      _MeditationSessionScreenState();
}

class _MeditationSessionScreenState extends State<MeditationSessionScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  final FocusNode _shortcutFocusNode = FocusNode(
    debugLabel: 'Meditation session shortcuts',
  );
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _elapsed = Duration.zero;
  // Raw session time includes preparation. The public meditation clock and logs
  // subtract preparation time so existing statistics keep their meaning.
  Duration _activeElapsedBeforeRun = Duration.zero;
  late final DateTime _startedAt;
  DateTime? _runStartedAt;
  DateTime? _meditationStartedAt;
  int _lastProcessedElapsedSecond = 0;
  bool _isRunning = true;
  bool _isSessionActive = true;
  bool _isCompleting = false;
  bool _isSavingSummary = false;
  bool _prefersDisplayDimmed = false;
  bool _manuallyDimmedDuringRevealWindow = false;
  bool _pausedPranayamaWithMeditation = false;
  bool _stoppedConcurrentPranayamaForSessionEnd = false;
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
    _requestShortcutFocus();
    _startMeditationIfReady(Duration.zero);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(widget.setWakeLockEnabled(false));
    unawaited(widget.backgroundTimerService.stop());
    _shortcutFocusNode.dispose();
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

  void _requestShortcutFocus() {
    if (widget.onMinimizeRequested == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_shortcutFocusNode.hasFocus) {
        _shortcutFocusNode.requestFocus();
      }
    });
  }

  void _tickSession() {
    if (!_isRunning || _summary != null || _isCompleting) {
      return;
    }

    final sessionElapsed = _currentSessionElapsed();
    _startMeditationIfReady(sessionElapsed);
    final nextElapsed = _currentElapsedFromSessionElapsed(sessionElapsed);
    if (_meditationStartedAt == null) {
      setState(() {
        _elapsed = Duration.zero;
      });
      _notifyElapsedChanged(Duration.zero);
      return;
    }

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
    _notifyElapsedChanged(displayedElapsed);

    if (timerCompleted) {
      _timer?.cancel();
      _activeElapsedBeforeRun = sessionElapsed;
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
    final shouldReveal = _shouldRevealDisplay(_sessionClockForDisplayState());
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
    final pranayamaSnapshot = widget.pranayamaSessionListenable?.value;
    if (pranayamaSnapshot != null &&
        pranayamaSnapshot.isActive &&
        !pranayamaSnapshot.isPaused) {
      _pausedPranayamaWithMeditation = true;
      widget.onTogglePranayamaPaused?.call();
    }

    _timer?.cancel();
    _activeElapsedBeforeRun = _currentSessionElapsed();
    _runStartedAt = null;
    final meditationElapsed = _currentElapsedFromSessionElapsed(
      _activeElapsedBeforeRun,
    );
    setState(() {
      _elapsed = meditationElapsed;
      _isRunning = false;
    });
    _notifyElapsedChanged(meditationElapsed);
  }

  void _resumeSession() {
    final pranayamaSnapshot = widget.pranayamaSessionListenable?.value;
    if (_pausedPranayamaWithMeditation &&
        pranayamaSnapshot != null &&
        pranayamaSnapshot.isActive &&
        pranayamaSnapshot.isPaused) {
      widget.onTogglePranayamaPaused?.call();
    }
    _pausedPranayamaWithMeditation = false;

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
    final completedSessionElapsed = _currentSessionElapsed();
    _startMeditationIfReady(completedSessionElapsed);
    final completedElapsed = _completedElapsedFromSessionElapsed(
      completedSessionElapsed,
    );
    _activeElapsedBeforeRun = completedSessionElapsed;
    _runStartedAt = null;
    setState(() {
      _elapsed = completedElapsed;
      _isCompleting = true;
      _isRunning = false;
    });
    _notifyElapsedChanged(completedElapsed);
    _stopConcurrentPranayamaIfActive();

    if (playEndingBell &&
        (forceEndingBell || widget.playBells) &&
        widget.timer.endingBell != null) {
      // Prefer a detached player owned by HomeScreen. Otherwise popping this
      // route from the summary would dispose the local player and cut the bell.
      final detachedPlayer = widget.onDetachedEndingBellRequested;
      if (detachedPlayer != null) {
        detachedPlayer(widget.timer.endingBell!);
      } else {
        unawaited(_playBell(widget.timer.endingBell));
      }
    }

    final entry = MeditationLogEntry(
      id: _newLogId(),
      startedAt: _meditationStartedAt ?? _startedAt,
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

  void _discardFromHost() {
    _discardSession();
  }

  Future<void> _selectPranayamaPreset() async {
    final selectedPreset = await Navigator.of(context).push<PranayamaPreset>(
      MaterialPageRoute<PranayamaPreset>(
        builder: (_) => PranayamaPresetPickerScreen(
          recentPresets: widget.recentPranayamaPresets,
          presetEntries: widget.pranayamaEntries,
          expandedFolders: widget.expandedPranayamaFolders,
        ),
      ),
    );

    if (!mounted || selectedPreset == null) {
      return;
    }

    _pausedPranayamaWithMeditation = false;
    widget.onStartPranayamaPreset?.call(selectedPreset);
  }

  void _stopMeditationPranayama() {
    _pausedPranayamaWithMeditation = false;
    widget.onStopPranayama?.call();
  }

  void _stopConcurrentPranayamaIfActive() {
    if (_stoppedConcurrentPranayamaForSessionEnd) {
      return;
    }

    final pranayamaSnapshot = widget.pranayamaSessionListenable?.value;
    if (pranayamaSnapshot == null || !pranayamaSnapshot.isActive) {
      return;
    }

    _pausedPranayamaWithMeditation = false;
    _stoppedConcurrentPranayamaForSessionEnd = true;
    widget.onStopPranayama?.call();
  }

  void _endSession() {
    _timer?.cancel();
    _stopConcurrentPranayamaIfActive();
    unawaited(widget.setWakeLockEnabled(false));
    unawaited(widget.backgroundTimerService.stop());
    final onSessionClosed = widget.onSessionClosed;
    if (onSessionClosed != null) {
      onSessionClosed();
      return;
    }
    // When launched from HomeScreen, return to that existing route so concurrent
    // pranayama state/audio remains visible and controllable. Widget tests can
    // still mount this screen directly, so keep the in-place fallback below.
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
      _meditationStartedAt = null;
      _prefersDisplayDimmed = false;
      _manuallyDimmedDuringRevealWindow = false;
    });
  }

  void _startMeditationIfReady(Duration sessionElapsed) {
    if (_meditationStartedAt != null ||
        sessionElapsed < _preparationDuration()) {
      return;
    }

    final meditationElapsed = _currentElapsedFromSessionElapsed(sessionElapsed);
    _meditationStartedAt = widget.now().subtract(meditationElapsed);
    _lastProcessedElapsedSecond = 0;

    if (!widget.playBells) {
      return;
    }

    if (widget.timer.startingBell != null) {
      unawaited(_playBell(widget.timer.startingBell));
    } else {
      unawaited(_playDueIntermediateBell(Duration.zero));
    }
  }

  void _notifyElapsedChanged(Duration elapsed) {
    widget.onElapsedChanged?.call(elapsed);
  }

  Future<void> _playBell(BellSound? bell) async {
    if (bell == null) {
      return;
    }

    if (widget.onBellPlayed != null) {
      widget.onBellPlayed!(bell);
      return;
    }

    await _configurePlayerForAudioMixing(_audioPlayer);
    try {
      await _audioPlayer.play(AssetSource(bell.assetPath));
    } on Object {
      return;
    }
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
    final content = _buildSessionContent(context);
    final onMinimizeRequested = widget.onMinimizeRequested;
    if (onMinimizeRequested == null) {
      return content;
    }
    _requestShortcutFocus();

    return Focus(
      focusNode: _shortcutFocusNode,
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            HardwareKeyboard.instance.isAltPressed) {
          onMinimizeRequested();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            onMinimizeRequested();
          }
        },
        child: content,
      ),
    );
  }

  Widget _buildSessionContent(BuildContext context) {
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
    final sessionElapsedForDisplay = _sessionClockForDisplayState();
    final isPreparing = _isPreparingForDisplayState();
    final shouldReveal = _shouldRevealDisplay(sessionElapsedForDisplay);
    final screenDimmed =
        _prefersDisplayDimmed &&
        (_manuallyDimmedDuringRevealWindow || !shouldReveal);
    final activityTitle = widget.timer.activity.trim().isEmpty
        ? 'Meditation'
        : widget.timer.activity.trim();

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
                    Center(
                      child: Text(
                        activityTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF77777C),
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    _MeditationPranayamaPanelHost(
                      listenable: widget.pranayamaSessionListenable,
                    ),
                    const Spacer(flex: 6),
                    Center(
                      child: Text(
                        _formatElapsed(displayedTime),
                        textAlign: TextAlign.center,
                        semanticsLabel: isPreparing
                            ? 'Preparation time remaining ${_formatElapsed(displayedTime)}'
                            : widget.timer.isInfinite
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
                    if (isPreparing) ...[
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'Preparation',
                          style: TextStyle(
                            color: Color(0xFF77777C),
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
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
            _MeditationPranayamaActionButton(
              listenable: widget.pranayamaSessionListenable,
              canSelect: widget.onStartPranayamaPreset != null,
              onSelect: _selectPranayamaPreset,
              onStop: _stopMeditationPranayama,
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
    if (_isPreparingForDisplayState()) {
      final remaining = _preparationDuration() - _sessionClockForDisplayState();
      return remaining.isNegative ? Duration.zero : remaining;
    }

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

  Duration _sessionClockForDisplayState() {
    if (_isRunning) {
      return _currentSessionElapsed();
    }

    return _activeElapsedBeforeRun;
  }

  bool _isPreparingForDisplayState() {
    return _meditationStartedAt == null &&
        _sessionClockForDisplayState() < _preparationDuration();
  }

  bool _shouldRevealDisplay(Duration sessionElapsed) {
    if (!widget.playBells || !widget.turnScreenOnNearAudio) {
      return false;
    }

    return _bellVisibilityWindows(widget.timer).any((window) {
      return sessionElapsed >= window.start && sessionElapsed <= window.end;
    });
  }

  Duration _currentElapsed() {
    return _currentElapsedFromSessionElapsed(_currentSessionElapsed());
  }

  Duration _currentSessionElapsed() {
    final runStartedAt = _runStartedAt;
    if (!_isRunning || runStartedAt == null) {
      return _activeElapsedBeforeRun;
    }

    final elapsed =
        _activeElapsedBeforeRun + widget.now().difference(runStartedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Duration _currentElapsedFromSessionElapsed(Duration sessionElapsed) {
    final meditationElapsed = sessionElapsed - _preparationDuration();
    return meditationElapsed.isNegative ? Duration.zero : meditationElapsed;
  }

  Duration _preparationDuration() {
    final preparationDuration = widget.timer.preparationDuration;
    return preparationDuration.isNegative ? Duration.zero : preparationDuration;
  }

  Duration _completedElapsedFromSessionElapsed(Duration sessionElapsed) {
    final elapsed = _currentElapsedFromSessionElapsed(sessionElapsed);
    if (!widget.timer.isInfinite && elapsed >= widget.timer.duration!) {
      return widget.timer.duration!;
    }

    return elapsed;
  }
}

class PranayamaPresetPickerScreen extends StatefulWidget {
  const PranayamaPresetPickerScreen({
    super.key,
    required this.recentPresets,
    required this.presetEntries,
    required this.expandedFolders,
  });

  final List<PranayamaPreset> recentPresets;
  final List<PranayamaBrowserEntry> presetEntries;
  final Set<String> expandedFolders;

  @override
  State<PranayamaPresetPickerScreen> createState() =>
      _PranayamaPresetPickerScreenState();
}

class _PranayamaPresetPickerScreenState
    extends State<PranayamaPresetPickerScreen> {
  late final Set<String> _expandedFolders = Set<String>.of(
    widget.expandedFolders,
  );

  void _toggleFolder(String folderName) {
    setState(() {
      if (!_expandedFolders.add(folderName)) {
        _expandedFolders.remove(folderName);
      }
    });
  }

  void _selectPreset(PranayamaPreset preset) {
    Navigator.of(context).pop(preset);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _PranayamaPickerTitleBar(
              onClose: () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1, thickness: 1, color: _dividerColor),
            Expanded(
              child: SingleChildScrollView(
                child: ColoredBox(
                  color: _homeSurfaceColor,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionHeader(title: 'Recent presets'),
                        const SizedBox(height: 12),
                        if (widget.recentPresets.isEmpty)
                          const _EmptyPranayamaRecentPresetsMessage()
                        else
                          for (final preset in widget.recentPresets)
                            _PranayamaPresetRow(
                              preset: preset,
                              keySuffix: 'picker-recent',
                              onTap: () => _selectPreset(preset),
                            ),
                        const SizedBox(height: 28),
                        const _SectionHeader(title: 'Presets'),
                        const SizedBox(height: 12),
                        _PranayamaBrowser(
                          entries: widget.presetEntries,
                          expandedFolders: _expandedFolders,
                          onToggleFolder: _toggleFolder,
                          onStartPreset: _selectPreset,
                        ),
                        const SizedBox(height: 280),
                      ],
                    ),
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

class _PranayamaPickerTitleBar extends StatelessWidget {
  const _PranayamaPickerTitleBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('close-pranayama-picker-button'),
            onPressed: onClose,
            tooltip: 'Cancel',
            icon: const Icon(Icons.close_rounded),
          ),
          const Expanded(
            child: Text(
              'Select preset',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _MeditationPranayamaActionButton extends StatelessWidget {
  const _MeditationPranayamaActionButton({
    required this.listenable,
    required this.canSelect,
    required this.onSelect,
    required this.onStop,
  });

  final ValueListenable<PranayamaSessionSnapshot>? listenable;
  final bool canSelect;
  final VoidCallback onSelect;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final sessionListenable = listenable;
    if (sessionListenable == null || !canSelect) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 106,
      right: 24,
      child: ValueListenableBuilder<PranayamaSessionSnapshot>(
        valueListenable: sessionListenable,
        builder: (context, snapshot, _) {
          final isActive = snapshot.isActive;
          return Material(
            color: const Color(0xFF111114),
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              key: ValueKey(
                isActive
                    ? 'stop-meditation-pranayama-button'
                    : 'select-pranayama-preset-button',
              ),
              onPressed: isActive ? onStop : onSelect,
              tooltip: isActive ? 'Stop pranayama' : 'Select pranayama preset',
              icon: Icon(
                isActive ? Icons.stop_rounded : Icons.air_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MeditationPranayamaPanelHost extends StatelessWidget {
  const _MeditationPranayamaPanelHost({required this.listenable});

  final ValueListenable<PranayamaSessionSnapshot>? listenable;

  @override
  Widget build(BuildContext context) {
    final sessionListenable = listenable;
    if (sessionListenable == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<PranayamaSessionSnapshot>(
      valueListenable: sessionListenable,
      builder: (context, snapshot, _) {
        if (!snapshot.isActive) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: SizedBox(
            key: const ValueKey('meditation-pranayama-panel'),
            height: 210,
            child: _MeditationPranayamaPanel(snapshot: snapshot),
          ),
        );
      },
    );
  }
}

class _MeditationPranayamaPanel extends StatelessWidget {
  const _MeditationPranayamaPanel({required this.snapshot});

  final PranayamaSessionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final preset = snapshot.preset!;
    final phase = _phaseSnapshotForPranayama(preset, snapshot.elapsed);
    final segmentPosition = _pranayamaSegmentAtElapsed(
      preset,
      snapshot.elapsed,
    );
    final activeSegment = segmentPosition.segment;
    final segmentRemaining = _remainingPranayamaSegmentDuration(
      segmentPosition,
    );
    final bpm = activeSegment.cycleDuration == Duration.zero
        ? 0.0
        : 60 / activeSegment.cycleDuration.inMilliseconds * 1000;

    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF26262B)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MeditationPranayamaWavePainter(
                  preset: preset,
                  elapsed: snapshot.elapsed,
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 12,
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Color(0xFFAAAAB0),
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                  letterSpacing: 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clock: ${_formatPranayamaSegmentRemaining(segmentRemaining)}',
                    ),
                    Text('Breaths: ${phase.breathCount}'),
                    Text('BPM: ${bpm.toStringAsFixed(1)}'),
                  ],
                ),
              ),
            ),
            Center(
              child: Text(
                snapshot.isPaused ? 'Paused' : phase.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0,
                ),
              ),
            ),
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFBDBDC2)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 7,
                    ),
                    child: Text(
                      preset.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
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

Duration? _remainingPranayamaSegmentDuration(
  PranayamaSegmentPosition segmentPosition,
) {
  final effectiveDuration = _effectivePranayamaSegmentDuration(
    segmentPosition.segment,
  );
  if (effectiveDuration == null) {
    return null;
  }

  final remaining = effectiveDuration - segmentPosition.localElapsed;
  return remaining.isNegative ? Duration.zero : remaining;
}

String _formatPranayamaSegmentRemaining(Duration? duration) {
  if (duration == null) {
    return '--:--';
  }
  return _formatTimerDisplay(duration);
}

class _MeditationPranayamaWavePainter extends CustomPainter {
  const _MeditationPranayamaWavePainter({
    required this.preset,
    required this.elapsed,
  });

  final PranayamaPreset preset;
  final Duration elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xDDEFEFF1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final transitionLinePaint = Paint()
      ..color = const Color(0x6677777C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final activeDotPaint = Paint()..color = Colors.white;
    final transitionDotPaint = Paint()..color = const Color(0x99FFFFFF);
    final guide = _PranayamaPathGuide.fromPreset(
      preset,
      elapsed: elapsed,
      size: size,
    );

    final path = Path()
      ..moveTo(guide.start.dx, guide.start.dy)
      ..lineTo(guide.afterInhale.dx, guide.afterInhale.dy)
      ..lineTo(guide.afterFirstHold.dx, guide.afterFirstHold.dy)
      ..lineTo(guide.afterExhale.dx, guide.afterExhale.dy)
      ..lineTo(guide.end.dx, guide.end.dy);

    canvas.drawPath(path, linePaint);
    _drawDashedLine(
      canvas,
      guide.leadingStart,
      guide.start,
      transitionLinePaint,
    );
    _drawDashedLine(canvas, guide.end, guide.trailingEnd, transitionLinePaint);
    for (final dot in guide.transitionDots) {
      canvas.drawCircle(dot, 7, transitionDotPaint);
    }
    canvas.drawCircle(guide.activeDot, 9, activeDotPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 7.0;
    const gapLength = 7.0;
    final delta = end - start;
    final distance = delta.distance;
    if (distance <= 0) {
      return;
    }

    final direction = delta / distance;
    var cursor = 0.0;
    while (cursor < distance) {
      final next = (cursor + dashLength).clamp(0.0, distance);
      canvas.drawLine(
        start + direction * cursor,
        start + direction * next,
        paint,
      );
      cursor = next + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _MeditationPranayamaWavePainter oldDelegate) {
    return oldDelegate.preset != preset || oldDelegate.elapsed != elapsed;
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
  } on Object {
    // Some Linux desktop portals can reject or expire wakelock requests while
    // the timer itself is behaving correctly. Treat wakelock as best-effort so
    // desktop testing does not emit unhandled asynchronous exceptions.
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
  final preparationDuration = timer.preparationDuration.isNegative
      ? Duration.zero
      : timer.preparationDuration;

  void addWindow(Duration bellTime) {
    final start = bellTime - revealBeforeBell;
    windows.add(
      _BellVisibilityWindow(
        start: start.isNegative ? Duration.zero : start,
        end: bellTime + revealAfterBell,
      ),
    );
  }

  if (timer.startingBell != null) {
    addWindow(preparationDuration);
  }

  final timerDuration = timer.duration;
  if (timerDuration != null && timer.endingBell != null) {
    addWindow(preparationDuration + timerDuration);
  }

  for (final bell in timer.intermediateBells) {
    if (timerDuration == null) {
      addWindow(preparationDuration + bell.startTime);
      final repeatInterval = bell.repeatInterval;
      if (repeatInterval != null && repeatInterval.inSeconds > 0) {
        for (var repeatIndex = 1; repeatIndex <= 48; repeatIndex += 1) {
          addWindow(
            preparationDuration +
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
      addWindow(preparationDuration + bellTime);
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
                  child: Text(isSaving ? 'Finishing...' : 'Finish'),
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
                child: const Text('Discard session (delete log)'),
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
            key: const ValueKey('finish-with-bell-button'),
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
                  ? 'Log & Finish (play bell)'
                  : 'Log & Finish early (play bell)',
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            key: const ValueKey('finish-without-bell-button'),
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
              isInfiniteTimer
                  ? 'Log & Finish (no bell)'
                  : 'Log & Finish early (no bell)',
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          key: const ValueKey('discard-session-button'),
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
  final baseDuration = timer.isInfinite
      ? 'Infinite'
      : _formatDuration(timer.duration!);
  final duration = timer.preparationDuration > Duration.zero
      ? '$baseDuration + ${_formatDuration(timer.preparationDuration)} prep'
      : baseDuration;

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
