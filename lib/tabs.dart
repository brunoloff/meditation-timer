part of 'main.dart';

class _TimersTab extends StatelessWidget {
  const _TimersTab({
    required this.recentTimersCollapsed,
    required this.recentTimers,
    required this.isEditingTimerPositions,
    required this.expandedFolders,
    required this.timerEntries,
    required this.onToggleRecentTimers,
    required this.onAddTimer,
    required this.onAddFolder,
    required this.onToggleTimerPositionEditing,
    required this.onEditTimer,
    required this.onDeleteTimer,
    required this.onEditFolderTitle,
    required this.onDeleteFolder,
    required this.onToggleFolder,
    required this.onReorderTimerEntry,
    required this.onStartTimer,
  });

  final bool recentTimersCollapsed;
  final List<MeditationTimerPreset> recentTimers;
  final bool isEditingTimerPositions;
  final Set<String> expandedFolders;
  final List<TimerBrowserEntry> timerEntries;
  final VoidCallback onToggleRecentTimers;
  final VoidCallback onAddTimer;
  final VoidCallback onAddFolder;
  final VoidCallback onToggleTimerPositionEditing;
  final ValueChanged<MeditationTimerPreset> onEditTimer;
  final ValueChanged<MeditationTimerPreset> onDeleteTimer;
  final ValueChanged<TimerFolder> onEditFolderTitle;
  final ValueChanged<TimerFolder> onDeleteFolder;
  final ValueChanged<String> onToggleFolder;
  final ReorderCallback onReorderTimerEntry;
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
                    if (recentTimers.isEmpty)
                      const _EmptyRecentTimersMessage()
                    else
                      for (final timer in recentTimers)
                        _TimerRow(
                          timer: timer,
                          onTap: () => onStartTimer(timer),
                          keySuffix: 'recent',
                        ),
                  ],
                ),
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Timers',
          actions: [
            _HeaderAction(
              key: const ValueKey('add-timer-button'),
              tooltip: 'Add timer',
              icon: const Icon(Icons.add_rounded),
              onPressed: onAddTimer,
            ),
            _HeaderAction(
              key: const ValueKey('add-folder-button'),
              tooltip: 'Add folder',
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: onAddFolder,
            ),
            _HeaderAction(
              key: const ValueKey('edit-timer-positions-button'),
              tooltip: isEditingTimerPositions ? 'Finish editing' : 'Edit',
              icon: Icon(
                isEditingTimerPositions
                    ? Icons.check_rounded
                    : Icons.edit_outlined,
              ),
              onPressed: onToggleTimerPositionEditing,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isEditingTimerPositions)
          _EditableTimerBrowser(
            entries: timerEntries,
            onReorder: onReorderTimerEntry,
            onEditTimer: onEditTimer,
            onDeleteTimer: onDeleteTimer,
            onEditFolderTitle: onEditFolderTitle,
            onDeleteFolder: onDeleteFolder,
          )
        else
          _TimerBrowser(
            entries: timerEntries,
            expandedFolders: expandedFolders,
            onToggleFolder: onToggleFolder,
            onStartTimer: onStartTimer,
          ),
        const SizedBox(height: 420),
      ],
    );
  }
}

class _TimerBrowser extends StatelessWidget {
  const _TimerBrowser({
    required this.entries,
    required this.expandedFolders,
    required this.onToggleFolder,
    required this.onStartTimer,
  });

  final List<TimerBrowserEntry> entries;
  final Set<String> expandedFolders;
  final ValueChanged<String> onToggleFolder;
  final ValueChanged<MeditationTimerPreset> onStartTimer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [for (final entry in entries) ..._widgetsForEntry(entry)],
    );
  }

  List<Widget> _widgetsForEntry(TimerBrowserEntry entry) {
    return switch (entry) {
      TimerPresetEntry(:final timer) => [
        _TimerRow(timer: timer, onTap: () => onStartTimer(timer)),
      ],
      TimerFolderEntry(:final folder) => [
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
    };
  }
}

class _EmptyRecentTimersMessage extends StatelessWidget {
  const _EmptyRecentTimersMessage();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Text(
        'No recent timers yet',
        style: TextStyle(
          color: _mutedTextColor,
          fontSize: 14,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _EditableTimerBrowser extends StatelessWidget {
  const _EditableTimerBrowser({
    required this.entries,
    required this.onReorder,
    required this.onEditTimer,
    required this.onDeleteTimer,
    required this.onEditFolderTitle,
    required this.onDeleteFolder,
  });

  final List<TimerBrowserEntry> entries;
  final ReorderCallback onReorder;
  final ValueChanged<MeditationTimerPreset> onEditTimer;
  final ValueChanged<MeditationTimerPreset> onDeleteTimer;
  final ValueChanged<TimerFolder> onEditFolderTitle;
  final ValueChanged<TimerFolder> onDeleteFolder;

  @override
  Widget build(BuildContext context) {
    final rows = _editableRowsFor(entries);

    return ReorderableListView.builder(
      key: const ValueKey('editable-timer-browser'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      itemCount: rows.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final row = rows[index];

        return KeyedSubtree(
          key: ValueKey('editable-${row.id}'),
          child: _EditableTimerBrowserEntry(
            row: row,
            index: index,
            onEditTimer: onEditTimer,
            onDeleteTimer: onDeleteTimer,
            onEditFolderTitle: onEditFolderTitle,
            onDeleteFolder: onDeleteFolder,
          ),
        );
      },
    );
  }
}

class _EditableTimerBrowserEntry extends StatelessWidget {
  const _EditableTimerBrowserEntry({
    required this.row,
    required this.index,
    required this.onEditTimer,
    required this.onDeleteTimer,
    required this.onEditFolderTitle,
    required this.onDeleteFolder,
  });

  final _EditableTimerBrowserRow row;
  final int index;
  final ValueChanged<MeditationTimerPreset> onEditTimer;
  final ValueChanged<MeditationTimerPreset> onDeleteTimer;
  final ValueChanged<TimerFolder> onEditFolderTitle;
  final ValueChanged<TimerFolder> onDeleteFolder;

  @override
  Widget build(BuildContext context) {
    final dragHandle = ReorderableDragStartListener(
      key: ValueKey('drag-handle-${row.id}'),
      index: index,
      child: const Padding(
        padding: EdgeInsets.only(left: 12),
        child: Icon(Icons.drag_handle_rounded, color: Colors.white, size: 28),
      ),
    );

    return switch (row) {
      _EditableTimerRow(:final timer, :final folderName) => _TimerRow(
        timer: timer,
        onTap: null,
        isNested: folderName != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('edit-timer-${row.id}'),
              onPressed: () => onEditTimer(timer),
              tooltip: 'Edit timer',
              color: Colors.white,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              key: ValueKey('delete-timer-${row.id}'),
              onPressed: () => onDeleteTimer(timer),
              tooltip: 'Delete timer',
              color: const Color(0xFFE06A6A),
              icon: const Icon(Icons.delete_outline),
            ),
            dragHandle,
          ],
        ),
      ),
      _EditableFolderRow(:final folder) => _FolderRow(
        folder: folder,
        isExpanded: true,
        onTap: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('edit-folder-title-${folder.name}'),
              onPressed: () => onEditFolderTitle(folder),
              tooltip: 'Edit folder title',
              color: Colors.white,
              icon: const Icon(Icons.drive_file_rename_outline),
            ),
            IconButton(
              key: ValueKey('delete-folder-${folder.name}'),
              onPressed: folder.timers.isEmpty
                  ? () => onDeleteFolder(folder)
                  : null,
              tooltip: 'Delete folder',
              color: const Color(0xFFE06A6A),
              disabledColor: const Color(0xFF6A4444),
              icon: const Icon(Icons.delete_outline),
            ),
            dragHandle,
          ],
        ),
      ),
    };
  }
}

