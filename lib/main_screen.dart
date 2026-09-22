part of 'main.dart';

const _externalTouchRemoteCommandDebounce = Duration(milliseconds: 500);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.openBackgroundSetupGuide, this.now});

  final Future<bool> Function()? openBackgroundSetupGuide;
  final DateTime Function()? now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _now() => widget.now?.call() ?? DateTime.now();

  static const MethodChannel _remoteKeysChannel = MethodChannel(
    'bruno_meditation_timer/remote_keys',
  );

  // Home owns all tab-level state that must survive pushing full-screen routes
  // such as meditation sessions and edit screens. Keeping pranayama state here
  // is deliberate: pranayama audio can continue while the user runs a timer.
  HomeTab _selectedTab = HomeTab.timers;
  bool _recentTimersCollapsed = false;
  bool _recentPranayamaCollapsed = false;
  bool _soundEnabled = true;
  bool _turnScreenOnNearAudio = true;
  bool _isEditingTimerPositions = false;
  bool _isEditingPranayamaPositions = false;
  int _recentTimerLimit = _defaultRecentTimerLimit;
  final _BellAudioEngine _bellAudioEngine = _BellAudioEngine.instance;
  final _PranayamaAudioEngine _pranayamaAudioEngine = _PranayamaAudioEngine();
  final Map<String, _PranayamaToneClip> _pranayamaToneCache =
      <String, _PranayamaToneClip>{};
  final List<_ScheduledPranayamaCycle> _scheduledPranayamaAudioCycles =
      <_ScheduledPranayamaCycle>[];
  Future<void>? _pranayamaAudioOperation;
  bool _pranayamaRemoteControlEnabled = false;
  final Map<PranayamaRemoteCommand, PranayamaRemoteInputBinding>
  _pranayamaRemoteCommandBindings =
      <PranayamaRemoteCommand, PranayamaRemoteInputBinding>{};
  PranayamaRemoteCommand? _capturingPranayamaRemoteCommand;
  final ValueNotifier<List<_PranayamaRemoteInputDebugEvent>>
  _pranayamaRemoteInputEvents =
      ValueNotifier<List<_PranayamaRemoteInputDebugEvent>>(
        const <_PranayamaRemoteInputDebugEvent>[],
      );
  int _pranayamaRemoteInputSerial = 0;
  String? _lastHandledAndroidRemoteEventSignature;
  Timer? _pendingExternalTouchRemoteCommandTimer;
  // Async audio startup can complete after the user pauses/stops/switches a
  // preset. These generations make those stale completions harmless.
  int _pranayamaStartGeneration = 0;
  int _pranayamaAudioGeneration = 0;
  final MeditationLogStore _logStore = const MeditationLogStore();
  final BackgroundTimerService _backgroundTimerService =
      const BackgroundTimerService();
  final Set<String> _expandedFolders = <String>{};
  final Set<String> _expandedPranayamaFolders = <String>{};
  final List<TimerBrowserEntry> _timerEntries = List.of(_defaultTimerEntries);
  final List<PranayamaBrowserEntry> _pranayamaEntries = List.of(
    _defaultPranayamaEntries,
  );
  final List<String> _recentTimerIds = <String>[];
  final List<String> _recentPranayamaPresetIds = <String>[];
  // Persisted browser entries are saved asynchronously; only the latest save
  // should win if the user edits/reorders quickly.
  int _timerEntriesSaveGeneration = 0;
  int _pranayamaEntriesSaveGeneration = 0;
  int _statsRefreshKey = 0;
  PranayamaPreset? _activePranayamaPreset;
  DateTime? _pranayamaStartedAt;
  Duration _pranayamaElapsedBeforePause = Duration.zero;
  bool _isPranayamaPaused = false;
  int _activePranayamaSegmentIndex = 0;
  _PendingPranayamaTransition? _pendingPranayamaTransition;
  Timer? _pendingPranayamaTransitionTimer;
  Timer? _pranayamaTicker;
  final ValueNotifier<PranayamaSessionSnapshot> _pranayamaSessionNotifier =
      ValueNotifier<PranayamaSessionSnapshot>(PranayamaSessionSnapshot.empty);
  MeditationTimerPreset? _activeMeditationTimer;
  Duration _activeMeditationElapsed = Duration.zero;
  bool _isMeditationSessionVisible = false;
  GlobalKey<_MeditationSessionScreenState>? _activeMeditationSessionKey;

  @override
  void initState() {
    super.initState();
    _remoteKeysChannel.setMethodCallHandler(_handleRemoteKeyMethodCall);
    HardwareKeyboard.instance.addHandler(_handlePranayamaRemoteKeyEvent);
    _loadHomeSettings();
  }

  @override
  void dispose() {
    _remoteKeysChannel.setMethodCallHandler(null);
    HardwareKeyboard.instance.removeHandler(_handlePranayamaRemoteKeyEvent);
    _pendingExternalTouchRemoteCommandTimer?.cancel();
    _pendingPranayamaTransitionTimer?.cancel();
    _pranayamaTicker?.cancel();
    _disposePranayamaAudioEngine();
    _pranayamaSessionNotifier.dispose();
    _pranayamaRemoteInputEvents.dispose();
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
      _recentPranayamaCollapsed =
          preferences.getBool(_recentPranayamaCollapsedKey) ?? false;
      _soundEnabled = preferences.getBool(_soundEnabledKey) ?? true;
      _turnScreenOnNearAudio =
          preferences.getBool(_turnScreenOnNearAudioKey) ?? true;
      _pranayamaRemoteControlEnabled =
          preferences.getBool(_pranayamaRemoteControlEnabledKey) ?? false;
      _pranayamaRemoteCommandBindings
        ..clear()
        ..addAll(
          _decodePranayamaRemoteCommandKeys(
            preferences.getString(_pranayamaRemoteCommandKeysKey),
          ),
        );
      _recentTimerLimit = _clampRecentTimerLimit(
        preferences.getInt(_recentTimerLimitKey) ?? _defaultRecentTimerLimit,
      );
      _recentTimerIds
        ..clear()
        ..addAll(
          _decodeRecentTimerIds(preferences.getString(_recentTimerIdsKey)),
        );
      _recentPranayamaPresetIds
        ..clear()
        ..addAll(
          _decodeRecentTimerIds(
            preferences.getString(_recentPranayamaPresetIdsKey),
          ),
        );
      _timerEntries
        ..clear()
        ..addAll(
          _decodeTimerEntries(preferences.getString(_timerEntriesKey)) ??
              _defaultTimerEntries,
        );
      _pranayamaEntries
        ..clear()
        ..addAll(
          _decodePranayamaEntries(
                preferences.getString(_pranayamaEntriesKey),
              ) ??
              _defaultPranayamaEntries,
        );
    });
    unawaited(_setAndroidRemoteKeyListening(_pranayamaRemoteControlEnabled));
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

  Future<void> _toggleRecentPranayamaPresets() async {
    final nextValue = !_recentPranayamaCollapsed;
    setState(() {
      _recentPranayamaCollapsed = nextValue;
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_recentPranayamaCollapsedKey, nextValue);
  }

  Future<void> _setSoundEnabled({required bool enabled}) async {
    final preservePranayamaElapsed =
        _activePranayamaPreset != null && !_isPranayamaPaused;
    final pranayamaElapsed = preservePranayamaElapsed
        ? _currentPranayamaElapsed
        : Duration.zero;

    setState(() {
      _soundEnabled = enabled;
      if (!enabled && preservePranayamaElapsed) {
        _pranayamaElapsedBeforePause = pranayamaElapsed;
        _pranayamaStartedAt = _now();
      }
    });
    if (!enabled) {
      unawaited(_mutePranayamaAudio());
    } else {
      unawaited(_syncPranayamaAudio(forceRestart: true));
    }
    _notifyPranayamaSession();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_soundEnabledKey, enabled);
  }

  Future<void> _setTurnScreenOnNearAudio({required bool enabled}) async {
    setState(() {
      _turnScreenOnNearAudio = enabled;
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_turnScreenOnNearAudioKey, enabled);
  }

  Future<void> _setPranayamaRemoteControlEnabled({
    required bool enabled,
  }) async {
    if (_pranayamaRemoteControlEnabled == enabled) {
      return;
    }

    final preset = _activePranayamaPreset;
    _clearPendingPranayamaTransition();
    setState(() {
      if (preset != null) {
        final elapsed = _currentPranayamaElapsed;
        if (enabled) {
          final position = _pranayamaSegmentAtElapsed(preset, elapsed);
          _activePranayamaSegmentIndex = position.index;
          _pranayamaElapsedBeforePause = position.localElapsed;
        } else {
          final position = _pranayamaSegmentAtElapsed(
            preset,
            elapsed,
            forcedSegmentIndex: _activePranayamaSegmentIndex,
          );
          _pranayamaElapsedBeforePause =
              _pranayamaSegmentStartForIndex(preset, position.index) +
              position.localElapsed;
        }
        _pranayamaStartedAt = _isPranayamaPaused ? null : _now();
      }

      _pranayamaRemoteControlEnabled = enabled;
    });
    _notifyPranayamaSession();
    if (preset != null && !_isPranayamaPaused) {
      unawaited(_syncPranayamaAudio(forceRestart: true));
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_pranayamaRemoteControlEnabledKey, enabled);
    unawaited(_setAndroidRemoteKeyListening(enabled));
  }

  Future<void> _setAndroidRemoteKeyListening(bool enabled) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _remoteKeysChannel.invokeMethod<void>(
        'setRemoteKeyListeningEnabled',
        {'enabled': enabled},
      );
    } on MissingPluginException {
      // Non-Android builds and older installed builds simply do not expose the
      // native remote bridge.
    } on PlatformException catch (error) {
      debugPrint('Could not update Android remote key listening: $error');
    }
  }

  Future<void> _openRemoteAccessibilitySettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      _showMessage('Accessibility settings are only available on Android.');
      return;
    }

    try {
      await _remoteKeysChannel.invokeMethod<void>('openAccessibilitySettings');
    } on MissingPluginException {
      _showMessage('Could not open Android accessibility settings.');
    } on PlatformException catch (error) {
      debugPrint('Could not open Android accessibility settings: $error');
      _showMessage('Could not open Android accessibility settings.');
    }
  }

  Future<void> _handleRemoteKeyMethodCall(MethodCall call) async {
    if (call.method != 'androidKeyEvent' &&
        call.method != 'androidMotionEvent') {
      return;
    }

    final event = _PranayamaRemoteInputDebugEvent.fromAndroidPayload(
      serial: ++_pranayamaRemoteInputSerial,
      method: call.method,
      payload: call.arguments,
    );
    if (event == null) {
      return;
    }

    _recordPranayamaRemoteInputEvent(event);
    if (!_pranayamaRemoteControlEnabled ||
        _capturingPranayamaRemoteCommand != null ||
        !event.isCommandTrigger ||
        event.repeatCount > 0 ||
        _isTextInputFocused()) {
      return;
    }

    final binding = event.binding;
    if (binding == null) {
      return;
    }

    final command = _pranayamaRemoteCommandForBinding(binding);
    if (command == null) {
      return;
    }

    final signature = event.androidCommandSignature;
    if (signature != null &&
        signature == _lastHandledAndroidRemoteEventSignature) {
      return;
    }
    _lastHandledAndroidRemoteEventSignature = signature;
    _runOrSchedulePranayamaRemoteCommand(command, event: event);
  }

  void _recordPranayamaRemoteInputEvent(_PranayamaRemoteInputDebugEvent event) {
    _pranayamaRemoteInputEvents.value = [
      event,
      ..._pranayamaRemoteInputEvents.value.take(23),
    ];
  }

  Future<void> _capturePranayamaRemoteCommandKey(
    PranayamaRemoteCommand command,
  ) async {
    setState(() {
      _capturingPranayamaRemoteCommand = command;
    });

    try {
      unawaited(_setAndroidRemoteKeyListening(true));
      if (!mounted) {
        return;
      }

      final initialLatestSerial = _pranayamaRemoteInputEvents.value.isEmpty
          ? 0
          : _pranayamaRemoteInputEvents.value.first.serial;
      final binding = await showDialog<PranayamaRemoteInputBinding>(
        context: context,
        builder: (_) => _PranayamaRemoteKeyCaptureDialog(
          command: command,
          remoteInputEvents: _pranayamaRemoteInputEvents,
          initialLatestSerial: initialLatestSerial,
        ),
      );
      if (!mounted || binding == null) {
        return;
      }

      setState(() {
        _pranayamaRemoteCommandBindings.removeWhere(
          (_, existingBinding) => existingBinding == binding,
        );
        _pranayamaRemoteCommandBindings[command] = binding;
      });
      await _savePranayamaRemoteCommandKeys();
    } finally {
      unawaited(_setAndroidRemoteKeyListening(_pranayamaRemoteControlEnabled));
      if (mounted) {
        setState(() {
          _capturingPranayamaRemoteCommand = null;
        });
      }
    }
  }

  Future<void> _clearPranayamaRemoteCommandKey(
    PranayamaRemoteCommand command,
  ) async {
    setState(() {
      _pranayamaRemoteCommandBindings.remove(command);
    });
    await _savePranayamaRemoteCommandKeys();
  }

  Future<void> _savePranayamaRemoteCommandKeys() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _pranayamaRemoteCommandKeysKey,
      jsonEncode(
        _encodePranayamaRemoteCommandKeys(_pranayamaRemoteCommandBindings),
      ),
    );
  }

  bool _handlePranayamaRemoteKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent ||
        event is KeyUpEvent ||
        event is KeyRepeatEvent) {
      _recordPranayamaRemoteInputEvent(
        _PranayamaRemoteInputDebugEvent.fromFlutterKeyEvent(
          serial: ++_pranayamaRemoteInputSerial,
          event: event,
        ),
      );
    }

    if (!_pranayamaRemoteControlEnabled ||
        _capturingPranayamaRemoteCommand != null ||
        event is! KeyDownEvent ||
        _isTextInputFocused()) {
      return false;
    }

    final command = _pranayamaRemoteCommandForBinding(
      PranayamaRemoteInputBinding.flutterLogicalKey(event.logicalKey.keyId),
    );
    if (command == null) {
      return false;
    }

    _pendingExternalTouchRemoteCommandTimer?.cancel();
    _pendingExternalTouchRemoteCommandTimer = null;
    _runPranayamaRemoteCommand(command);
    return true;
  }

  bool _isTextInputFocused() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }

    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  PranayamaRemoteCommand? _pranayamaRemoteCommandForBinding(
    PranayamaRemoteInputBinding binding,
  ) {
    for (final entry in _pranayamaRemoteCommandBindings.entries) {
      if (entry.value == binding) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> _openPranayamaRemoteDiagnostics() async {
    unawaited(_setAndroidRemoteKeyListening(true));
    try {
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (_) => _PranayamaRemoteDiagnosticsDialog(
          remoteInputEvents: _pranayamaRemoteInputEvents,
          onClear: () {
            _pranayamaRemoteInputEvents.value =
                const <_PranayamaRemoteInputDebugEvent>[];
          },
        ),
      );
    } finally {
      unawaited(_setAndroidRemoteKeyListening(_pranayamaRemoteControlEnabled));
    }
  }

  void _runOrSchedulePranayamaRemoteCommand(
    PranayamaRemoteCommand command, {
    required _PranayamaRemoteInputDebugEvent event,
  }) {
    if (event.origin != 'externalTouch') {
      _pendingExternalTouchRemoteCommandTimer?.cancel();
      _pendingExternalTouchRemoteCommandTimer = null;
      _runPranayamaRemoteCommand(command);
      return;
    }

    // The WX02-style ring emits its single-click gesture before its double-click
    // gesture. Treat external-touch input as a short cluster and execute only
    // the final gesture so double-click bindings do not also fire the
    // single-click command.
    _pendingExternalTouchRemoteCommandTimer?.cancel();
    _pendingExternalTouchRemoteCommandTimer = Timer(
      _externalTouchRemoteCommandDebounce,
      () {
        _pendingExternalTouchRemoteCommandTimer = null;
        if (mounted && _pranayamaRemoteControlEnabled) {
          _runPranayamaRemoteCommand(command);
        }
      },
    );
  }

  void _runPranayamaRemoteCommand(PranayamaRemoteCommand command) {
    switch (command) {
      case PranayamaRemoteCommand.toggleStartStop:
        _togglePranayamaRemoteStartStop();
      case PranayamaRemoteCommand.increaseBreathLengths:
        _scaleActivePranayamaBreathLengths(1.1);
      case PranayamaRemoteCommand.decreaseBreathLengths:
        _scaleActivePranayamaBreathLengths(1 / 1.1);
      case PranayamaRemoteCommand.nextSegment:
        _moveActivePranayamaSegment(1);
      case PranayamaRemoteCommand.previousSegment:
        _moveActivePranayamaSegment(-1);
    }
  }

  void _togglePranayamaRemoteStartStop() {
    if (_activePranayamaPreset != null) {
      _stopPranayamaSession();
      return;
    }

    final preset =
        (_recentPranayamaPresets.isEmpty ? null : _recentPranayamaPresets[0]) ??
        _firstPranayamaPresetInEntries(_pranayamaEntries);
    if (preset != null) {
      _startPranayamaPreset(preset);
    }
  }

  void _scaleActivePranayamaBreathLengths(double factor) {
    final preset =
        _pendingPranayamaTransition?.preset ?? _activePranayamaPreset;
    if (preset == null) {
      return;
    }

    final updatedPreset = preset.copyWith(
      segments: [
        for (final segment in preset.segments)
          segment.copyWith(
            inBreath: _scaledPranayamaPhaseDuration(segment.inBreath, factor),
            firstHold: _scaledPranayamaPhaseDuration(segment.firstHold, factor),
            outBreath: _scaledPranayamaPhaseDuration(segment.outBreath, factor),
            secondHold: _scaledPranayamaPhaseDuration(
              segment.secondHold,
              factor,
            ),
          ),
      ],
    );

    _queueOrApplyPranayamaTransition(
      preset: updatedPreset,
      segmentIndex:
          _pendingPranayamaTransition?.segmentIndex ??
          _activePranayamaSegmentIndex,
    );
  }

  Duration _scaledPranayamaPhaseDuration(Duration duration, double factor) {
    if (duration == Duration.zero) {
      return Duration.zero;
    }

    final scaledMilliseconds = (duration.inMilliseconds * factor).round();
    return Duration(milliseconds: math.max(100, scaledMilliseconds));
  }

  void _moveActivePranayamaSegment(int delta) {
    final preset =
        _pendingPranayamaTransition?.preset ?? _activePranayamaPreset;
    if (preset == null || preset.segments.isEmpty) {
      return;
    }

    final currentIndex =
        (_pendingPranayamaTransition?.segmentIndex ??
                _activePranayamaSegmentIndex)
            .clamp(0, preset.segments.length - 1)
            .toInt();
    final nextIndex = (currentIndex + delta)
        .clamp(0, preset.segments.length - 1)
        .toInt();
    if (nextIndex == currentIndex) {
      return;
    }

    _queueOrApplyPranayamaTransition(preset: preset, segmentIndex: nextIndex);
  }

  Future<void> _setRecentTimerLimit(int limit) async {
    final nextLimit = _clampRecentTimerLimit(limit);
    setState(() {
      _recentTimerLimit = nextLimit;
      if (_recentTimerIds.length > nextLimit) {
        _recentTimerIds.removeRange(nextLimit, _recentTimerIds.length);
      }
      if (_recentPranayamaPresetIds.length > nextLimit) {
        _recentPranayamaPresetIds.removeRange(
          nextLimit,
          _recentPranayamaPresetIds.length,
        );
      }
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_recentTimerLimitKey, nextLimit);
    await preferences.setString(
      _recentTimerIdsKey,
      jsonEncode(_recentTimerIds),
    );
    await preferences.setString(
      _recentPranayamaPresetIdsKey,
      jsonEncode(_recentPranayamaPresetIds),
    );
  }

  Future<void> _testSound() async {
    if (!_soundEnabled) {
      return;
    }

    await _bellAudioEngine.play(
      _woodKnock,
      group: 'settings-test-sound',
      replaceGroup: true,
    );
  }

  Future<void> _importLogsCsv() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(label: 'CSV', extensions: <String>['csv']),
        ],
      );
      if (file == null) {
        return;
      }

      final importResult = await _logStore.importCsv(await file.readAsString());
      if (!mounted) {
        return;
      }

      _showMessage(
        'Imported ${importResult.importedCount} logs. Skipped ${importResult.skippedCount}.',
      );
    } on Object {
      if (mounted) {
        _showMessage('Could not import logs from that CSV file.');
      }
    }
  }

  Future<void> _exportLogsCsv() async {
    try {
      final csvText = await _logStore.exportCsv();
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Export meditation logs',
        fileName: 'breath-and-insight-logs.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csvText)),
      );

      if (!mounted) {
        return;
      }

      if (kIsWeb || savedPath != null) {
        _showMessage('Exported meditation logs.');
      }
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Could not export meditation logs: $error');
      }
    }
  }

  Future<void> _reinstallDefaultPresets() async {
    try {
      final bundle = await _loadDefaultPresetBundle();
      final conflictChoice = await _resolvePresetImportConflicts(bundle);
      if (conflictChoice == null) {
        return;
      }

      final result = await _mergePresetBundle(
        bundle,
        overrideExisting: conflictChoice == _PresetConflictChoice.override,
      );
      if (!mounted) {
        return;
      }

      _showMessage(_presetImportMessage('Reinstalled default presets', result));
    } on Object {
      if (mounted) {
        _showMessage('Could not reinstall default presets.');
      }
    }
  }

  Future<void> _importPresetsJson() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(label: 'JSON', extensions: <String>['json']),
        ],
      );
      if (file == null) {
        return;
      }

      final bundle = _decodePresetBundle(await file.readAsString());
      if (bundle == null) {
        _showMessage('Could not understand that presets file.');
        return;
      }

      final conflictChoice = await _resolvePresetImportConflicts(bundle);
      if (conflictChoice == null) {
        return;
      }

      final importResult = await _mergePresetBundle(
        bundle,
        overrideExisting: conflictChoice == _PresetConflictChoice.override,
      );
      if (!mounted) {
        return;
      }

      _showMessage(_presetImportMessage('Imported presets', importResult));
    } on Object {
      if (mounted) {
        _showMessage('Could not import presets from that JSON file.');
      }
    }
  }

  Future<void> _exportPresetsJson() async {
    try {
      final jsonText = _encodePresetBundle(
        _PresetBundle(
          timerEntries: _timerEntries,
          pranayamaEntries: _pranayamaEntries,
        ),
      );
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Export presets',
        fileName: 'breath-and-insight-presets.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(jsonText)),
      );

      if (!mounted) {
        return;
      }

      if (kIsWeb || savedPath != null) {
        _showMessage('Exported presets.');
      }
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Could not export presets: $error');
      }
    }
  }

  Future<_PresetBundle> _loadDefaultPresetBundle() async {
    final jsonText = await rootBundle.loadString('assets/default-presets.json');
    final bundle = _decodePresetBundle(jsonText);
    if (bundle == null) {
      throw const FormatException('Invalid default presets JSON');
    }

    return bundle;
  }

  Future<_PresetConflictChoice?> _resolvePresetImportConflicts(
    _PresetBundle bundle,
  ) async {
    final conflicts = _presetBundleConflicts(
      timerEntries: _timerEntries,
      pranayamaEntries: _pranayamaEntries,
      importedBundle: bundle,
    );
    if (conflicts == 0) {
      return _PresetConflictChoice.ignore;
    }

    return showDialog<_PresetConflictChoice>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _homeSurfaceColor,
          title: const Text('Preset titles already exist'),
          content: Text(
            '$conflicts imported presets have titles that already exist. Override all matching presets, or ignore all matching presets?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('ignore-preset-conflicts-button'),
              onPressed: () =>
                  Navigator.of(context).pop(_PresetConflictChoice.ignore),
              child: const Text('Ignore'),
            ),
            TextButton(
              key: const ValueKey('override-preset-conflicts-button'),
              onPressed: () =>
                  Navigator.of(context).pop(_PresetConflictChoice.override),
              child: const Text('Override'),
            ),
          ],
        );
      },
    );
  }

  Future<_PresetImportResult> _mergePresetBundle(
    _PresetBundle bundle, {
    required bool overrideExisting,
  }) async {
    // Import/reinstall is title-based by design. IDs are stable for recents,
    // but users understand duplicate preset titles better than duplicate IDs.
    final timerMerge = _mergeTimerEntryPresets(
      _timerEntries,
      bundle.timerEntries,
      overrideExisting: overrideExisting,
    );
    final pranayamaMerge = _mergePranayamaEntryPresets(
      _pranayamaEntries,
      bundle.pranayamaEntries,
      overrideExisting: overrideExisting,
    );

    setState(() {
      _timerEntries
        ..clear()
        ..addAll(timerMerge.entries);
      _pranayamaEntries
        ..clear()
        ..addAll(pranayamaMerge.entries);
      final activePreset = _activePranayamaPreset;
      if (activePreset != null) {
        // If the active preset was overwritten, keep the running session tied to
        // the new definition and restart its generated cycle audio below.
        _activePranayamaPreset =
            _pranayamaPresetByIdInEntries(activePreset.id, _pranayamaEntries) ??
            activePreset;
      }
    });
    _notifyPranayamaSession();

    await _saveTimerEntries();
    await _savePranayamaEntries();
    if (_activePranayamaPreset != null && !_isPranayamaPaused) {
      unawaited(_syncPranayamaAudio(forceRestart: true));
    }

    return _PresetImportResult(
      addedCount: timerMerge.addedCount + pranayamaMerge.addedCount,
      overwrittenCount:
          timerMerge.overwrittenCount + pranayamaMerge.overwrittenCount,
      skippedCount: timerMerge.skippedCount + pranayamaMerge.skippedCount,
    );
  }

  Future<void> _prepareBackgroundTimerSupport() async {
    final prepared = await _backgroundTimerService.prepare();
    if (!mounted) {
      return;
    }

    _showMessage(
      prepared
          ? 'Background timer support is ready.'
          : 'Background timer support is only available on Android, or permissions were not granted.',
    );
  }

  Future<void> _openBackgroundSetupHelp() async {
    final opened =
        await (widget.openBackgroundSetupGuide ?? _openBackgroundSetupGuide)();
    if (!mounted || opened) {
      return;
    }

    _showMessage('Could not open the background setup guide.');
  }

  Future<void> _confirmPurgeLogs() async {
    final shouldPurge = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Purge all logs?'),
          content: const Text(
            'This will permanently delete every meditation log entry. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('confirm-purge-logs-button'),
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF7A7A),
              ),
              child: const Text('Purge all logs'),
            ),
          ],
        );
      },
    );

    if (shouldPurge != true) {
      return;
    }

    await _logStore.purgeAll();
    if (!mounted) {
      return;
    }

    setState(() {
      _statsRefreshKey += 1;
    });
    _showMessage('All meditation logs have been purged.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  void _togglePranayamaFolder(String folderName) {
    setState(() {
      if (_expandedPranayamaFolders.contains(folderName)) {
        _expandedPranayamaFolders.remove(folderName);
      } else {
        _expandedPranayamaFolders.add(folderName);
      }
    });
  }

  void _toggleTimerPositionEditing() {
    setState(() {
      _isEditingTimerPositions = !_isEditingTimerPositions;
    });
  }

  void _togglePranayamaPositionEditing() {
    setState(() {
      _isEditingPranayamaPositions = !_isEditingPranayamaPositions;
    });
  }

  Future<void> _addFolder() async {
    final folderName = await _promptForFolderTitle(
      title: 'Add folder',
      initialValue: 'New folder',
      saveButtonLabel: 'Add',
    );
    if (folderName == null) {
      return;
    }

    setState(() {
      _timerEntries.add(
        TimerFolderEntry(TimerFolder(name: folderName, timers: const [])),
      );
    });

    unawaited(_saveTimerEntries());
  }

  Future<void> _editFolderTitle(TimerFolder folder) async {
    final newName = await _promptForFolderTitle(
      title: 'Edit folder title',
      initialValue: folder.name,
      saveButtonLabel: 'Save',
      exceptFolderName: folder.name,
    );

    if (newName == null || newName == folder.name) {
      return;
    }

    setState(() {
      for (var index = 0; index < _timerEntries.length; index += 1) {
        final entry = _timerEntries[index];
        if (entry is TimerFolderEntry && entry.folder.name == folder.name) {
          _timerEntries[index] = TimerFolderEntry(
            entry.folder.withName(newName),
          );
          break;
        }
      }

      if (_expandedFolders.remove(folder.name)) {
        _expandedFolders.add(newName);
      }
    });

    unawaited(_saveTimerEntries());
  }

  Future<String?> _promptForFolderTitle({
    required String title,
    required String initialValue,
    required String saveButtonLabel,
    String? exceptFolderName,
  }) async {
    var editedName = initialValue;
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        String? errorText;

        void submit(StateSetter setDialogState) {
          final trimmedName = editedName.trim();
          if (trimmedName.isEmpty) {
            setDialogState(() {
              errorText = 'Enter a folder title';
            });
            return;
          }

          if (_folderNameExists(
            trimmedName,
            exceptFolderName: exceptFolderName,
          )) {
            setDialogState(() {
              errorText = 'A folder with this title already exists';
            });
            return;
          }

          Navigator.of(context).pop(trimmedName);
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _homeSurfaceColor,
              title: Text(title),
              content: TextFormField(
                key: const ValueKey('folder-title-field'),
                initialValue: initialValue,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Title',
                  errorText: errorText,
                ),
                textInputAction: TextInputAction.done,
                onChanged: (value) {
                  editedName = value;
                  if (errorText != null) {
                    setDialogState(() {
                      errorText = null;
                    });
                  }
                },
                onFieldSubmitted: (_) => submit(setDialogState),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  key: const ValueKey('save-folder-title-button'),
                  onPressed: () => submit(setDialogState),
                  child: Text(saveButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );

    return newName;
  }

  void _deleteFolder(TimerFolder folder) {
    if (folder.timers.isNotEmpty) {
      return;
    }

    setState(() {
      for (var index = 0; index < _timerEntries.length; index += 1) {
        final entry = _timerEntries[index];
        if (entry is TimerFolderEntry && entry.folder.name == folder.name) {
          _timerEntries.removeAt(index);
          break;
        }
      }

      _expandedFolders.remove(folder.name);
    });

    unawaited(_saveTimerEntries());
  }

  Future<void> _createTimer() async {
    final timer = await Navigator.of(context).push<MeditationTimerPreset>(
      MaterialPageRoute(
        builder: (_) => TimerEditScreen(existingTimerNames: _timerNames()),
      ),
    );

    if (timer == null) {
      return;
    }

    setState(() {
      _timerEntries.add(TimerPresetEntry(timer));
    });

    unawaited(_saveTimerEntries());
  }

  Future<void> _editTimer(MeditationTimerPreset timer) async {
    final updatedTimer = await Navigator.of(context)
        .push<MeditationTimerPreset>(
          MaterialPageRoute(
            builder: (_) => TimerEditScreen(
              timer: timer,
              existingTimerNames: _timerNames(exceptTimerName: timer.name),
            ),
          ),
        );

    if (updatedTimer == null) {
      return;
    }

    final updatedEntries = _replaceTimer(
      _timerEntries,
      timer.name,
      updatedTimer,
    );
    setState(() {
      _timerEntries
        ..clear()
        ..addAll(updatedEntries);
    });

    unawaited(_saveTimerEntries());
    unawaited(_saveRecentTimerIds());
  }

  Future<void> _confirmDeleteTimer(MeditationTimerPreset timer) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _homeSurfaceColor,
          title: const Text('Delete timer?'),
          content: Text('Delete "${timer.name}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('confirm-delete-timer-button'),
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE06A6A),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    final updatedEntries = _removeTimer(_timerEntries, timer.name);
    setState(() {
      _timerEntries
        ..clear()
        ..addAll(updatedEntries);
      _recentTimerIds.remove(timer.id);
    });

    unawaited(_saveTimerEntries());
    unawaited(_saveRecentTimerIds());
  }

  Set<String> _timerNames({String? exceptTimerName}) {
    final names = <String>{};
    for (final entry in _timerEntries) {
      switch (entry) {
        case TimerPresetEntry(:final timer):
          if (timer.name != exceptTimerName) {
            names.add(timer.name);
          }
        case TimerFolderEntry(:final folder):
          for (final timer in folder.timers) {
            if (timer.name != exceptTimerName) {
              names.add(timer.name);
            }
          }
      }
    }

    return names;
  }

  bool _folderNameExists(String folderName, {String? exceptFolderName}) {
    return _timerEntries.any(
      (entry) =>
          entry is TimerFolderEntry &&
          entry.folder.name == folderName &&
          entry.folder.name != exceptFolderName,
    );
  }

  void _reorderTimerEntry(int oldIndex, int newIndex) {
    setState(() {
      final rows = _editableRowsFor(_timerEntries);
      final movingRow = rows[oldIndex];
      final entriesWithoutMoving = _removeEditableRow(_timerEntries, movingRow);
      final rowsWithoutMoving = _editableRowsFor(entriesWithoutMoving);
      final targetIndex = newIndex.clamp(0, rowsWithoutMoving.length);

      _timerEntries
        ..clear()
        ..addAll(switch (movingRow) {
          _EditableTimerRow(:final timer) => _insertTimerRow(
            entriesWithoutMoving,
            rowsWithoutMoving,
            targetIndex,
            timer,
          ),
          _EditableFolderRow(:final folder) => _insertFolderRow(
            entriesWithoutMoving,
            rowsWithoutMoving,
            targetIndex,
            folder,
          ),
        });
    });

    unawaited(_saveTimerEntries());
  }

  Future<void> _saveTimerEntries() async {
    final saveGeneration = ++_timerEntriesSaveGeneration;
    final encodedEntries = jsonEncode(_encodeTimerEntries(_timerEntries));
    final preferences = await SharedPreferences.getInstance();

    if (saveGeneration != _timerEntriesSaveGeneration) {
      return;
    }

    await preferences.setString(_timerEntriesKey, encodedEntries);
  }

  void _startTimer(MeditationTimerPreset timer) {
    // A new session is allowed to interrupt an ending bell that is still
    // ringing from the previous summary screen.
    unawaited(_bellAudioEngine.stopGroup('detached-ending-bell'));
    _recordRecentTimer(timer);
    setState(() {
      _activeMeditationTimer = timer;
      _activeMeditationElapsed = Duration.zero;
      _isMeditationSessionVisible = true;
      _activeMeditationSessionKey = GlobalKey<_MeditationSessionScreenState>();
    });
  }

  void _showActiveMeditationSession() {
    if (_activeMeditationTimer == null) {
      return;
    }

    setState(() {
      _isMeditationSessionVisible = true;
    });
  }

  void _minimizeActiveMeditationSession() {
    if (_activeMeditationTimer == null) {
      return;
    }

    setState(() {
      _selectedTab = HomeTab.timers;
      _isMeditationSessionVisible = false;
    });
  }

  void _clearActiveMeditationSession() {
    if (!mounted) {
      return;
    }

    setState(() {
      _activeMeditationTimer = null;
      _activeMeditationElapsed = Duration.zero;
      _isMeditationSessionVisible = false;
      _activeMeditationSessionKey = null;
      _selectedTab = HomeTab.timers;
    });
  }

  void _discardActiveMeditationSession() {
    final sessionState = _activeMeditationSessionKey?.currentState;
    if (sessionState != null) {
      sessionState._discardFromHost();
      return;
    }

    _clearActiveMeditationSession();
  }

  void _updateActiveMeditationElapsed(Duration elapsed) {
    if (_activeMeditationTimer == null ||
        _activeMeditationElapsed.inSeconds == elapsed.inSeconds) {
      return;
    }

    setState(() {
      _activeMeditationElapsed = elapsed;
    });
  }

  Future<void> _playDetachedEndingBell(BellSound bell) async {
    await _bellAudioEngine.play(
      bell,
      group: 'detached-ending-bell',
      replaceGroup: true,
    );
  }

  void _recordRecentTimer(MeditationTimerPreset timer) {
    setState(() {
      _recentTimerIds.remove(timer.id);
      if (_recentTimerLimit > 0) {
        _recentTimerIds.insert(0, timer.id);
      }
      if (_recentTimerIds.length > _recentTimerLimit) {
        _recentTimerIds.removeRange(_recentTimerLimit, _recentTimerIds.length);
      }
    });

    unawaited(_saveRecentTimerIds());
  }

  Future<void> _saveRecentTimerIds() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _recentTimerIdsKey,
      jsonEncode(_recentTimerIds),
    );
  }

  List<MeditationTimerPreset> get _recentTimers {
    return [
      for (final timerId in _recentTimerIds)
        ?_timerByIdInEntries(timerId, _timerEntries),
    ];
  }

  Future<void> _addPranayamaFolder() async {
    final folderName = await _promptForPranayamaFolderTitle(
      title: 'Add folder',
      initialValue: 'New folder',
      saveButtonLabel: 'Add',
    );
    if (folderName == null) {
      return;
    }

    setState(() {
      _pranayamaEntries.add(
        PranayamaFolderEntry(
          PranayamaFolder(name: folderName, presets: const []),
        ),
      );
    });

    unawaited(_savePranayamaEntries());
  }

  Future<void> _editPranayamaFolderTitle(PranayamaFolder folder) async {
    final newName = await _promptForPranayamaFolderTitle(
      title: 'Edit folder title',
      initialValue: folder.name,
      saveButtonLabel: 'Save',
      exceptFolderName: folder.name,
    );

    if (newName == null || newName == folder.name) {
      return;
    }

    setState(() {
      for (var index = 0; index < _pranayamaEntries.length; index += 1) {
        final entry = _pranayamaEntries[index];
        if (entry is PranayamaFolderEntry && entry.folder.name == folder.name) {
          _pranayamaEntries[index] = PranayamaFolderEntry(
            entry.folder.withName(newName),
          );
          break;
        }
      }

      if (_expandedPranayamaFolders.remove(folder.name)) {
        _expandedPranayamaFolders.add(newName);
      }
    });

    unawaited(_savePranayamaEntries());
  }

  Future<String?> _promptForPranayamaFolderTitle({
    required String title,
    required String initialValue,
    required String saveButtonLabel,
    String? exceptFolderName,
  }) async {
    var editedName = initialValue;
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        String? errorText;

        void submit(StateSetter setDialogState) {
          final trimmedName = editedName.trim();
          if (trimmedName.isEmpty) {
            setDialogState(() {
              errorText = 'Enter a folder title';
            });
            return;
          }

          if (_pranayamaFolderNameExists(
            trimmedName,
            exceptFolderName: exceptFolderName,
          )) {
            setDialogState(() {
              errorText = 'A folder with this title already exists';
            });
            return;
          }

          Navigator.of(context).pop(trimmedName);
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _homeSurfaceColor,
              title: Text(title),
              content: TextFormField(
                key: const ValueKey('pranayama-folder-title-field'),
                initialValue: initialValue,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Title',
                  errorText: errorText,
                ),
                textInputAction: TextInputAction.done,
                onChanged: (value) {
                  editedName = value;
                  if (errorText != null) {
                    setDialogState(() {
                      errorText = null;
                    });
                  }
                },
                onFieldSubmitted: (_) => submit(setDialogState),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  key: const ValueKey('save-pranayama-folder-title-button'),
                  onPressed: () => submit(setDialogState),
                  child: Text(saveButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );

    return newName;
  }

  bool _pranayamaFolderNameExists(
    String folderName, {
    String? exceptFolderName,
  }) {
    return _pranayamaEntries.any(
      (entry) =>
          entry is PranayamaFolderEntry &&
          entry.folder.name == folderName &&
          entry.folder.name != exceptFolderName,
    );
  }

  void _deletePranayamaFolder(PranayamaFolder folder) {
    if (folder.presets.isNotEmpty) {
      return;
    }

    setState(() {
      for (var index = 0; index < _pranayamaEntries.length; index += 1) {
        final entry = _pranayamaEntries[index];
        if (entry is PranayamaFolderEntry && entry.folder.name == folder.name) {
          _pranayamaEntries.removeAt(index);
          break;
        }
      }

      _expandedPranayamaFolders.remove(folder.name);
    });

    unawaited(_savePranayamaEntries());
  }

  Future<void> _createPranayamaPreset() async {
    final preset = await Navigator.of(context).push<PranayamaPreset>(
      MaterialPageRoute(
        builder: (_) =>
            PranayamaEditScreen(existingPresetNames: _pranayamaPresetNames()),
      ),
    );

    if (preset == null) {
      return;
    }

    setState(() {
      _pranayamaEntries.add(PranayamaPresetEntry(preset));
    });

    unawaited(_savePranayamaEntries());
  }

  Future<void> _editPranayamaPreset(PranayamaPreset preset) async {
    final updatedPreset = await Navigator.of(context).push<PranayamaPreset>(
      MaterialPageRoute(
        builder: (_) => PranayamaEditScreen(
          preset: preset,
          existingPresetNames: _pranayamaPresetNames(
            exceptPresetName: preset.name,
          ),
        ),
      ),
    );

    if (updatedPreset == null) {
      return;
    }

    final updatedEntries = _replacePranayamaPreset(
      _pranayamaEntries,
      preset.name,
      updatedPreset,
    );
    setState(() {
      _pranayamaEntries
        ..clear()
        ..addAll(updatedEntries);
      if (_activePranayamaPreset?.id == updatedPreset.id) {
        _activePranayamaPreset = updatedPreset;
      }
    });
    _notifyPranayamaSession();

    unawaited(_savePranayamaEntries());
    unawaited(_saveRecentPranayamaPresetIds());
  }

  Future<void> _confirmDeletePranayamaPreset(PranayamaPreset preset) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _homeSurfaceColor,
          title: const Text('Delete preset?'),
          content: Text('Delete "${preset.name}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('confirm-delete-pranayama-preset-button'),
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE06A6A),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    final updatedEntries = _removePranayamaPreset(
      _pranayamaEntries,
      preset.name,
    );
    setState(() {
      _pranayamaEntries
        ..clear()
        ..addAll(updatedEntries);
      _recentPranayamaPresetIds.remove(preset.id);
      if (_activePranayamaPreset?.id == preset.id) {
        _stopPranayamaSession(updateState: false);
      }
    });
    _notifyPranayamaSession();

    unawaited(_savePranayamaEntries());
    unawaited(_saveRecentPranayamaPresetIds());
  }

  Set<String> _pranayamaPresetNames({String? exceptPresetName}) {
    final names = <String>{};
    for (final entry in _pranayamaEntries) {
      switch (entry) {
        case PranayamaPresetEntry(:final preset):
          if (preset.name != exceptPresetName) {
            names.add(preset.name);
          }
        case PranayamaFolderEntry(:final folder):
          for (final preset in folder.presets) {
            if (preset.name != exceptPresetName) {
              names.add(preset.name);
            }
          }
      }
    }

    return names;
  }

  void _reorderPranayamaEntry(int oldIndex, int newIndex) {
    setState(() {
      final rows = _editablePranayamaRowsFor(_pranayamaEntries);
      final movingRow = rows[oldIndex];
      final entriesWithoutMoving = _removeEditablePranayamaRow(
        _pranayamaEntries,
        movingRow,
      );
      final rowsWithoutMoving = _editablePranayamaRowsFor(entriesWithoutMoving);
      final targetIndex = newIndex.clamp(0, rowsWithoutMoving.length);

      _pranayamaEntries
        ..clear()
        ..addAll(switch (movingRow) {
          _EditablePranayamaPresetRow(:final preset) =>
            _insertPranayamaPresetRow(
              entriesWithoutMoving,
              rowsWithoutMoving,
              targetIndex,
              preset,
            ),
          _EditablePranayamaFolderRow(:final folder) =>
            _insertPranayamaFolderRow(
              entriesWithoutMoving,
              rowsWithoutMoving,
              targetIndex,
              folder,
            ),
        });
    });

    unawaited(_savePranayamaEntries());
  }

  Future<void> _savePranayamaEntries() async {
    final saveGeneration = ++_pranayamaEntriesSaveGeneration;
    final encodedEntries = jsonEncode(
      _encodePranayamaEntries(_pranayamaEntries),
    );
    final preferences = await SharedPreferences.getInstance();

    if (saveGeneration != _pranayamaEntriesSaveGeneration) {
      return;
    }

    await preferences.setString(_pranayamaEntriesKey, encodedEntries);
  }

  void _startPranayamaPreset(PranayamaPreset preset) {
    final activePreset = _activePranayamaPreset;
    if (activePreset != null && !_isPranayamaPaused) {
      _queueOrApplyPranayamaTransition(
        preset: preset,
        segmentIndex: 0,
        recordRecentPreset: true,
      );
      return;
    }

    unawaited(_beginPranayamaPreset(preset));
  }

  void _queueOrApplyPranayamaTransition({
    required PranayamaPreset preset,
    required int segmentIndex,
    bool recordRecentPreset = false,
  }) {
    if (_activePranayamaPreset == null ||
        _isPranayamaPaused ||
        _pranayamaStartedAt == null) {
      _applyPranayamaTransitionNow(
        preset: preset,
        segmentIndex: segmentIndex,
        recordRecentPreset: recordRecentPreset,
      );
      return;
    }

    final currentElapsed = _currentPranayamaElapsed;
    final currentEngineTime = _pranayamaAudioEngine.currentEngineTime;
    final activeTimelineId = _pranayamaAudioTimelineId(
      preset: _activePranayamaPreset!,
      forcedSegmentIndex: _pranayamaRemoteControlEnabled
          ? _activePranayamaSegmentIndex
          : null,
    );
    final remainingUntilCycleEnd = _durationUntilCurrentPranayamaCycleEnds(
      _activePranayamaPreset!,
      elapsed: currentElapsed,
    );
    final applyAtElapsed = currentElapsed + remainingUntilCycleEnd;
    final applyAtEngineTime = _pranayamaAudioEngine.engineTimeForElapsed(
      applyAtElapsed,
    );
    _pendingPranayamaTransition = _PendingPranayamaTransition(
      preset: preset,
      segmentIndex: segmentIndex,
      applyAtElapsed: applyAtElapsed,
      applyAtEngineTime: applyAtEngineTime,
      recordRecentPreset: recordRecentPreset,
    );
    setState(() {});
    _notifyPranayamaSession();
    _schedulePendingPranayamaTransitionTimer(remainingUntilCycleEnd);
    _pranayamaAudioGeneration++;
    unawaited(
      _cancelScheduledPranayamaAudio(
        keepCurrentTimelineId: activeTimelineId,
        keepCurrentElapsed: currentElapsed,
        keepCurrentEngineTime: currentEngineTime,
        stopKeptAtEngineTime: applyAtEngineTime,
      ).then((_) => _syncPranayamaAudio(forceQueue: true)),
    );
  }

  void _schedulePendingPranayamaTransitionTimer(Duration remaining) {
    _pendingPranayamaTransitionTimer?.cancel();
    _pendingPranayamaTransitionTimer = Timer(remaining, () {
      if (!mounted || _pendingPranayamaTransition == null) {
        return;
      }
      _applyPendingPranayamaTransition();
    });
  }

  Duration _durationUntilCurrentPranayamaCycleEnds(
    PranayamaPreset preset, {
    Duration? elapsed,
  }) {
    final position = _pranayamaSegmentAtElapsed(
      preset,
      elapsed ?? _currentPranayamaElapsed,
      forcedSegmentIndex: _pranayamaRemoteControlEnabled
          ? _activePranayamaSegmentIndex
          : null,
    );
    final cycleDuration = _pranayamaCycleDurationForSegment(position.segment);
    final cycleMilliseconds = math.max(1, cycleDuration.inMilliseconds);
    final elapsedInCycle =
        position.localElapsed.inMilliseconds % cycleMilliseconds;
    final remainingMilliseconds = cycleMilliseconds - elapsedInCycle;
    return Duration(milliseconds: remainingMilliseconds);
  }

  void _applyPendingPranayamaTransition({bool restartAudio = true}) {
    final pendingTransition = _pendingPranayamaTransition;
    if (pendingTransition == null || _activePranayamaPreset == null) {
      return;
    }

    _pendingPranayamaTransition = null;
    _pendingPranayamaTransitionTimer?.cancel();
    _pendingPranayamaTransitionTimer = null;
    _applyPranayamaTransitionNow(
      preset: pendingTransition.preset,
      segmentIndex: pendingTransition.segmentIndex,
      recordRecentPreset: pendingTransition.recordRecentPreset,
      restartAudio: restartAudio,
      clockAnchorEngineTime:
          pendingTransition.applyAtEngineTime ??
          _pranayamaAudioEngine.engineTimeForElapsed(
            pendingTransition.applyAtElapsed,
          ),
    );
  }

  void _applyPranayamaTransitionNow({
    required PranayamaPreset preset,
    required int segmentIndex,
    bool recordRecentPreset = false,
    bool restartAudio = true,
    Duration? clockAnchorEngineTime,
  }) {
    _pranayamaStartGeneration++;
    if (recordRecentPreset) {
      _recordRecentPranayamaPreset(preset);
    }

    final nextSegmentIndex = preset.segments.isEmpty
        ? 0
        : segmentIndex.clamp(0, preset.segments.length - 1).toInt();
    setState(() {
      _activePranayamaPreset = preset;
      _activePranayamaSegmentIndex = nextSegmentIndex;
      _pranayamaElapsedBeforePause = Duration.zero;
      _pranayamaStartedAt = _isPranayamaPaused ? null : _now();
    });
    if (clockAnchorEngineTime != null) {
      _pranayamaAudioEngine.setClockAnchor(
        elapsed: Duration.zero,
        engineTime: clockAnchorEngineTime,
      );
    }
    _cachePranayamaSegmentTones(preset);
    _notifyPranayamaSession();
    if (restartAudio && !_isPranayamaPaused) {
      unawaited(
        _syncPranayamaAudio(forceRestart: clockAnchorEngineTime == null),
      );
    }
  }

  void _notifyPranayamaSession() {
    _pranayamaSessionNotifier.value = PranayamaSessionSnapshot(
      preset: _activePranayamaPreset,
      elapsed: _currentPranayamaElapsed,
      isPaused: _isPranayamaPaused,
      manualSegmentIndex: _pranayamaRemoteControlEnabled
          ? _activePranayamaSegmentIndex
          : null,
      pendingPreset: _pendingPranayamaTransition?.preset,
      pendingSegmentIndex: _pendingPranayamaTransition?.segmentIndex,
      remoteControlActive:
          _pranayamaRemoteControlEnabled && _activePranayamaPreset != null,
    );
  }

  Future<void> _beginPranayamaPreset(PranayamaPreset preset) async {
    final startGeneration = ++_pranayamaStartGeneration;
    _clearPendingPranayamaTransition();
    _recordRecentPranayamaPreset(preset);
    setState(() {
      _activePranayamaPreset = preset;
      _pranayamaStartedAt = null;
      _pranayamaElapsedBeforePause = Duration.zero;
      _isPranayamaPaused = false;
      _activePranayamaSegmentIndex = 0;
    });
    _notifyPranayamaSession();
    unawaited(_backgroundTimerService.start());
    _cachePranayamaSegmentTones(preset);
    await _startPranayamaAudio();

    if (!mounted ||
        startGeneration != _pranayamaStartGeneration ||
        _activePranayamaPreset?.id != preset.id ||
        _isPranayamaPaused) {
      return;
    }

    setState(() {
      _pranayamaStartedAt = _now();
    });
    _notifyPranayamaSession();
    _ensurePranayamaTicker();
  }

  void _togglePranayamaPaused() {
    final preset = _activePranayamaPreset;
    if (preset == null) {
      return;
    }

    if (_isPranayamaPaused) {
      unawaited(_resumePranayamaPreset(preset));
    } else {
      _pranayamaStartGeneration++;
      final elapsed = _currentPranayamaElapsed;
      _clearPendingPranayamaTransition();
      setState(() {
        _pranayamaElapsedBeforePause = elapsed;
        _pranayamaStartedAt = null;
        _isPranayamaPaused = true;
      });
      _notifyPranayamaSession();
      unawaited(_mutePranayamaAudio());
    }
  }

  Future<void> _resumePranayamaPreset(PranayamaPreset preset) async {
    final startGeneration = ++_pranayamaStartGeneration;
    setState(() {
      _pranayamaStartedAt = null;
      _isPranayamaPaused = false;
    });
    _notifyPranayamaSession();
    _cachePranayamaSegmentTones(preset);
    await _startPranayamaAudio();

    if (!mounted ||
        startGeneration != _pranayamaStartGeneration ||
        _activePranayamaPreset?.id != preset.id ||
        _isPranayamaPaused) {
      return;
    }

    setState(() {
      _pranayamaStartedAt = _now();
    });
    _notifyPranayamaSession();
    _ensurePranayamaTicker();
  }

  void _stopPranayamaSession({bool updateState = true}) {
    _pranayamaStartGeneration++;
    _pranayamaTicker?.cancel();
    _pranayamaTicker = null;
    _clearPendingPranayamaTransition();

    void clearSession() {
      _activePranayamaPreset = null;
      _pranayamaStartedAt = null;
      _pranayamaElapsedBeforePause = Duration.zero;
      _isPranayamaPaused = false;
      _activePranayamaSegmentIndex = 0;
    }

    unawaited(_stopPranayamaAudio());
    unawaited(_backgroundTimerService.stop());

    if (updateState) {
      setState(clearSession);
    } else {
      clearSession();
    }
    _notifyPranayamaSession();
  }

  void _clearPendingPranayamaTransition() {
    _pendingPranayamaTransitionTimer?.cancel();
    _pendingPranayamaTransitionTimer = null;
    _pendingPranayamaTransition = null;
  }

  void _ensurePranayamaTicker() {
    // 60-ish fps keeps the breathing dot smooth. When SoLoud is active, elapsed
    // time is read from the audio engine's clock; otherwise DateTime is the
    // fallback for silent/test runs.
    _pranayamaTicker ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) {
        return;
      }

      final preset = _activePranayamaPreset;
      if (preset == null || _isPranayamaPaused) {
        return;
      }

      final elapsed = _currentPranayamaElapsed;
      if (_pendingPranayamaTransition != null &&
          elapsed >= _pendingPranayamaTransition!.applyAtElapsed) {
        _applyPendingPranayamaTransition();
        return;
      }
      final effectiveDuration = _pranayamaRemoteControlEnabled
          ? null
          : _effectivePranayamaDuration(preset);
      if (effectiveDuration != null && elapsed >= effectiveDuration) {
        _stopPranayamaSession();
        return;
      }

      unawaited(_syncPranayamaAudio());
      setState(() {});
      _notifyPranayamaSession();
    });
  }

  Future<bool> _startPranayamaAudio() async {
    if (!_soundEnabled ||
        _activePranayamaPreset == null ||
        _isPranayamaPaused) {
      return false;
    }

    await _syncPranayamaAudio(forceRestart: true);
    return _pranayamaAudioEngine.hasClockAnchor;
  }

  Future<void> _syncPranayamaAudio({
    bool forceRestart = false,
    bool forceQueue = false,
  }) async {
    final activeOperation = _pranayamaAudioOperation;
    if (activeOperation != null && !forceRestart && !forceQueue) {
      return activeOperation;
    }
    if (forceRestart) {
      _pranayamaAudioGeneration++;
    }
    final generation = _pranayamaAudioGeneration;
    final previousOperation = _pranayamaAudioOperation ?? Future<void>.value();
    late final Future<void> operation;
    operation = previousOperation
        .then((_) {
          return _syncPranayamaAudioNow(
            forceRestart: forceRestart,
            generation: generation,
          );
        })
        .whenComplete(() {
          if (_pranayamaAudioOperation == operation) {
            _pranayamaAudioOperation = null;
          }
        });
    _pranayamaAudioOperation = operation;
    return operation;
  }

  Future<void> _syncPranayamaAudioNow({
    required bool forceRestart,
    required int generation,
  }) async {
    final preset = _activePranayamaPreset;
    if (!_soundEnabled || preset == null || _isPranayamaPaused) {
      await _mutePranayamaAudio();
      return;
    }

    if (!await _pranayamaAudioEngine.ensureReady()) {
      return;
    }
    if (generation != _pranayamaAudioGeneration ||
        !_soundEnabled ||
        _activePranayamaPreset == null ||
        _isPranayamaPaused) {
      return;
    }

    final currentElapsed = _currentPranayamaElapsed;
    if (forceRestart || !_pranayamaAudioEngine.hasClockAnchor) {
      await _cancelScheduledPranayamaAudio();
      final engineTime = _pranayamaAudioEngine.currentEngineTime;
      if (engineTime == null) {
        return;
      }
      _pranayamaAudioEngine.setClockAnchor(
        elapsed: currentElapsed,
        engineTime: engineTime + _pranayamaAudioStartLead,
      );
    }

    _pruneScheduledPranayamaAudio(currentElapsed);
    await _schedulePranayamaAudioAhead(
      currentElapsed: currentElapsed,
      generation: generation,
    );
  }

  Future<void> _schedulePranayamaAudioAhead({
    required Duration currentElapsed,
    required int generation,
  }) async {
    final preset = _activePranayamaPreset;
    if (preset == null || generation != _pranayamaAudioGeneration) {
      return;
    }

    final pendingTransition = _pendingPranayamaTransition;
    final lookAheadEnd = currentElapsed + _pranayamaAudioLookAhead;
    final activeTimelineId = _pranayamaAudioTimelineId(
      preset: preset,
      forcedSegmentIndex: _pranayamaRemoteControlEnabled
          ? _activePranayamaSegmentIndex
          : null,
    );

    await _schedulePranayamaAudioRange(
      preset: preset,
      timelineId: activeTimelineId,
      forcedSegmentIndex: _pranayamaRemoteControlEnabled
          ? _activePranayamaSegmentIndex
          : null,
      fromElapsed: currentElapsed,
      untilElapsed: pendingTransition == null
          ? lookAheadEnd
          : _minDuration(lookAheadEnd, pendingTransition.applyAtElapsed),
      engineTimeForElapsed: _pranayamaAudioEngine.engineTimeForElapsed,
      effectiveEnd: _pranayamaRemoteControlEnabled
          ? null
          : _effectivePranayamaDuration(preset),
      allowCycleBeyondUntilElapsed: pendingTransition == null,
      generation: generation,
    );

    if (pendingTransition == null ||
        lookAheadEnd <= pendingTransition.applyAtElapsed ||
        generation != _pranayamaAudioGeneration) {
      return;
    }

    final applyAtEngineTime =
        pendingTransition.applyAtEngineTime ??
        _pranayamaAudioEngine.engineTimeForElapsed(
          pendingTransition.applyAtElapsed,
        );
    if (applyAtEngineTime == null) {
      return;
    }

    // Timed sessions must use the same timeline before and after the switch.
    // Forcing segment zero here would queue an endless first segment and make
    // the normal scheduler add overlapping audio after the transition.
    final pendingForcedIndex = _pranayamaRemoteControlEnabled
        ? pendingTransition.segmentIndex
        : null;
    final pendingTimelineId = _pranayamaAudioTimelineId(
      preset: pendingTransition.preset,
      forcedSegmentIndex: pendingForcedIndex,
    );
    await _schedulePranayamaAudioRange(
      preset: pendingTransition.preset,
      timelineId: pendingTimelineId,
      forcedSegmentIndex: pendingForcedIndex,
      fromElapsed: Duration.zero,
      untilElapsed: lookAheadEnd - pendingTransition.applyAtElapsed,
      engineTimeForElapsed: (elapsed) => applyAtEngineTime + elapsed,
      effectiveEnd: _pranayamaRemoteControlEnabled
          ? null
          : _effectivePranayamaDuration(pendingTransition.preset),
      allowCycleBeyondUntilElapsed: true,
      generation: generation,
    );
  }

  Future<void> _schedulePranayamaAudioRange({
    required PranayamaPreset preset,
    required String timelineId,
    required int? forcedSegmentIndex,
    required Duration fromElapsed,
    required Duration untilElapsed,
    required Duration? Function(Duration elapsed) engineTimeForElapsed,
    required Duration? effectiveEnd,
    required bool allowCycleBeyondUntilElapsed,
    required int generation,
  }) async {
    var cursor = fromElapsed.isNegative ? Duration.zero : fromElapsed;
    var queuedCycles = 0;

    while (cursor < untilElapsed &&
        queuedCycles < _pranayamaAudioMaxQueuedCycles &&
        generation == _pranayamaAudioGeneration) {
      final existingCycle = _scheduledCycleCovering(
        timelineId: timelineId,
        elapsed: cursor,
      );
      if (existingCycle != null) {
        cursor = existingCycle.endElapsed;
        continue;
      }

      if (effectiveEnd != null && cursor >= effectiveEnd) {
        break;
      }

      final segmentPosition = _pranayamaSegmentAtElapsed(
        preset,
        cursor,
        forcedSegmentIndex: forcedSegmentIndex,
      );
      final cycleDuration = _pranayamaCycleDurationForSegment(
        segmentPosition.segment,
      );
      if (cycleDuration <= Duration.zero) {
        break;
      }
      final cycleMilliseconds = math.max(1, cycleDuration.inMilliseconds);
      final elapsedInCycle = Duration(
        milliseconds:
            segmentPosition.localElapsed.inMilliseconds % cycleMilliseconds,
      );
      final cycleRemaining = cycleDuration - elapsedInCycle;
      if (elapsedInCycle > Duration.zero) {
        final nextCycleBoundary = cursor + cycleRemaining;
        if ((effectiveEnd != null && nextCycleBoundary > effectiveEnd) ||
            (!allowCycleBeyondUntilElapsed &&
                nextCycleBoundary > untilElapsed)) {
          break;
        }
        // SoLoud's scheduled playback is sample-accurate when a whole voice is
        // placed on the engine clock. Seeking a delayed scheduled voice proved
        // fragile on quick pranayama timing changes, so partial current cycles
        // are intentionally left to the already-playing handle and future
        // audio is queued from the next breath boundary.
        cursor = nextCycleBoundary;
        continue;
      }
      final firstCycleEnd = cursor + cycleDuration;
      if ((effectiveEnd != null && firstCycleEnd > effectiveEnd) ||
          (!allowCycleBeyondUntilElapsed && firstCycleEnd > untilElapsed)) {
        break;
      }
      final schedulingWindowEnd = effectiveEnd == null
          ? untilElapsed
          : _minDuration(effectiveEnd, untilElapsed);
      final cycleCount = _pranayamaAudioChunkCycleCount(
        segmentPosition,
        schedulingWindowEnd - cursor,
        manualSegment: forcedSegmentIndex != null,
      );
      final playDuration = Duration(
        microseconds: cycleDuration.inMicroseconds * cycleCount,
      );
      if (playDuration <= Duration.zero) {
        break;
      }

      final atEngineTime = engineTimeForElapsed(cursor);
      if (atEngineTime == null) {
        break;
      }

      final toneClip = _toneChunkClipForPranayamaSegment(
        segmentPosition.segment,
        cycleCount: cycleCount,
      );
      final source = await _pranayamaAudioEngine.sourceForClip(
        key: _pranayamaToneChunkCacheKeyForSegment(
          segmentPosition.segment,
          cycleCount,
        ),
        clip: toneClip,
      );
      if (source == null || generation != _pranayamaAudioGeneration) {
        break;
      }

      final handle = _pranayamaAudioEngine.playScheduled(
        source: source,
        atEngineTime: atEngineTime,
        duration: playDuration,
      );
      if (handle == null) {
        break;
      }

      _scheduledPranayamaAudioCycles.add(
        _ScheduledPranayamaCycle(
          handle: handle,
          timelineId: timelineId,
          engineStartTime: atEngineTime,
          engineEndTime: atEngineTime + playDuration,
          startElapsed: cursor,
          endElapsed: cursor + playDuration,
        ),
      );
      cursor += playDuration;
      queuedCycles += cycleCount;
    }
  }

  _ScheduledPranayamaCycle? _scheduledCycleCovering({
    required String timelineId,
    required Duration elapsed,
  }) {
    for (final cycle in _scheduledPranayamaAudioCycles) {
      if (cycle.timelineId == timelineId &&
          cycle.startElapsed <= elapsed &&
          cycle.endElapsed > elapsed) {
        return cycle;
      }
    }
    return null;
  }

  String _pranayamaAudioTimelineId({
    required PranayamaPreset preset,
    required int? forcedSegmentIndex,
  }) {
    if (preset.segments.isEmpty) {
      return '${preset.id}:empty';
    }

    final clampedForcedSegmentIndex = forcedSegmentIndex
        ?.clamp(0, preset.segments.length - 1)
        .toInt();
    final segmentKeys = forcedSegmentIndex == null
        ? [
            for (final segment in preset.segments)
              _pranayamaToneCacheKeyForSegment(segment),
          ]
        : [
            _pranayamaToneCacheKeyForSegment(
              preset.segments[clampedForcedSegmentIndex!],
            ),
          ];
    return [
      preset.id,
      clampedForcedSegmentIndex ?? 'sequence',
      ...segmentKeys,
    ].join(':');
  }

  Duration _minDuration(Duration first, Duration second) {
    return first <= second ? first : second;
  }

  void _pruneScheduledPranayamaAudio(Duration currentElapsed) {
    final engineTime = _pranayamaAudioEngine.currentEngineTime;
    if (engineTime != null) {
      _scheduledPranayamaAudioCycles.removeWhere(
        (cycle) => cycle.engineEndTime <= engineTime,
      );
      return;
    }

    _scheduledPranayamaAudioCycles.removeWhere(
      (cycle) => cycle.endElapsed <= currentElapsed,
    );
  }

  Future<void> _cancelScheduledPranayamaAudio({
    Duration? fromElapsed,
    Duration? fromEngineTime,
    Set<String> timelineIds = const <String>{},
    String? keepCurrentTimelineId,
    Duration? keepCurrentElapsed,
    Duration? keepCurrentEngineTime,
    Duration? stopKeptAtEngineTime,
  }) async {
    if (_scheduledPranayamaAudioCycles.isEmpty) {
      return;
    }

    final elapsedCutoff = fromElapsed == null
        ? null
        : fromElapsed - _pranayamaTransitionCancelTolerance;
    final engineCutoff = fromEngineTime == null
        ? null
        : fromEngineTime - _pranayamaTransitionCancelTolerance;
    final engineKeepTime = keepCurrentEngineTime;
    final elapsedKeepTime = keepCurrentElapsed;
    final shouldStopAll =
        fromElapsed == null && fromEngineTime == null && timelineIds.isEmpty;
    final handlesToStop = <SoundHandle>[];
    final handlesToStopAtBoundary = <SoundHandle>[];
    _scheduledPranayamaAudioCycles.removeWhere((cycle) {
      final shouldKeepCurrentCycle =
          keepCurrentTimelineId != null &&
          cycle.timelineId == keepCurrentTimelineId &&
          elapsedKeepTime != null &&
          cycle.startElapsed <= elapsedKeepTime &&
          cycle.endElapsed > elapsedKeepTime &&
          (engineKeepTime == null ||
              (cycle.engineStartTime <=
                      engineKeepTime + _pranayamaTransitionCancelTolerance &&
                  cycle.engineEndTime > engineKeepTime));
      if (shouldKeepCurrentCycle) {
        if (stopKeptAtEngineTime != null) {
          handlesToStopAtBoundary.add(cycle.handle);
        }
        return false;
      }

      final shouldStop =
          shouldStopAll ||
          timelineIds.contains(cycle.timelineId) ||
          (elapsedCutoff != null && cycle.startElapsed >= elapsedCutoff) ||
          (engineCutoff != null && cycle.engineStartTime >= engineCutoff);
      if (shouldStop) {
        handlesToStop.add(cycle.handle);
      }
      return shouldStop;
    });
    _pranayamaAudioEngine.stopHandlesAt(
      handlesToStopAtBoundary,
      stopKeptAtEngineTime ?? Duration.zero,
    );
    await _pranayamaAudioEngine.stopHandles(handlesToStop);
  }

  Future<void> _mutePranayamaAudio() async {
    _pranayamaAudioGeneration++;
    await _cancelScheduledPranayamaAudio();
    _pranayamaAudioEngine.releaseClockAnchor();
  }

  Future<void> _stopPranayamaAudio() async {
    _pranayamaAudioGeneration++;
    await _cancelScheduledPranayamaAudio();
    _pranayamaAudioEngine.releaseClockAnchor();
  }

  void _disposePranayamaAudioEngine() {
    _pranayamaAudioGeneration++;
    unawaited(() async {
      await _cancelScheduledPranayamaAudio();
      await _pranayamaAudioEngine.dispose();
    }());
  }

  _PranayamaToneClip _toneClipForPranayamaSegment(PranayamaSegment segment) {
    final cacheKey = _pranayamaToneCacheKeyForSegment(segment);
    return _pranayamaToneCache.putIfAbsent(
      cacheKey,
      () => _generatePranayamaToneClip(segment),
    );
  }

  _PranayamaToneClip _toneChunkClipForPranayamaSegment(
    PranayamaSegment segment, {
    required int cycleCount,
  }) {
    final cacheKey = _pranayamaToneChunkCacheKeyForSegment(segment, cycleCount);
    return _pranayamaToneCache.putIfAbsent(
      cacheKey,
      () => _generatePranayamaToneChunkClip(
        segment: segment,
        cycleCount: cycleCount,
      ),
    );
  }

  void _cachePranayamaSegmentTones(PranayamaPreset preset) {
    for (final segment in preset.segments) {
      _toneClipForPranayamaSegment(segment);
    }
  }

  Duration get _currentPranayamaElapsed {
    final engineElapsed =
        _soundEnabled && !_isPranayamaPaused && _activePranayamaPreset != null
        ? _pranayamaAudioEngine.currentElapsed
        : null;
    if (engineElapsed != null) {
      return engineElapsed;
    }

    if (_isPranayamaPaused || _pranayamaStartedAt == null) {
      return _pranayamaElapsedBeforePause;
    }

    return _pranayamaElapsedBeforePause +
        _now().difference(_pranayamaStartedAt!);
  }

  void _recordRecentPranayamaPreset(PranayamaPreset preset) {
    setState(() {
      _recentPranayamaPresetIds.remove(preset.id);
      if (_recentTimerLimit > 0) {
        _recentPranayamaPresetIds.insert(0, preset.id);
      }
      if (_recentPranayamaPresetIds.length > _recentTimerLimit) {
        _recentPranayamaPresetIds.removeRange(
          _recentTimerLimit,
          _recentPranayamaPresetIds.length,
        );
      }
    });

    unawaited(_saveRecentPranayamaPresetIds());
  }

  Future<void> _saveRecentPranayamaPresetIds() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _recentPranayamaPresetIdsKey,
      jsonEncode(_recentPranayamaPresetIds),
    );
  }

  List<PranayamaPreset> get _recentPranayamaPresets {
    return [
      for (final presetId in _recentPranayamaPresetIds)
        ?_pranayamaPresetByIdInEntries(presetId, _pranayamaEntries),
    ];
  }

  Future<void> _openLogs() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LogsScreen()));
    if (!mounted) {
      return;
    }

    setState(() {
      _statsRefreshKey += 1;
    });
  }

  void _openAcknowledgements() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AcknowledgementsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeMeditationTimer = _activeMeditationTimer;
    final activeMeditationSessionKey = _activeMeditationSessionKey;
    final homeScaffold = _buildHomeScaffold();
    if (activeMeditationTimer == null || activeMeditationSessionKey == null) {
      return homeScaffold;
    }

    return IndexedStack(
      index: _isMeditationSessionVisible ? 1 : 0,
      children: [
        homeScaffold,
        MeditationSessionScreen(
          key: activeMeditationSessionKey,
          timer: activeMeditationTimer,
          playBells: _soundEnabled,
          turnScreenOnNearAudio: _turnScreenOnNearAudio,
          logStore: _logStore,
          backgroundTimerService: _backgroundTimerService,
          now: widget.now ?? DateTime.now,
          onDetachedEndingBellRequested: _playDetachedEndingBell,
          onSessionClosed: _clearActiveMeditationSession,
          onMinimizeRequested: _minimizeActiveMeditationSession,
          onElapsedChanged: _updateActiveMeditationElapsed,
          pranayamaSessionListenable: _pranayamaSessionNotifier,
          pranayamaEntries: _pranayamaEntries,
          recentPranayamaPresets: _recentPranayamaPresets,
          expandedPranayamaFolders: _expandedPranayamaFolders,
          onStartPranayamaPreset: _startPranayamaPreset,
          onTogglePranayamaPaused: _togglePranayamaPaused,
          onStopPranayama: _stopPranayamaSession,
        ),
      ],
    );
  }

  Widget _buildHomeScaffold() {
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
                  child: switch (_selectedTab) {
                    HomeTab.timers => _TimersTab(
                      activeMeditationSession: _activeMeditationTimer == null
                          ? null
                          : _ActiveMeditationSessionInfo(
                              timer: _activeMeditationTimer!,
                              elapsed: _activeMeditationElapsed,
                            ),
                      recentTimersCollapsed: _recentTimersCollapsed,
                      recentTimers: _recentTimers,
                      isEditingTimerPositions: _isEditingTimerPositions,
                      expandedFolders: _expandedFolders,
                      timerEntries: _timerEntries,
                      onToggleRecentTimers: _toggleRecentTimers,
                      onAddTimer: _createTimer,
                      onAddFolder: _addFolder,
                      onToggleTimerPositionEditing: _toggleTimerPositionEditing,
                      onEditTimer: _editTimer,
                      onDeleteTimer: _confirmDeleteTimer,
                      onEditFolderTitle: _editFolderTitle,
                      onDeleteFolder: _deleteFolder,
                      onToggleFolder: _toggleFolder,
                      onReorderTimerEntry: _reorderTimerEntry,
                      onStartTimer: _startTimer,
                      onOpenActiveMeditationSession:
                          _showActiveMeditationSession,
                      onDiscardActiveMeditationSession:
                          _discardActiveMeditationSession,
                    ),
                    HomeTab.pranayama => _PranayamaTab(
                      recentPresetsCollapsed: _recentPranayamaCollapsed,
                      recentPresets: _recentPranayamaPresets,
                      isEditingPresetPositions: _isEditingPranayamaPositions,
                      expandedFolders: _expandedPranayamaFolders,
                      presetEntries: _pranayamaEntries,
                      activePreset: _activePranayamaPreset,
                      elapsed: _currentPranayamaElapsed,
                      isPaused: _isPranayamaPaused,
                      manualSegmentIndex: _pranayamaRemoteControlEnabled
                          ? _activePranayamaSegmentIndex
                          : null,
                      pendingPreset: _pendingPranayamaTransition?.preset,
                      pendingSegmentIndex:
                          _pendingPranayamaTransition?.segmentIndex,
                      remoteControlActive: _pranayamaRemoteControlEnabled,
                      onToggleRecentPresets: _toggleRecentPranayamaPresets,
                      onAddPreset: _createPranayamaPreset,
                      onAddFolder: _addPranayamaFolder,
                      onTogglePresetPositionEditing:
                          _togglePranayamaPositionEditing,
                      onEditPreset: _editPranayamaPreset,
                      onDeletePreset: _confirmDeletePranayamaPreset,
                      onEditFolderTitle: _editPranayamaFolderTitle,
                      onDeleteFolder: _deletePranayamaFolder,
                      onToggleFolder: _togglePranayamaFolder,
                      onReorderPresetEntry: _reorderPranayamaEntry,
                      onStartPreset: _startPranayamaPreset,
                      onTogglePause: _togglePranayamaPaused,
                      onStop: _stopPranayamaSession,
                    ),
                    HomeTab.stats => _StatsTab(
                      logStore: _logStore,
                      refreshKey: _statsRefreshKey,
                      onViewEditLogs: _openLogs,
                    ),
                    HomeTab.settings => _SettingsTab(
                      soundEnabled: _soundEnabled,
                      turnScreenOnNearAudio: _turnScreenOnNearAudio,
                      pranayamaRemoteControlEnabled:
                          _pranayamaRemoteControlEnabled,
                      pranayamaRemoteCommandBindings:
                          _pranayamaRemoteCommandBindings,
                      recentTimerLimit: _recentTimerLimit,
                      onSoundEnabledChanged: (enabled) =>
                          _setSoundEnabled(enabled: enabled),
                      onTurnScreenOnNearAudioChanged: (enabled) =>
                          _setTurnScreenOnNearAudio(enabled: enabled),
                      onPranayamaRemoteControlEnabledChanged: (enabled) =>
                          _setPranayamaRemoteControlEnabled(enabled: enabled),
                      onCapturePranayamaRemoteCommandKey:
                          _capturePranayamaRemoteCommandKey,
                      onClearPranayamaRemoteCommandKey:
                          _clearPranayamaRemoteCommandKey,
                      onOpenPranayamaRemoteDiagnostics:
                          _openPranayamaRemoteDiagnostics,
                      onOpenRemoteAccessibilitySettings:
                          _openRemoteAccessibilitySettings,
                      onRecentTimerLimitChanged: _setRecentTimerLimit,
                      onTestSound: _testSound,
                      onPrepareBackgroundTimerSupport:
                          _prepareBackgroundTimerSupport,
                      onOpenBackgroundSetupGuide: _openBackgroundSetupHelp,
                      onReinstallDefaultPresets: _reinstallDefaultPresets,
                      onImportPresets: _importPresetsJson,
                      onExportPresets: _exportPresetsJson,
                      onImportLogs: _importLogsCsv,
                      onExportLogs: _exportLogsCsv,
                      onPurgeLogs: _confirmPurgeLogs,
                      onOpenAcknowledgements: _openAcknowledgements,
                    ),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingPranayamaTransition {
  const _PendingPranayamaTransition({
    required this.preset,
    required this.segmentIndex,
    required this.applyAtElapsed,
    required this.applyAtEngineTime,
    required this.recordRecentPreset,
  });

  final PranayamaPreset preset;
  final int segmentIndex;
  final Duration applyAtElapsed;
  final Duration? applyAtEngineTime;
  final bool recordRecentPreset;
}

class _PranayamaRemoteKeyCaptureDialog extends StatefulWidget {
  const _PranayamaRemoteKeyCaptureDialog({
    required this.command,
    required this.remoteInputEvents,
    required this.initialLatestSerial,
  });

  final PranayamaRemoteCommand command;
  final ValueListenable<List<_PranayamaRemoteInputDebugEvent>>
  remoteInputEvents;
  final int initialLatestSerial;

  @override
  State<_PranayamaRemoteKeyCaptureDialog> createState() =>
      _PranayamaRemoteKeyCaptureDialogState();
}

class _PranayamaRemoteKeyCaptureDialogState
    extends State<_PranayamaRemoteKeyCaptureDialog> {
  final FocusNode _focusNode = FocusNode();
  late int _latestHandledSerial = widget.initialLatestSerial;

  @override
  void initState() {
    super.initState();
    widget.remoteInputEvents.addListener(_handleNativeInputEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    widget.remoteInputEvents.removeListener(_handleNativeInputEvent);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleNativeInputEvent() {
    if (!mounted || widget.remoteInputEvents.value.isEmpty) {
      return;
    }

    final event = widget.remoteInputEvents.value.first;
    if (event.serial <= _latestHandledSerial) {
      return;
    }
    _latestHandledSerial = event.serial;

    final binding = event.binding;
    if (binding == null ||
        !event.isCommandTrigger ||
        event.origin != 'activity' &&
            event.origin != 'mediaSession' &&
            event.origin != 'mediaSessionCallback' &&
            event.origin != 'accessibility' &&
            event.origin != 'genericMotion' &&
            event.origin != 'trackball' &&
            event.origin != 'touch' &&
            event.origin != 'externalTouch') {
      return;
    }

    Navigator.of(context).pop(binding);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    Navigator.of(context).pop(
      PranayamaRemoteInputBinding.flutterLogicalKey(event.logicalKey.keyId),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF19191D),
      title: const Text('Set remote key'),
      content: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 260),
          child: Text(
            'Press a keyboard, media, scroll, or remote button for ${_pranayamaRemoteCommandLabel(widget.command)}.',
            style: const TextStyle(color: Colors.white, letterSpacing: 0),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('cancel-pranayama-remote-key-capture-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _PranayamaRemoteDiagnosticsDialog extends StatelessWidget {
  const _PranayamaRemoteDiagnosticsDialog({
    required this.remoteInputEvents,
    required this.onClear,
  });

  final ValueListenable<List<_PranayamaRemoteInputDebugEvent>>
  remoteInputEvents;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF19191D),
      title: const Text('Remote input diagnostics'),
      content: SizedBox(
        width: 360,
        child: ValueListenableBuilder<List<_PranayamaRemoteInputDebugEvent>>(
          valueListenable: remoteInputEvents,
          builder: (context, events, _) {
            if (events.isEmpty) {
              return const Text(
                'Press remote buttons now. If nothing appears here, Android is not delivering key, media, scroll, or pointer events to the app.',
                style: TextStyle(color: _mutedTextColor, letterSpacing: 0),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: events.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: Color(0xFF303036)),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      event.diagnosticLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                        letterSpacing: 0,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('clear-pranayama-remote-diagnostics-button'),
          onPressed: onClear,
          child: const Text('Clear'),
        ),
        TextButton(
          key: const ValueKey('close-pranayama-remote-diagnostics-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _PranayamaRemoteInputDebugEvent {
  const _PranayamaRemoteInputDebugEvent({
    required this.serial,
    required this.origin,
    required this.action,
    required this.label,
    required this.binding,
    this.details,
    this.repeatCount = 0,
    this.scanCode,
    this.deviceId,
    this.source,
    this.eventTime,
    this.downTime,
  });

  factory _PranayamaRemoteInputDebugEvent.fromFlutterKeyEvent({
    required int serial,
    required KeyEvent event,
  }) {
    final action = switch (event) {
      KeyDownEvent() => 'down',
      KeyRepeatEvent() => 'repeat',
      KeyUpEvent() => 'up',
      _ => 'unknown',
    };
    final binding = PranayamaRemoteInputBinding.flutterLogicalKey(
      event.logicalKey.keyId,
    );
    return _PranayamaRemoteInputDebugEvent(
      serial: serial,
      origin: 'flutter',
      action: action,
      label: _pranayamaRemoteInputBindingLabel(binding),
      binding: binding,
      repeatCount: event is KeyRepeatEvent ? 1 : 0,
    );
  }

  static _PranayamaRemoteInputDebugEvent? fromAndroidPayload({
    required int serial,
    required String method,
    required Object? payload,
  }) {
    if (payload is! Map) {
      return null;
    }

    return switch (method) {
      'androidKeyEvent' => _fromAndroidKeyPayload(
        serial: serial,
        payload: payload,
      ),
      'androidMotionEvent' => _fromAndroidMotionPayload(
        serial: serial,
        payload: payload,
      ),
      _ => null,
    };
  }

  static _PranayamaRemoteInputDebugEvent? _fromAndroidKeyPayload({
    required int serial,
    required Map<dynamic, dynamic> payload,
  }) {
    final keyCode = payload['keyCode'];
    final action = payload['action'];
    if (keyCode is! int || action is! int) {
      return null;
    }

    final binding = PranayamaRemoteInputBinding.androidKeyCode(keyCode);
    final origin = payload['origin'];
    final keyLabel = payload['keyLabel'];
    return _PranayamaRemoteInputDebugEvent(
      serial: serial,
      origin: origin is String ? origin : 'android',
      action: switch (action) {
        0 => 'down',
        1 => 'up',
        2 => 'multiple',
        _ => 'action-$action',
      },
      label: keyLabel is String ? keyLabel : _androidKeyCodeLabel(keyCode),
      binding: binding,
      repeatCount: payload['repeatCount'] is int
          ? payload['repeatCount'] as int
          : 0,
      scanCode: payload['scanCode'] is int ? payload['scanCode'] as int : null,
      deviceId: payload['deviceId'] is int ? payload['deviceId'] as int : null,
      source: payload['source'] is int ? payload['source'] as int : null,
      eventTime: payload['eventTime'] is int
          ? payload['eventTime'] as int
          : null,
      downTime: payload['downTime'] is int ? payload['downTime'] as int : null,
    );
  }

  static _PranayamaRemoteInputDebugEvent? _fromAndroidMotionPayload({
    required int serial,
    required Map<dynamic, dynamic> payload,
  }) {
    final action = payload['action'];
    if (action is! int) {
      return null;
    }

    final origin = payload['origin'];
    final actionLabel = payload['actionLabel'];
    final verticalScroll = _remotePayloadDouble(payload['vscroll']) ?? 0;
    final horizontalScroll = _remotePayloadDouble(payload['hscroll']) ?? 0;
    final buttonState = payload['buttonState'] is int
        ? payload['buttonState'] as int
        : 0;
    final actionButton = payload['actionButton'] is int
        ? payload['actionButton'] as int
        : 0;
    final x = _remotePayloadDouble(payload['x']);
    final y = _remotePayloadDouble(payload['y']);
    final startX = _remotePayloadDouble(payload['startX']);
    final startY = _remotePayloadDouble(payload['startY']);
    final deltaX = _remotePayloadDouble(payload['deltaX']);
    final deltaY = _remotePayloadDouble(payload['deltaY']);
    final binding = _androidMotionBindingForPayload(
      origin: origin is String ? origin : 'androidMotion',
      action: action,
      verticalScroll: verticalScroll,
      horizontalScroll: horizontalScroll,
      buttonState: buttonState,
      actionButton: actionButton,
      deltaX: deltaX,
      deltaY: deltaY,
    );
    final details = [
      if (verticalScroll.abs() > 0.001)
        'v=${_remotePayloadDoubleLabel(verticalScroll)}',
      if (horizontalScroll.abs() > 0.001)
        'h=${_remotePayloadDoubleLabel(horizontalScroll)}',
      if (buttonState != 0) 'buttons=$buttonState',
      if (actionButton != 0) 'button=$actionButton',
      if (startX != null) 'sx=${_remotePayloadDoubleLabel(startX)}',
      if (startY != null) 'sy=${_remotePayloadDoubleLabel(startY)}',
      if (deltaX != null) 'dx=${_remotePayloadDoubleLabel(deltaX)}',
      if (deltaY != null) 'dy=${_remotePayloadDoubleLabel(deltaY)}',
      if (x != null) 'x=${_remotePayloadDoubleLabel(x)}',
      if (y != null) 'y=${_remotePayloadDoubleLabel(y)}',
    ].join(' ');

    return _PranayamaRemoteInputDebugEvent(
      serial: serial,
      origin: origin is String ? origin : 'androidMotion',
      action: actionLabel is String ? actionLabel : 'action-$action',
      label: binding == null
          ? 'Android motion'
          : _pranayamaRemoteInputBindingLabel(binding),
      binding: binding,
      details: details.isEmpty ? null : details,
      deviceId: payload['deviceId'] is int ? payload['deviceId'] as int : null,
      source: payload['source'] is int ? payload['source'] as int : null,
      eventTime: payload['eventTime'] is int
          ? payload['eventTime'] as int
          : null,
      downTime: payload['downTime'] is int ? payload['downTime'] as int : null,
    );
  }

  final int serial;
  final String origin;
  final String action;
  final String label;
  final PranayamaRemoteInputBinding? binding;
  final String? details;
  final int repeatCount;
  final int? scanCode;
  final int? deviceId;
  final int? source;
  final int? eventTime;
  final int? downTime;

  bool get isDown => action == 'down';
  bool get isCommandTrigger {
    if (origin == 'accessibility') {
      return action == 'up';
    }
    if (origin == 'externalTouch') {
      return action == 'up';
    }
    return action == 'down' || action == 'scroll';
  }

  String? get androidCommandSignature {
    if (binding == null ||
        binding!.type == PranayamaRemoteInputType.flutterLogicalKey ||
        eventTime == null) {
      return null;
    }
    return '${binding!.type.name}:${binding!.code}:$action:$eventTime:$downTime';
  }

  String get diagnosticLabel {
    final bindingLabel = binding == null
        ? label
        : _pranayamaRemoteInputBindingLabel(binding!);
    return [
      '#$serial',
      origin,
      action,
      bindingLabel,
      if (repeatCount > 0) 'repeat=$repeatCount',
      ?details,
      if (scanCode != null) 'scan=$scanCode',
      if (deviceId != null) 'device=$deviceId',
      if (source != null) 'source=$source',
    ].join(' | ');
  }
}

PranayamaRemoteInputBinding? _androidMotionBindingForPayload({
  required String origin,
  required int action,
  required double verticalScroll,
  required double horizontalScroll,
  required int buttonState,
  required int actionButton,
  required double? deltaX,
  required double? deltaY,
}) {
  const upAction = 1;
  if (origin == 'externalTouch' && action == upAction) {
    final dx = deltaX ?? 0;
    final dy = deltaY ?? 0;
    const swipeThreshold = 80.0;

    if (dx.abs() < swipeThreshold && dy.abs() < swipeThreshold) {
      return const PranayamaRemoteInputBinding.androidMotion(
        _androidMotionExternalTouchTapCode,
      );
    }

    if (dy.abs() >= dx.abs()) {
      return PranayamaRemoteInputBinding.androidMotion(
        dy < 0
            ? _androidMotionExternalTouchSwipeUpCode
            : _androidMotionExternalTouchSwipeDownCode,
      );
    }

    return PranayamaRemoteInputBinding.androidMotion(
      dx < 0
          ? _androidMotionExternalTouchSwipeLeftCode
          : _androidMotionExternalTouchSwipeRightCode,
    );
  }

  const scrollAction = 8;
  if (action == scrollAction) {
    if (verticalScroll.abs() >= horizontalScroll.abs() &&
        verticalScroll.abs() > 0.001) {
      return PranayamaRemoteInputBinding.androidMotion(
        verticalScroll > 0
            ? _androidMotionVerticalScrollPositiveCode
            : _androidMotionVerticalScrollNegativeCode,
      );
    }

    if (horizontalScroll.abs() > 0.001) {
      return PranayamaRemoteInputBinding.androidMotion(
        horizontalScroll > 0
            ? _androidMotionHorizontalScrollPositiveCode
            : _androidMotionHorizontalScrollNegativeCode,
      );
    }
  }

  const downAction = 0;
  if (action == downAction) {
    final button = actionButton != 0 ? actionButton : buttonState;
    return switch (button) {
      1 => const PranayamaRemoteInputBinding.androidMotion(
        _androidMotionPointerPrimaryClickCode,
      ),
      2 => const PranayamaRemoteInputBinding.androidMotion(
        _androidMotionPointerSecondaryClickCode,
      ),
      4 => const PranayamaRemoteInputBinding.androidMotion(
        _androidMotionPointerMiddleClickCode,
      ),
      8 => const PranayamaRemoteInputBinding.androidMotion(
        _androidMotionPointerBackClickCode,
      ),
      16 => const PranayamaRemoteInputBinding.androidMotion(
        _androidMotionPointerForwardClickCode,
      ),
      _ => null,
    };
  }

  return null;
}

double? _remotePayloadDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  return null;
}

String _remotePayloadDoubleLabel(double value) {
  return value.toStringAsFixed(2);
}

int _clampRecentTimerLimit(int value) {
  return value.clamp(0, _maxRecentTimerLimit).toInt();
}

List<String> _decodeRecentTimerIds(String? encodedIds) {
  if (encodedIds == null) {
    return const [];
  }

  try {
    final decoded = jsonDecode(encodedIds);
    if (decoded is! List) {
      return const [];
    }

    return [
      for (final item in decoded)
        if (item is String && item.trim().isNotEmpty) item,
    ];
  } on FormatException {
    return const [];
  } on TypeError {
    return const [];
  }
}

MeditationTimerPreset? _timerByIdInEntries(
  String timerId,
  List<TimerBrowserEntry> entries,
) {
  for (final entry in entries) {
    switch (entry) {
      case TimerPresetEntry(:final timer):
        if (timer.id == timerId) {
          return timer;
        }
      case TimerFolderEntry(:final folder):
        for (final timer in folder.timers) {
          if (timer.id == timerId) {
            return timer;
          }
        }
    }
  }

  return null;
}

class _HomeTabBar extends StatelessWidget {
  const _HomeTabBar({required this.selectedTab, required this.onTabSelected});

  final HomeTab selectedTab;
  final ValueChanged<HomeTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tab in [HomeTab.timers, HomeTab.pranayama, HomeTab.stats])
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

enum _PresetConflictChoice { override, ignore }

class _PresetBundle {
  const _PresetBundle({
    required this.timerEntries,
    required this.pranayamaEntries,
  });

  final List<TimerBrowserEntry> timerEntries;
  final List<PranayamaBrowserEntry> pranayamaEntries;
}

class _PresetImportResult {
  const _PresetImportResult({
    required this.addedCount,
    required this.overwrittenCount,
    required this.skippedCount,
  });

  final int addedCount;
  final int overwrittenCount;
  final int skippedCount;
}

class _TimerPresetMergeResult {
  const _TimerPresetMergeResult({
    required this.entries,
    required this.addedCount,
    required this.overwrittenCount,
    required this.skippedCount,
  });

  final List<TimerBrowserEntry> entries;
  final int addedCount;
  final int overwrittenCount;
  final int skippedCount;
}

class _PranayamaPresetMergeResult {
  const _PranayamaPresetMergeResult({
    required this.entries,
    required this.addedCount,
    required this.overwrittenCount,
    required this.skippedCount,
  });

  final List<PranayamaBrowserEntry> entries;
  final int addedCount;
  final int overwrittenCount;
  final int skippedCount;
}

_PresetBundle? _decodePresetBundle(String jsonText) {
  try {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, Object?>) {
      return null;
    }

    final encodedTimers = decoded['timers'];
    final encodedPranayama = decoded['pranayama'];
    if (encodedTimers is! List || encodedPranayama is! List) {
      return null;
    }

    final timerEntries = _decodeTimerEntries(jsonEncode(encodedTimers));
    final pranayamaEntries = _decodePranayamaEntries(
      jsonEncode(encodedPranayama),
    );
    if (timerEntries == null || pranayamaEntries == null) {
      return null;
    }

    return _PresetBundle(
      timerEntries: timerEntries,
      pranayamaEntries: pranayamaEntries,
    );
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

String _encodePresetBundle(_PresetBundle bundle) {
  // This is the public preset interchange format. It deliberately reuses the
  // same entry JSON used for SharedPreferences so import/export, persistence,
  // and bundled defaults cannot silently drift apart.
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert({
    'timers': _encodeTimerEntries(bundle.timerEntries),
    'pranayama': _encodePranayamaEntries(bundle.pranayamaEntries),
  });
}

int _presetBundleConflicts({
  required List<TimerBrowserEntry> timerEntries,
  required List<PranayamaBrowserEntry> pranayamaEntries,
  required _PresetBundle importedBundle,
}) {
  final timerNames = _timerNamesInEntries(timerEntries);
  final pranayamaNames = _pranayamaPresetNamesInEntries(pranayamaEntries);
  var conflicts = 0;

  for (final importedTimer in _flattenTimerPresets(
    importedBundle.timerEntries,
  )) {
    if (timerNames.contains(importedTimer.preset.name)) {
      conflicts += 1;
    }
  }
  for (final importedPreset in _flattenPranayamaPresets(
    importedBundle.pranayamaEntries,
  )) {
    if (pranayamaNames.contains(importedPreset.preset.name)) {
      conflicts += 1;
    }
  }

  return conflicts;
}

String _presetImportMessage(String prefix, _PresetImportResult result) {
  return '$prefix. Added ${result.addedCount}, overridden ${result.overwrittenCount}, skipped ${result.skippedCount}.';
}

_TimerPresetMergeResult _mergeTimerEntryPresets(
  List<TimerBrowserEntry> currentEntries,
  List<TimerBrowserEntry> importedEntries, {
  required bool overrideExisting,
}) {
  final entries = _copyTimerEntries(currentEntries);
  var addedCount = 0;
  var overwrittenCount = 0;
  var skippedCount = 0;

  // Flatten imported folders to presets, then reinsert each preset into the
  // matching folder in the current tree. This recreates missing defaults without
  // disturbing unrelated user folders or their existing order.
  for (final importedTimer in _flattenTimerPresets(importedEntries)) {
    if (_timerNamesInEntries(entries).contains(importedTimer.preset.name)) {
      if (overrideExisting) {
        _replaceTimerPresetByName(entries, importedTimer.preset);
        overwrittenCount += 1;
      } else {
        skippedCount += 1;
      }
      continue;
    }

    _insertTimerPresetInFolder(entries, importedTimer);
    addedCount += 1;
  }

  return _TimerPresetMergeResult(
    entries: entries,
    addedCount: addedCount,
    overwrittenCount: overwrittenCount,
    skippedCount: skippedCount,
  );
}

_PranayamaPresetMergeResult _mergePranayamaEntryPresets(
  List<PranayamaBrowserEntry> currentEntries,
  List<PranayamaBrowserEntry> importedEntries, {
  required bool overrideExisting,
}) {
  final entries = _copyPranayamaEntries(currentEntries);
  var addedCount = 0;
  var overwrittenCount = 0;
  var skippedCount = 0;

  // Same strategy as timers: only presets participate in conflict resolution;
  // folders are containers recreated as needed for newly added presets.
  for (final importedPreset in _flattenPranayamaPresets(importedEntries)) {
    if (_pranayamaPresetNamesInEntries(
      entries,
    ).contains(importedPreset.preset.name)) {
      if (overrideExisting) {
        _replacePranayamaPresetByName(entries, importedPreset.preset);
        overwrittenCount += 1;
      } else {
        skippedCount += 1;
      }
      continue;
    }

    _insertPranayamaPresetInFolder(entries, importedPreset);
    addedCount += 1;
  }

  return _PranayamaPresetMergeResult(
    entries: entries,
    addedCount: addedCount,
    overwrittenCount: overwrittenCount,
    skippedCount: skippedCount,
  );
}

List<TimerBrowserEntry> _copyTimerEntries(List<TimerBrowserEntry> entries) {
  return [
    for (final entry in entries)
      switch (entry) {
        TimerPresetEntry(:final timer) => TimerPresetEntry(timer),
        TimerFolderEntry(:final folder) => TimerFolderEntry(
          TimerFolder(name: folder.name, timers: List.of(folder.timers)),
        ),
      },
  ];
}

List<PranayamaBrowserEntry> _copyPranayamaEntries(
  List<PranayamaBrowserEntry> entries,
) {
  return [
    for (final entry in entries)
      switch (entry) {
        PranayamaPresetEntry(:final preset) => PranayamaPresetEntry(preset),
        PranayamaFolderEntry(:final folder) => PranayamaFolderEntry(
          PranayamaFolder(name: folder.name, presets: List.of(folder.presets)),
        ),
      },
  ];
}

Set<String> _timerNamesInEntries(List<TimerBrowserEntry> entries) {
  return {
    for (final importedTimer in _flattenTimerPresets(entries))
      importedTimer.preset.name,
  };
}

Set<String> _pranayamaPresetNamesInEntries(
  List<PranayamaBrowserEntry> entries,
) {
  return {
    for (final importedPreset in _flattenPranayamaPresets(entries))
      importedPreset.preset.name,
  };
}

List<({MeditationTimerPreset preset, String? folderName})> _flattenTimerPresets(
  List<TimerBrowserEntry> entries,
) {
  final presets = <({MeditationTimerPreset preset, String? folderName})>[];
  for (final entry in entries) {
    switch (entry) {
      case TimerPresetEntry(:final timer):
        presets.add((preset: timer, folderName: null));
      case TimerFolderEntry(:final folder):
        for (final timer in folder.timers) {
          presets.add((preset: timer, folderName: folder.name));
        }
    }
  }

  return presets;
}

List<({PranayamaPreset preset, String? folderName})> _flattenPranayamaPresets(
  List<PranayamaBrowserEntry> entries,
) {
  final presets = <({PranayamaPreset preset, String? folderName})>[];
  for (final entry in entries) {
    switch (entry) {
      case PranayamaPresetEntry(:final preset):
        presets.add((preset: preset, folderName: null));
      case PranayamaFolderEntry(:final folder):
        for (final preset in folder.presets) {
          presets.add((preset: preset, folderName: folder.name));
        }
    }
  }

  return presets;
}

void _replaceTimerPresetByName(
  List<TimerBrowserEntry> entries,
  MeditationTimerPreset preset,
) {
  for (var index = 0; index < entries.length; index += 1) {
    final entry = entries[index];
    switch (entry) {
      case TimerPresetEntry(:final timer):
        if (timer.name == preset.name) {
          entries[index] = TimerPresetEntry(preset);
          return;
        }
      case TimerFolderEntry(:final folder):
        final timerIndex = folder.timers.indexWhere(
          (timer) => timer.name == preset.name,
        );
        if (timerIndex != -1) {
          final timers = List<MeditationTimerPreset>.of(folder.timers);
          timers[timerIndex] = preset;
          entries[index] = TimerFolderEntry(folder.withTimers(timers));
          return;
        }
    }
  }
}

void _replacePranayamaPresetByName(
  List<PranayamaBrowserEntry> entries,
  PranayamaPreset replacement,
) {
  for (var index = 0; index < entries.length; index += 1) {
    final entry = entries[index];
    switch (entry) {
      case PranayamaPresetEntry(preset: final existingPreset):
        if (existingPreset.name == replacement.name) {
          entries[index] = PranayamaPresetEntry(replacement);
          return;
        }
      case PranayamaFolderEntry(:final folder):
        final presetIndex = folder.presets.indexWhere(
          (folderPreset) => folderPreset.name == replacement.name,
        );
        if (presetIndex != -1) {
          final presets = List<PranayamaPreset>.of(folder.presets);
          presets[presetIndex] = replacement;
          entries[index] = PranayamaFolderEntry(folder.withPresets(presets));
          return;
        }
    }
  }
}

void _insertTimerPresetInFolder(
  List<TimerBrowserEntry> entries,
  ({MeditationTimerPreset preset, String? folderName}) importedTimer,
) {
  final folderName = importedTimer.folderName;
  if (folderName == null) {
    entries.add(TimerPresetEntry(importedTimer.preset));
    return;
  }

  for (var index = 0; index < entries.length; index += 1) {
    final entry = entries[index];
    if (entry is TimerFolderEntry && entry.folder.name == folderName) {
      entries[index] = TimerFolderEntry(
        entry.folder.withTimers([...entry.folder.timers, importedTimer.preset]),
      );
      return;
    }
  }

  entries.add(
    TimerFolderEntry(
      TimerFolder(name: folderName, timers: [importedTimer.preset]),
    ),
  );
}

void _insertPranayamaPresetInFolder(
  List<PranayamaBrowserEntry> entries,
  ({PranayamaPreset preset, String? folderName}) importedPreset,
) {
  final folderName = importedPreset.folderName;
  if (folderName == null) {
    entries.add(PranayamaPresetEntry(importedPreset.preset));
    return;
  }

  for (var index = 0; index < entries.length; index += 1) {
    final entry = entries[index];
    if (entry is PranayamaFolderEntry && entry.folder.name == folderName) {
      entries[index] = PranayamaFolderEntry(
        entry.folder.withPresets([
          ...entry.folder.presets,
          importedPreset.preset,
        ]),
      );
      return;
    }
  }

  entries.add(
    PranayamaFolderEntry(
      PranayamaFolder(name: folderName, presets: [importedPreset.preset]),
    ),
  );
}
