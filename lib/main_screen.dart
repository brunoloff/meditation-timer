part of 'main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.openBackgroundSetupGuide});

  final Future<bool> Function()? openBackgroundSetupGuide;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeTab _selectedTab = HomeTab.timers;
  bool _recentTimersCollapsed = false;
  bool _recentPranayamaCollapsed = false;
  bool _soundEnabled = true;
  bool _turnScreenOnNearAudio = true;
  bool _isEditingTimerPositions = false;
  bool _isEditingPranayamaPositions = false;
  int _recentTimerLimit = _defaultRecentTimerLimit;
  AudioPlayer? _settingsAudioPlayer;
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
  int _timerEntriesSaveGeneration = 0;
  int _pranayamaEntriesSaveGeneration = 0;
  int _statsRefreshKey = 0;
  PranayamaPreset? _activePranayamaPreset;
  DateTime? _pranayamaStartedAt;
  Duration _pranayamaElapsedBeforePause = Duration.zero;
  bool _isPranayamaPaused = false;
  Timer? _pranayamaTicker;

  @override
  void initState() {
    super.initState();
    _loadHomeSettings();
  }

  @override
  void dispose() {
    _pranayamaTicker?.cancel();
    _settingsAudioPlayer?.dispose();
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
    setState(() {
      _soundEnabled = enabled;
    });

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

  Future<void> _setRecentTimerLimit(int limit) async {
    final nextLimit = _clampRecentTimerLimit(limit);
    setState(() {
      _recentTimerLimit = nextLimit;
      if (_recentTimerIds.length > nextLimit) {
        _recentTimerIds.removeRange(nextLimit, _recentTimerIds.length);
      }
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_recentTimerLimitKey, nextLimit);
    await preferences.setString(
      _recentTimerIdsKey,
      jsonEncode(_recentTimerIds),
    );
  }

  Future<void> _testSound() async {
    if (!_soundEnabled) {
      return;
    }

    final audioPlayer = _settingsAudioPlayer ??= AudioPlayer();
    await audioPlayer.play(AssetSource(_woodKnock.assetPath));
  }

  Future<void> _importLogsCsv() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Import meditation logs',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final bytes = result.files.single.bytes;
      if (bytes == null) {
        _showMessage('Could not read the selected CSV file.');
        return;
      }

      final importResult = await _logStore.importCsv(
        utf8.decode(bytes, allowMalformed: true),
      );
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
      final bytes = Uint8List.fromList(utf8.encode(csvText));
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Export meditation logs',
        fileName: 'breath-and-insight-logs.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );

      if (!mounted) {
        return;
      }

      if (kIsWeb || savedPath != null) {
        _showMessage('Exported meditation logs.');
      }
    } on Object {
      if (mounted) {
        _showMessage('Could not export meditation logs.');
      }
    }
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
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

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
    _recordRecentTimer(timer);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeditationSessionScreen(
          timer: timer,
          playBells: _soundEnabled,
          turnScreenOnNearAudio: _turnScreenOnNearAudio,
          logStore: _logStore,
          backgroundTimerService: _backgroundTimerService,
        ),
      ),
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
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

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
    _recordRecentPranayamaPreset(preset);
    setState(() {
      _activePranayamaPreset = preset;
      _pranayamaStartedAt = DateTime.now();
      _pranayamaElapsedBeforePause = Duration.zero;
      _isPranayamaPaused = false;
    });
    _ensurePranayamaTicker();
  }

  void _togglePranayamaPaused() {
    final preset = _activePranayamaPreset;
    if (preset == null) {
      return;
    }

    setState(() {
      if (_isPranayamaPaused) {
        _pranayamaStartedAt = DateTime.now();
        _isPranayamaPaused = false;
        _ensurePranayamaTicker();
      } else {
        _pranayamaElapsedBeforePause = _currentPranayamaElapsed;
        _pranayamaStartedAt = null;
        _isPranayamaPaused = true;
      }
    });
  }

  void _stopPranayamaSession({bool updateState = true}) {
    _pranayamaTicker?.cancel();
    _pranayamaTicker = null;

    void clearSession() {
      _activePranayamaPreset = null;
      _pranayamaStartedAt = null;
      _pranayamaElapsedBeforePause = Duration.zero;
      _isPranayamaPaused = false;
    }

    if (updateState) {
      setState(clearSession);
    } else {
      clearSession();
    }
  }

  void _ensurePranayamaTicker() {
    _pranayamaTicker ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) {
        return;
      }

      final preset = _activePranayamaPreset;
      if (preset == null || _isPranayamaPaused) {
        return;
      }

      final elapsed = _currentPranayamaElapsed;
      if (preset.duration != null && elapsed >= preset.duration!) {
        _stopPranayamaSession();
        return;
      }

      setState(() {});
    });
  }

  Duration get _currentPranayamaElapsed {
    if (_isPranayamaPaused || _pranayamaStartedAt == null) {
      return _pranayamaElapsedBeforePause;
    }

    return _pranayamaElapsedBeforePause +
        DateTime.now().difference(_pranayamaStartedAt!);
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
                  child: switch (_selectedTab) {
                    HomeTab.timers => _TimersTab(
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
                      recentTimerLimit: _recentTimerLimit,
                      onSoundEnabledChanged: (enabled) =>
                          _setSoundEnabled(enabled: enabled),
                      onTurnScreenOnNearAudioChanged: (enabled) =>
                          _setTurnScreenOnNearAudio(enabled: enabled),
                      onRecentTimerLimitChanged: _setRecentTimerLimit,
                      onTestSound: _testSound,
                      onPrepareBackgroundTimerSupport:
                          _prepareBackgroundTimerSupport,
                      onOpenBackgroundSetupGuide: _openBackgroundSetupHelp,
                      onImportLogs: _importLogsCsv,
                      onExportLogs: _exportLogsCsv,
                      onPurgeLogs: _confirmPurgeLogs,
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