sealed class _EditableTimerBrowserRow {
  const _EditableTimerBrowserRow();

  String get id;
}

class _EditableTimerRow extends _EditableTimerBrowserRow {
  const _EditableTimerRow({required this.timer, this.folderName});

  final MeditationTimerPreset timer;
  final String? folderName;

  @override
  String get id => folderName == null
      ? 'timer-${timer.name}'
      : 'timer-$folderName-${timer.name}';
}

class _EditableFolderRow extends _EditableTimerBrowserRow {
  const _EditableFolderRow({required this.folder});

  final TimerFolder folder;

  @override
  String get id => 'folder-${folder.name}';
}

List<_EditableTimerBrowserRow> _editableRowsFor(
  List<TimerBrowserEntry> entries,
) {
  final rows = <_EditableTimerBrowserRow>[];

  for (final entry in entries) {
    switch (entry) {
      case TimerPresetEntry(:final timer):
        rows.add(_EditableTimerRow(timer: timer));
      case TimerFolderEntry(:final folder):
        rows.add(_EditableFolderRow(folder: folder));
        rows.addAll([
          for (final timer in folder.timers)
            _EditableTimerRow(timer: timer, folderName: folder.name),
        ]);
    }
  }

  return rows;
}

List<TimerBrowserEntry> _removeEditableRow(
  List<TimerBrowserEntry> entries,
  _EditableTimerBrowserRow row,
) {
  return switch (row) {
    _EditableTimerRow(:final timer) => [
      for (final entry in entries)
        ...switch (entry) {
          TimerPresetEntry(timer: final entryTimer)
              when entryTimer.name == timer.name =>
            const <TimerBrowserEntry>[],
          TimerPresetEntry() => [entry],
          TimerFolderEntry(:final folder) => [
            TimerFolderEntry(
              folder.withTimers([
                for (final folderTimer in folder.timers)
                  if (folderTimer.name != timer.name) folderTimer,
              ]),
            ),
          ],
        },
    ],
    _EditableFolderRow(:final folder) => [
      for (final entry in entries)
        if (entry case TimerFolderEntry(
          folder: final entryFolder,
        ) when entryFolder.name == folder.name)
          ...const <TimerBrowserEntry>[]
        else
          entry,
    ],
  };
}

List<TimerBrowserEntry> _replaceTimer(
  List<TimerBrowserEntry> entries,
  String oldTimerName,
  MeditationTimerPreset updatedTimer,
) {
  return [
    for (final entry in entries)
      switch (entry) {
        TimerPresetEntry(timer: final timer) when timer.name == oldTimerName =>
          TimerPresetEntry(updatedTimer),
        TimerPresetEntry() => entry,
        TimerFolderEntry(:final folder) => TimerFolderEntry(
          folder.withTimers([
            for (final timer in folder.timers)
              timer.name == oldTimerName ? updatedTimer : timer,
          ]),
        ),
      },
  ];
}

List<TimerBrowserEntry> _removeTimer(
  List<TimerBrowserEntry> entries,
  String timerName,
) {
  return [
    for (final entry in entries)
      ...switch (entry) {
        TimerPresetEntry(timer: final timer) when timer.name == timerName =>
          const <TimerBrowserEntry>[],
        TimerPresetEntry() => [entry],
        TimerFolderEntry(:final folder) => [
          TimerFolderEntry(
            folder.withTimers([
              for (final timer in folder.timers)
                if (timer.name != timerName) timer,
            ]),
          ),
        ],
      },
  ];
}

List<TimerBrowserEntry> _insertTimerRow(
  List<TimerBrowserEntry> entries,
  List<_EditableTimerBrowserRow> rows,
  int targetIndex,
  MeditationTimerPreset timer,
) {
  final targetFolderName = _targetFolderNameFor(rows, targetIndex);

  if (targetFolderName != null) {
    return [
      for (final entry in entries)
        switch (entry) {
          TimerPresetEntry() => entry,
          TimerFolderEntry(:final folder)
              when folder.name == targetFolderName =>
            TimerFolderEntry(
              folder.withTimers(
                _insertTimerIntoFolder(rows, targetIndex, timer),
              ),
            ),
          TimerFolderEntry() => entry,
        },
    ];
  }

  final targetTopLevelIndex = _targetTopLevelIndexFor(rows, targetIndex);
  final updatedEntries = List<TimerBrowserEntry>.of(entries);
  updatedEntries.insert(targetTopLevelIndex, TimerPresetEntry(timer));
  return updatedEntries;
}

List<MeditationTimerPreset> _insertTimerIntoFolder(
  List<_EditableTimerBrowserRow> rows,
  int targetIndex,
  MeditationTimerPreset timer,
) {
  final folderName = _targetFolderNameFor(rows, targetIndex)!;
  final existingTimers = [
    for (final row in rows)
      if (row case _EditableTimerRow(
        timer: final rowTimer,
        folderName: final rowFolderName?,
      ))
        if (rowFolderName == folderName) rowTimer,
  ];
  final targetChildIndex = rows.take(targetIndex).where((row) {
    return row is _EditableTimerRow && row.folderName == folderName;
  }).length;

  existingTimers.insert(targetChildIndex, timer);
  return existingTimers;
}

List<TimerBrowserEntry> _insertFolderRow(
  List<TimerBrowserEntry> entries,
  List<_EditableTimerBrowserRow> rows,
  int targetIndex,
  TimerFolder folder,
) {
  final targetTopLevelIndex = _targetTopLevelIndexFor(rows, targetIndex);
  final updatedEntries = List<TimerBrowserEntry>.of(entries);
  updatedEntries.insert(targetTopLevelIndex, TimerFolderEntry(folder));
  return updatedEntries;
}

String? _targetFolderNameFor(
  List<_EditableTimerBrowserRow> rows,
  int targetIndex,
) {
  if (targetIndex == 0) {
    return null;
  }

  final previousRow = rows[targetIndex - 1];
  return switch (previousRow) {
    _EditableFolderRow(:final folder) => folder.name,
    _EditableTimerRow(:final folderName) => folderName,
  };
}

int _targetTopLevelIndexFor(
  List<_EditableTimerBrowserRow> rows,
  int targetIndex,
) {
  return rows.take(targetIndex).where((row) {
    return row is _EditableFolderRow ||
        row is _EditableTimerRow && row.folderName == null;
  }).length;
}

List<Map<String, Object?>> _encodeTimerEntries(
  List<TimerBrowserEntry> entries,
) {
  return [
    for (final entry in entries)
      switch (entry) {
        TimerPresetEntry(:final timer) => {
          'type': 'timer',
          'timer': _encodeTimer(timer),
        },
        TimerFolderEntry(:final folder) => {
          'type': 'folder',
          'folder': folder.name,
          'timers': [for (final timer in folder.timers) _encodeTimer(timer)],
        },
      },
  ];
}

Map<String, Object?> _encodeTimer(MeditationTimerPreset timer) {
  return {
    'id': timer.id,
    'name': timer.name,
    'note': timer.note,
    'activity': timer.activity,
    'durationSeconds': timer.duration?.inSeconds,
    'startingBell': timer.startingBell?.assetPath,
    'endingBell': timer.endingBell?.assetPath,
    'intermediateBells': [
      for (final bell in timer.intermediateBells) _encodeIntermediateBell(bell),
    ],
  };
}

Map<String, Object?> _encodeIntermediateBell(IntermediateBell bell) {
  return {
    'startTimeSeconds': bell.startTime.inSeconds,
    'bell': bell.bell.assetPath,
    'repeatIntervalSeconds': bell.repeatInterval?.inSeconds,
  };
}

List<TimerBrowserEntry>? _decodeTimerEntries(String? encodedEntries) {
  if (encodedEntries == null) {
    return null;
  }

  try {
    final decoded = jsonDecode(encodedEntries);
    if (decoded is! List) {
      return null;
    }

    final entries = <TimerBrowserEntry>[];
    final usedTimers = <String>{};
    final usedFolders = <String>{};

    for (final item in decoded) {
      if (item is! Map<String, Object?>) {
        return null;
      }

      switch (item['type']) {
        case 'timer':
          final timer = _decodeTimer(item['timer']);
          if (timer == null || usedTimers.contains(timer.name)) {
            return null;
          }

          entries.add(TimerPresetEntry(timer));
          usedTimers.add(timer.name);
        case 'folder':
          final folderName = item['folder'];
          final encodedTimers = item['timers'];
          if (folderName is! String ||
              encodedTimers is! List ||
              usedFolders.contains(folderName)) {
            return null;
          }

          final folder = _folderByName(folderName);
          if (folder == null) {
            return null;
          }

          final timers = <MeditationTimerPreset>[];
          for (final encodedTimer in encodedTimers) {
            final timer = _decodeTimer(encodedTimer);
            if (timer == null || usedTimers.contains(timer.name)) {
              return null;
            }

            timers.add(timer);
            usedTimers.add(timer.name);
          }

          entries.add(TimerFolderEntry(folder.withTimers(timers)));
          usedFolders.add(folderName);
        default:
          return null;
      }
    }

    if (entries.isEmpty) {
      return null;
    }

    return entries;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

MeditationTimerPreset? _decodeTimer(Object? encodedTimer) {
  if (encodedTimer is String) {
    return _timerByName(encodedTimer);
  }

  if (encodedTimer is! Map<String, Object?>) {
    return null;
  }

  final name = encodedTimer['name'];
  final id = encodedTimer['id'];
  final durationSeconds = encodedTimer['durationSeconds'];
  final startingBellAssetPath = encodedTimer['startingBell'];
  final endingBellAssetPath = encodedTimer['endingBell'];
  final note = encodedTimer['note'];
  final activity = encodedTimer['activity'];
  final encodedIntermediateBells = encodedTimer['intermediateBells'];

  if (name is! String || name.trim().isEmpty) {
    return null;
  }

  if (id != null && (id is! String || id.trim().isEmpty)) {
    return null;
  }

  if (durationSeconds != null && durationSeconds is! int) {
    return null;
  }

  if (startingBellAssetPath != null && startingBellAssetPath is! String) {
    return null;
  }

  if (endingBellAssetPath != null && endingBellAssetPath is! String) {
    return null;
  }

  if (note != null && note is! String) {
    return null;
  }

  if (activity != null && activity is! String) {
    return null;
  }

  if (encodedIntermediateBells != null && encodedIntermediateBells is! List) {
    return null;
  }

  final decodedDurationSeconds = durationSeconds as int?;
  final decodedStartingBellAssetPath = startingBellAssetPath as String?;
  final decodedEndingBellAssetPath = endingBellAssetPath as String?;
  final decodedActivity = activity as String?;
  final decodedIntermediateBells = encodedIntermediateBells as List?;
  final intermediateBells = <IntermediateBell>[];
  if (decodedIntermediateBells != null) {
    for (final encodedBell in decodedIntermediateBells) {
      final bell = _decodeIntermediateBell(encodedBell);
      if (bell == null) {
        return null;
      }

      intermediateBells.add(bell);
    }
  }

  return MeditationTimerPreset(
    id: id as String? ?? _legacyTimerId(name),
    name: name,
    note: note as String? ?? '',
    activity: decodedActivity?.trim().isEmpty ?? true
        ? 'Meditation'
        : decodedActivity!,
    duration: decodedDurationSeconds == null
        ? null
        : Duration(seconds: decodedDurationSeconds),
    startingBell: decodedStartingBellAssetPath == null
        ? null
        : _bellByAssetPath(decodedStartingBellAssetPath),
    endingBell: decodedEndingBellAssetPath == null
        ? null
        : _bellByAssetPath(decodedEndingBellAssetPath),
    intermediateBells: intermediateBells,
  );
}

IntermediateBell? _decodeIntermediateBell(Object? encodedBell) {
  if (encodedBell is! Map<String, Object?>) {
    return null;
  }

  final startTimeSeconds = encodedBell['startTimeSeconds'];
  final bellAssetPath = encodedBell['bell'];
  final repeatIntervalSeconds = encodedBell['repeatIntervalSeconds'];

  if (startTimeSeconds is! int ||
      bellAssetPath is! String ||
      startTimeSeconds < 0 ||
      repeatIntervalSeconds != null && repeatIntervalSeconds is! int) {
    return null;
  }

  final bell = _bellByAssetPath(bellAssetPath);
  if (bell == null) {
    return null;
  }

  final decodedRepeatIntervalSeconds = repeatIntervalSeconds as int?;

  if (decodedRepeatIntervalSeconds != null &&
      decodedRepeatIntervalSeconds <= 0) {
    return null;
  }

  return IntermediateBell(
    startTime: Duration(seconds: startTimeSeconds),
    bell: bell,
    repeatInterval: decodedRepeatIntervalSeconds == null
        ? null
        : Duration(seconds: decodedRepeatIntervalSeconds),
  );
}

MeditationTimerPreset? _timerByName(String name) {
  for (final timer in _knownTimers) {
    if (timer.name == name) {
      return timer;
    }
  }

  return null;
}

BellSound? _bellByAssetPath(String assetPath) {
  for (final bell in _bellSounds) {
    if (bell.assetPath == assetPath) {
      return bell;
    }
  }

  return _legacyBellAssetReplacements[assetPath];
}

const _legacyBellAssetReplacements = {
  '$_bellAssetRoot/singing-bowl--long--1.mp3': _bellVeryLong,
  '$_bellAssetRoot/singing-bowl--long--2.mp3': _bowlInG,
  '$_bellAssetRoot/singing-bowl--long--3.mp3': _bowlWahwah,
  '$_bellAssetRoot/singing-bowl--long--4.mp3': _bowlGong,
  '$_bellAssetRoot/singing-bowl--very-long--1.mp3': _bowlLowAndLong,
  '$_bellAssetRoot/singing-bowl--very-long--2.mp3': _bowlLowAndLong,
};

TimerFolder? _folderByName(String name) {
  for (final folder in _knownFolders) {
    if (folder.name == name) {
      return folder;
    }
  }

  return TimerFolder(name: name, timers: const []);
}

class _StatsTab extends StatefulWidget {
  const _StatsTab({
    required this.logStore,
    required this.refreshKey,
    required this.onViewEditLogs,
  });

  final MeditationLogStore logStore;
  final int refreshKey;
  final VoidCallback onViewEditLogs;

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  _StatsPeriod _period = _StatsPeriod.days;
  bool _showDailyAverage = false;
  bool _streakDetailsExpanded = false;
  Future<List<MeditationLogEntry>>? _entriesFuture;

  @override
  void initState() {
    super.initState();
    _reloadEntries();
  }

  @override
  void didUpdateWidget(covariant _StatsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey ||
        oldWidget.logStore != widget.logStore) {
      _reloadEntries();
    }
  }

  void _reloadEntries() {
    _entriesFuture = widget.logStore.allEntries();
  }

  void _selectPeriod(_StatsPeriod period) {
    setState(() {
      _period = period;
      if (period == _StatsPeriod.days) {
        _showDailyAverage = false;
      }
    });
  }

  Future<void> _confirmRepairStreak(_StreakStats streakStats) async {
    final repairDay = streakStats.gapDay;
    final shouldRepair = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _homeSurfaceColor,
          title: const Text('Repair streak'),
          content: Text(
            'We will now repair your streak by adding a zero-minute log entry on the day ${_formatDateOnly(repairDay)}, which will cause your streak number to rise from ${streakStats.length} to ${streakStats.lengthAfterRepair}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('confirm-repair-streak-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (shouldRepair != true) {
      return;
    }

    await widget.logStore.append(
      MeditationLogEntry(
        id: 'streak-repair-${repairDay.toIso8601String()}',
        startedAt: DateTime(repairDay.year, repairDay.month, repairDay.day, 12),
        duration: Duration.zero,
        preset: 'Streak repair',
        activity: 'Meditation',
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _reloadEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MeditationLogEntry>>(
      future: _entriesFuture,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <MeditationLogEntry>[];
        final streakStats = _streakStatsBeforeToday(entries);
        final streakLength = streakStats.length;
        final allTimeDurationStats = _durationStatsForAllLoggedDays(entries);
        final buckets = _statsBucketsFor(
          entries,
          period: _period,
          showDailyAverage: _showDailyAverage,
        );

        return Column(
          key: const ValueKey('stats-tab'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  key: const ValueKey('view-edit-logs-button'),
                  onPressed: widget.onViewEditLogs,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: const Text('View and edit logs'),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _SectionHeader(title: 'Stats'),
            const SizedBox(height: 26),
            Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  streakLength.toString(),
                  key: const ValueKey('streak-length-value'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const ValueKey('streak-details-toggle'),
                    onPressed: () {
                      setState(() {
                        _streakDetailsExpanded = !_streakDetailsExpanded;
                      });
                    },
                    tooltip: _streakDetailsExpanded
                        ? 'Hide streak details'
                        : 'Show streak details',
                    color: Colors.white,
                    icon: Icon(
                      _streakDetailsExpanded
                          ? Icons.remove_rounded
                          : Icons.add_rounded,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'streak length',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _mutedTextColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            if (_streakDetailsExpanded) ...[
              const SizedBox(height: 18),
              _StreakDetailsPanel(
                stats: streakStats,
                onRepairStreak: () => _confirmRepairStreak(streakStats),
              ),
            ],
            const SizedBox(height: 32),
            _StatsPeriodSelector(
              selectedPeriod: _period,
              onSelected: _selectPeriod,
            ),
            if (_period != _StatsPeriod.days) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                key: const ValueKey('stats-per-day-checkbox'),
                value: _showDailyAverage,
                onChanged: (value) {
                  setState(() {
                    _showDailyAverage = value ?? false;
                  });
                },
                title: const Text(
                  'Per day',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    letterSpacing: 0,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Colors.white,
                checkColor: Colors.black,
              ),
            ],
            const SizedBox(height: 16),
            _StatsBarChart(
              buckets: buckets,
              period: _period,
              showDailyAverage: _showDailyAverage,
            ),
            const SizedBox(height: 28),
            _SomeStatisticsPanel(stats: allTimeDurationStats),
            const SizedBox(height: 520),
          ],
        );
      },
    );
  }
}

class _StreakDetailsPanel extends StatelessWidget {
  const _StreakDetailsPanel({
    required this.stats,
    required this.onRepairStreak,
  });

  final _StreakStats stats;
  final VoidCallback onRepairStreak;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('streak-details-panel'),
      color: const Color(0xFF19191D),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'First day before streak: ${_formatDateOnly(stats.gapDay)}',
                    key: const ValueKey('streak-gap-date'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('repair-streak-button'),
                  onPressed: onRepairStreak,
                  child: const Text('Repair streak'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _DurationStatsText(stats: stats.durationStats),
          ],
        ),
      ),
    );
  }
}

class _StreakDetailText extends StatelessWidget {
  const _StreakDetailText({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        '$label: $count',
        style: const TextStyle(
          color: _mutedTextColor,
          fontSize: 12,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SomeStatisticsPanel extends StatelessWidget {
  const _SomeStatisticsPanel({required this.stats});

  final _DurationStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('some-statistics-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Some statistics'),
        const SizedBox(height: 12),
        Material(
          color: const Color(0xFF19191D),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: _DurationStatsText(stats: stats),
          ),
        ),
      ],
    );
  }
}

class _DurationStatsText extends StatelessWidget {
  const _DurationStatsText({required this.stats});

  final _DurationStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StreakDetailText(
          label: 'Zero-minute days',
          count: stats.zeroMinuteDays,
        ),
        _StreakDetailText(
          label: '10 minutes or less',
          count: stats.upTo10MinutesDays,
        ),
        _StreakDetailText(
          label: '10-30 minutes',
          count: stats.tenTo30MinutesDays,
        ),
        _StreakDetailText(
          label: '30m-1h00m',
          count: stats.thirtyTo60MinutesDays,
        ),
        _StreakDetailText(
          label: '1h00m-2h30m',
          count: stats.oneToTwoAndHalfHoursDays,
        ),
        _StreakDetailText(
          label: '2h30m-5h',
          count: stats.twoAndHalfToFiveHoursDays,
        ),
        _StreakDetailText(
          label: '5 hours or more',
          count: stats.fiveHoursOrMoreDays,
        ),
      ],
    );
  }
}

class _DurationStats {
  const _DurationStats({
    required this.zeroMinuteDays,
    required this.upTo10MinutesDays,
    required this.tenTo30MinutesDays,
    required this.thirtyTo60MinutesDays,
    required this.oneToTwoAndHalfHoursDays,
    required this.twoAndHalfToFiveHoursDays,
    required this.fiveHoursOrMoreDays,
  });

  final int zeroMinuteDays;
  final int upTo10MinutesDays;
  final int tenTo30MinutesDays;
  final int thirtyTo60MinutesDays;
  final int oneToTwoAndHalfHoursDays;
  final int twoAndHalfToFiveHoursDays;
  final int fiveHoursOrMoreDays;
}

class _StreakStats {
  const _StreakStats({
    required this.length,
    required this.gapDay,
    required this.lengthAfterRepair,
    required this.durationStats,
  });

  final int length;
  final DateTime gapDay;
  final int lengthAfterRepair;
  final _DurationStats durationStats;

  int get zeroMinuteDays => durationStats.zeroMinuteDays;
  int get upTo10MinutesDays => durationStats.upTo10MinutesDays;
  int get tenTo30MinutesDays => durationStats.tenTo30MinutesDays;
  int get thirtyTo60MinutesDays => durationStats.thirtyTo60MinutesDays;
  int get oneToTwoAndHalfHoursDays => durationStats.oneToTwoAndHalfHoursDays;
  int get twoAndHalfToFiveHoursDays => durationStats.twoAndHalfToFiveHoursDays;
  int get fiveHoursOrMoreDays => durationStats.fiveHoursOrMoreDays;
}

enum _StatsPeriod {
  days('Days'),
  weeks('Weeks'),
  months('Months');

  const _StatsPeriod(this.label);

  final String label;
}

class _StatsBucket {
  const _StatsBucket({required this.label, required this.seconds});

  final String label;
  final double seconds;

  double get hours => seconds / Duration.secondsPerHour;
}

class _StatsPeriodSelector extends StatelessWidget {
  const _StatsPeriodSelector({
    required this.selectedPeriod,
    required this.onSelected,
  });

  final _StatsPeriod selectedPeriod;
  final ValueChanged<_StatsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('stats-period-selector'),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _dividerColor),
      ),
      child: Row(
        children: [
          for (final period in _StatsPeriod.values)
            Expanded(
              child: TextButton(
                key: ValueKey('stats-period-${period.name}'),
                onPressed: () => onSelected(period),
                style: TextButton.styleFrom(
                  backgroundColor: period == selectedPeriod
                      ? Colors.white
                      : Colors.transparent,
                  foregroundColor: period == selectedPeriod
                      ? Colors.black
                      : _mutedTextColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                child: Text(period.label),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsBarChart extends StatelessWidget {
  const _StatsBarChart({
    required this.buckets,
    required this.period,
    required this.showDailyAverage,
  });

  final List<_StatsBucket> buckets;
  final _StatsPeriod period;
  final bool showDailyAverage;

  @override
  Widget build(BuildContext context) {
    final maxHours = buckets.fold<double>(
      0,
      (maxValue, bucket) => bucket.hours > maxValue ? bucket.hours : maxValue,
    );
    final chartMaxY = _niceChartMax(maxHours);
    final chartInterval = _niceChartInterval(chartMaxY);

    return Material(
      key: const ValueKey('practice-bar-chart'),
      color: const Color(0xFF19191D),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _practiceChartTitle(
                period: period,
                showDailyAverage: showDailyAverage,
              ),
              key: const ValueKey('practice-chart-title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = _barWidthForChartWidth(
                  constraints.maxWidth,
                  buckets.length,
                );

                return SizedBox(
                  height: 270,
                  child: BarChart(
                    BarChartData(
                      minY: 0,
                      maxY: chartMaxY,
                      alignment: BarChartAlignment.spaceEvenly,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: chartInterval,
                        getDrawingHorizontalLine: (_) {
                          return const FlLine(
                            color: _dividerColor,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: const Border(
                          left: BorderSide(color: _dividerColor),
                          bottom: BorderSide(color: _dividerColor),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          axisNameWidget: const Text(
                            '# of hours',
                            style: TextStyle(
                              color: _mutedTextColor,
                              fontSize: 11,
                              letterSpacing: 0,
                            ),
                          ),
                          axisNameSize: 24,
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 38,
                            interval: chartInterval,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                meta: meta,
                                space: 6,
                                child: Text(
                                  _formatAxisHours(value),
                                  style: const TextStyle(
                                    color: _mutedTextColor,
                                    fontSize: 10,
                                    letterSpacing: 0,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          axisNameWidget: Text(
                            _xAxisLabel(period),
                            style: const TextStyle(
                              color: _mutedTextColor,
                              fontSize: 11,
                              letterSpacing: 0,
                            ),
                          ),
                          axisNameSize: 24,
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= buckets.length) {
                                return const SizedBox.shrink();
                              }

                              return SideTitleWidget(
                                meta: meta,
                                space: 8,
                                child: Text(
                                  buckets[index].label,
                                  style: const TextStyle(
                                    color: _mutedTextColor,
                                    fontSize: 10,
                                    letterSpacing: 0,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.white,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final bucket = buckets[group.x.toInt()];
                            return BarTooltipItem(
                              '${bucket.label}\n${_formatPracticeHours(bucket.seconds)}',
                              const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            );
                          },
                        ),
                      ),
                      barGroups: [
                        for (var index = 0; index < buckets.length; index += 1)
                          BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: buckets[index].hours,
                                width: barWidth,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                                color: buckets[index].seconds > 0
                                    ? const Color(0xFF78BFA7)
                                    : const Color(0xFF2A2A2E),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

_StreakStats _streakStatsBeforeToday(List<MeditationLogEntry> entries) {
  final durationSecondsByDay = <int, int>{};
  for (final entry in entries) {
    final dayNumber = _dayNumber(entry.startedAt);
    durationSecondsByDay[dayNumber] =
        (durationSecondsByDay[dayNumber] ?? 0) + entry.duration.inSeconds;
  }

  var cursor = _dayNumber(DateTime.now()) - 1;
  var streakLength = 0;
  final streakDaySeconds = <int>[];

  while (durationSecondsByDay.containsKey(cursor)) {
    streakLength += 1;
    streakDaySeconds.add(durationSecondsByDay[cursor] ?? 0);
    cursor -= 1;
  }

  final gapDayNumber = cursor;
  var repairPreviewCursor = gapDayNumber - 1;
  var earlierStreakLength = 0;
  while (durationSecondsByDay.containsKey(repairPreviewCursor)) {
    earlierStreakLength += 1;
    repairPreviewCursor -= 1;
  }

  return _StreakStats(
    length: streakLength,
    gapDay: _dateFromDayNumber(gapDayNumber),
    lengthAfterRepair: streakLength + 1 + earlierStreakLength,
    durationStats: _durationStatsForSeconds(streakDaySeconds),
  );
}

_DurationStats _durationStatsForAllLoggedDays(
  List<MeditationLogEntry> entries,
) {
  final durationSecondsByDay = <int, int>{};
  for (final entry in entries) {
    final dayNumber = _dayNumber(entry.startedAt);
    durationSecondsByDay[dayNumber] =
        (durationSecondsByDay[dayNumber] ?? 0) + entry.duration.inSeconds;
  }

  return _durationStatsForSeconds(durationSecondsByDay.values);
}

_DurationStats _durationStatsForSeconds(Iterable<int> dayDurationsSeconds) {
  var zeroMinuteDays = 0;
  var upTo10MinutesDays = 0;
  var tenTo30MinutesDays = 0;
  var thirtyTo60MinutesDays = 0;
  var oneToTwoAndHalfHoursDays = 0;
  var twoAndHalfToFiveHoursDays = 0;
  var fiveHoursOrMoreDays = 0;

  for (final seconds in dayDurationsSeconds) {
    if (seconds == 0) {
      zeroMinuteDays += 1;
    } else if (seconds <= 10 * 60) {
      upTo10MinutesDays += 1;
    } else if (seconds <= 30 * 60) {
      tenTo30MinutesDays += 1;
    } else if (seconds <= 60 * 60) {
      thirtyTo60MinutesDays += 1;
    } else if (seconds <= 150 * 60) {
      oneToTwoAndHalfHoursDays += 1;
    } else if (seconds <= 300 * 60) {
      twoAndHalfToFiveHoursDays += 1;
    } else {
      fiveHoursOrMoreDays += 1;
    }
  }

  return _DurationStats(
    zeroMinuteDays: zeroMinuteDays,
    upTo10MinutesDays: upTo10MinutesDays,
    tenTo30MinutesDays: tenTo30MinutesDays,
    thirtyTo60MinutesDays: thirtyTo60MinutesDays,
    oneToTwoAndHalfHoursDays: oneToTwoAndHalfHoursDays,
    twoAndHalfToFiveHoursDays: twoAndHalfToFiveHoursDays,
    fiveHoursOrMoreDays: fiveHoursOrMoreDays,
  );
}

List<_StatsBucket> _statsBucketsFor(
  List<MeditationLogEntry> entries, {
  required _StatsPeriod period,
  required bool showDailyAverage,
}) {
  return switch (period) {
    _StatsPeriod.days => _dailyStatsBuckets(entries),
    _StatsPeriod.weeks => _weeklyStatsBuckets(
      entries,
      showDailyAverage: showDailyAverage,
    ),
    _StatsPeriod.months => _monthlyStatsBuckets(
      entries,
      showDailyAverage: showDailyAverage,
    ),
  };
}

List<_StatsBucket> _dailyStatsBuckets(List<MeditationLogEntry> entries) {
  const bucketCount = 14;
  final today = _dateOnly(DateTime.now());

  return [
    for (var offset = bucketCount - 1; offset >= 0; offset -= 1)
      _StatsBucket(
        label: _weekdayInitial(_calendarAddDays(today, -offset)),
        seconds: _durationSecondsForDay(
          entries,
          _calendarAddDays(today, -offset),
        ),
      ),
  ];
}

List<_StatsBucket> _weeklyStatsBuckets(
  List<MeditationLogEntry> entries, {
  required bool showDailyAverage,
}) {
  const bucketCount = 12;
  final currentWeekStart = _weekStart(DateTime.now());

  return [
    for (var offset = bucketCount - 1; offset >= 0; offset -= 1)
      _weeklyBucket(
        entries,
        _calendarAddDays(currentWeekStart, -offset * 7),
        showDailyAverage: showDailyAverage,
      ),
  ];
}

_StatsBucket _weeklyBucket(
  List<MeditationLogEntry> entries,
  DateTime weekStart, {
  required bool showDailyAverage,
}) {
  final weekEnd = weekStart.add(const Duration(days: 7));
  final totalSeconds = _durationSecondsWhere(
    entries,
    (entry) =>
        !entry.startedAt.isBefore(weekStart) &&
        entry.startedAt.isBefore(weekEnd),
  );

  return _StatsBucket(
    label: _weekAxisLabel(weekStart),
    seconds: showDailyAverage ? totalSeconds / 7 : totalSeconds,
  );
}

List<_StatsBucket> _monthlyStatsBuckets(
  List<MeditationLogEntry> entries, {
  required bool showDailyAverage,
}) {
  const bucketCount = 12;
  final now = DateTime.now();
  final currentMonthStart = DateTime(now.year, now.month);

  return [
    for (var offset = bucketCount - 1; offset >= 0; offset -= 1)
      _monthlyBucket(
        entries,
        DateTime(currentMonthStart.year, currentMonthStart.month - offset),
        showDailyAverage: showDailyAverage,
      ),
  ];
}

_StatsBucket _monthlyBucket(
  List<MeditationLogEntry> entries,
  DateTime monthStart, {
  required bool showDailyAverage,
}) {
  final nextMonthStart = DateTime(monthStart.year, monthStart.month + 1);
  final totalSeconds = _durationSecondsWhere(
    entries,
    (entry) =>
        !entry.startedAt.isBefore(monthStart) &&
        entry.startedAt.isBefore(nextMonthStart),
  );
  final daysInMonth = nextMonthStart.difference(monthStart).inDays;

  return _StatsBucket(
    label: _monthAbbreviation(monthStart.month),
    seconds: showDailyAverage ? totalSeconds / daysInMonth : totalSeconds,
  );
}

double _durationSecondsForDay(List<MeditationLogEntry> entries, DateTime day) {
  final start = _dateOnly(day);
  final end = start.add(const Duration(days: 1));
  return _durationSecondsWhere(
    entries,
    (entry) =>
        !entry.startedAt.isBefore(start) && entry.startedAt.isBefore(end),
  );
}

double _durationSecondsWhere(
  List<MeditationLogEntry> entries,
  bool Function(MeditationLogEntry entry) test,
) {
  return entries
      .where(test)
      .fold<double>(0, (total, entry) => total + entry.duration.inSeconds);
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

DateTime _calendarAddDays(DateTime dateTime, int days) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day + days);
}

int _dayNumber(DateTime dateTime) {
  return DateTime.utc(
    dateTime.year,
    dateTime.month,
    dateTime.day,
  ).difference(DateTime.utc(1970)).inDays;
}

DateTime _dateFromDayNumber(int dayNumber) {
  final date = DateTime.utc(1970).add(Duration(days: dayNumber));
  return DateTime(date.year, date.month, date.day);
}

DateTime _weekStart(DateTime dateTime) {
  final date = _dateOnly(dateTime);
  return _calendarAddDays(date, -(date.weekday - DateTime.monday));
}

String _weekdayInitial(DateTime dateTime) {
  return switch (dateTime.weekday) {
    DateTime.monday => 'M',
    DateTime.tuesday => 'T',
    DateTime.wednesday => 'W',
    DateTime.thursday => 'T',
    DateTime.friday => 'F',
    DateTime.saturday => 'S',
    DateTime.sunday => 'S',
    _ => '',
  };
}

String _weekAxisLabel(DateTime weekStart) {
  return _isFirstFullWeekOfMonth(weekStart)
      ? _monthAbbreviation(weekStart.month)
      : weekStart.day.toString();
}

bool _isFirstFullWeekOfMonth(DateTime weekStart) {
  final weekEnd = _calendarAddDays(weekStart, 6);
  if (weekStart.month != weekEnd.month) {
    return false;
  }

  final firstDayOfMonth = DateTime(weekStart.year, weekStart.month);
  final daysUntilFirstMonday = (DateTime.monday - firstDayOfMonth.weekday) % 7;
  final firstFullWeekStart = _calendarAddDays(
    firstDayOfMonth,
    daysUntilFirstMonday,
  );
  return _dateOnly(weekStart) == firstFullWeekStart;
}

String _monthAbbreviation(int month) {
  return const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}

String _formatPracticeHours(double seconds) {
  if (seconds <= 0) {
    return '0 min';
  }

  final minutes = (seconds / 60).round();
  if (minutes < 60) {
    return '$minutes min';
  }

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes.remainder(60);
  return remainingMinutes == 0 ? '$hours h' : '$hours h $remainingMinutes min';
}

String _practiceChartTitle({
  required _StatsPeriod period,
  required bool showDailyAverage,
}) {
  return switch ((period, showDailyAverage)) {
    (_StatsPeriod.days, _) => 'Daily practice',
    (_StatsPeriod.weeks, false) => 'Total practice per week',
    (_StatsPeriod.weeks, true) => 'Daily average per week',
    (_StatsPeriod.months, false) => 'Total practice per month',
    (_StatsPeriod.months, true) => 'Daily average per month',
  };
}

String _xAxisLabel(_StatsPeriod period) {
  return switch (period) {
    _StatsPeriod.days => 'day',
    _StatsPeriod.weeks => 'week',
    _StatsPeriod.months => 'month',
  };
}

double _niceChartMax(double maxHours) {
  if (maxHours <= 0) {
    return 1;
  }

  if (maxHours <= 1) {
    return 1;
  }

  if (maxHours <= 2) {
    return 2;
  }

  if (maxHours <= 5) {
    return 5;
  }

  if (maxHours <= 10) {
    return 10;
  }

  return (maxHours / 5).ceil() * 5;
}

double _niceChartInterval(double maxHours) {
  if (maxHours <= 1) {
    return 0.25;
  }

  if (maxHours <= 2) {
    return 0.5;
  }

  if (maxHours <= 5) {
    return 1;
  }

  if (maxHours <= 10) {
    return 2;
  }

  return 5;
}

String _formatAxisHours(double hours) {
  if (hours == hours.roundToDouble()) {
    return hours.toInt().toString();
  }

  return hours.toStringAsFixed(1);
}

double _barWidthForChartWidth(double chartWidth, int bucketCount) {
  if (bucketCount <= 0 || chartWidth <= 0) {
    return 8;
  }

  const occupiedFraction = 0.80;
  final estimatedPlotWidth = (chartWidth - 38).clamp(0, chartWidth);
  return (estimatedPlotWidth * occupiedFraction / bucketCount).clamp(8, 42);
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.soundEnabled,
    required this.turnScreenOnNearAudio,
    required this.recentTimerLimit,
    required this.onSoundEnabledChanged,
    required this.onTurnScreenOnNearAudioChanged,
    required this.onRecentTimerLimitChanged,
    required this.onTestSound,
    required this.onPrepareBackgroundTimerSupport,
    required this.onOpenBackgroundSetupGuide,
    required this.onImportLogs,
    required this.onExportLogs,
    required this.onPurgeLogs,
  });

  final bool soundEnabled;
  final bool turnScreenOnNearAudio;
  final int recentTimerLimit;
  final ValueChanged<bool> onSoundEnabledChanged;
  final ValueChanged<bool> onTurnScreenOnNearAudioChanged;
  final ValueChanged<int> onRecentTimerLimitChanged;
  final VoidCallback onTestSound;
  final VoidCallback onPrepareBackgroundTimerSupport;
  final VoidCallback onOpenBackgroundSetupGuide;
  final VoidCallback onImportLogs;
  final VoidCallback onExportLogs;
  final VoidCallback onPurgeLogs;

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
        Material(
          color: const Color(0xFF19191D),
          borderRadius: BorderRadius.circular(8),
          child: SwitchListTile(
            key: const ValueKey('turn-screen-on-near-audio-switch'),
            value: turnScreenOnNearAudio,
            onChanged: onTurnScreenOnNearAudioChanged,
            title: const Text(
              'Turn screen back on near playing audio',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            subtitle: const Text(
              'Reveal meditation screen from 10 seconds before a bell until 30 seconds after',
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
        const SizedBox(height: 28),
        const _SectionHeader(title: 'Background timers'),
        const SizedBox(height: 12),
        _SettingsActionButton(
          key: const ValueKey('prepare-background-timer-support-button'),
          onPressed: onPrepareBackgroundTimerSupport,
          icon: Icons.hourglass_bottom_rounded,
          label: 'Enable background timer support',
        ),
        const SizedBox(height: 12),
        _SettingsActionButton(
          key: const ValueKey('background-setup-guide-button'),
          onPressed: onOpenBackgroundSetupGuide,
          icon: Icons.open_in_new_rounded,
          label: 'Open background setup guide',
        ),
        const SizedBox(height: 28),
        const _SectionHeader(title: 'Recent timers'),
        const SizedBox(height: 12),
        _RecentTimerLimitControl(
          value: recentTimerLimit,
          onChanged: onRecentTimerLimitChanged,
        ),
        const SizedBox(height: 28),
        const _SectionHeader(title: 'Logs'),
        const SizedBox(height: 12),
        _SettingsActionButton(
          key: const ValueKey('import-logs-button'),
          onPressed: onImportLogs,
          icon: Icons.upload_file_outlined,
          label: 'Import logs CSV',
        ),
        const SizedBox(height: 12),
        _SettingsActionButton(
          key: const ValueKey('export-logs-button'),
          onPressed: onExportLogs,
          icon: Icons.download_outlined,
          label: 'Export logs CSV',
        ),
        const SizedBox(height: 12),
        _SettingsActionButton(
          key: const ValueKey('purge-logs-button'),
          onPressed: onPurgeLogs,
          icon: Icons.delete_forever_outlined,
          label: 'Purge all logs',
          foregroundColor: const Color(0xFFFF7A7A),
          borderColor: const Color(0xFF5E2626),
        ),
        const SizedBox(height: 660),
      ],
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.foregroundColor = Colors.white,
    this.borderColor = _dividerColor,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _RecentTimerLimitControl extends StatelessWidget {
  const _RecentTimerLimitControl({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF19191D),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Number of recent timers',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Shown at the top of the Timers tab',
                    style: TextStyle(
                      color: _mutedTextColor,
                      fontSize: 13,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('decrease-recent-timer-limit-button'),
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
              tooltip: 'Show fewer recent timers',
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              key: const ValueKey('recent-timer-limit-value'),
              width: 34,
              child: Text(
                value.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('increase-recent-timer-limit-button'),
              onPressed: value < _maxRecentTimerLimit
                  ? () => onChanged(value + 1)
                  : null,
              tooltip: 'Show more recent timers',
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.actionText,
    this.onActionPressed,
    this.actions = const [],
  });

  final String title;
  final String? actionLabel;
  final String? actionText;
  final VoidCallback? onActionPressed;
  final List<_HeaderAction> actions;

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
        for (final action in actions)
          IconButton(
            key: action.key,
            onPressed: action.onPressed,
            tooltip: action.tooltip,
            color: Colors.white,
            iconSize: 28,
            icon: action.icon,
          ),
      ],
    );
  }
}

class _HeaderAction {
  const _HeaderAction({
    required this.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final Key key;
  final String tooltip;
  final Widget icon;
  final VoidCallback onPressed;
}

class _TimerRow extends StatelessWidget {
  const _TimerRow({
    required this.timer,
    required this.onTap,
    this.isNested = false,
    this.keySuffix,
    this.trailing,
  });

  final MeditationTimerPreset timer;
  final VoidCallback? onTap;
  final bool isNested;
  final String? keySuffix;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: isNested ? 28 : 0, bottom: 10),
      child: Material(
        color: const Color(0xFF19191D),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey(
            'timer-${timer.name}-${keySuffix ?? (isNested ? 'nested' : 'root')}',
          ),
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
                trailing ??
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
    this.trailing,
  });

  final TimerFolder folder;
  final bool isExpanded;
  final VoidCallback? onTap;
  final Widget? trailing;

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
                trailing ??
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
