part of 'main.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({
    super.key,
    this.store = const MeditationLogStore(),
    this.initialStartDate,
    this.initialEndDate,
  });

  final MeditationLogStore store;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final List<MeditationLogEntry> _loadedEntries = [];
  final List<MeditationLogEntry> _pendingAdditions = [];
  final Set<String> _pendingDeletedIds = {};
  DateTime? _startDate;
  DateTime? _endDate;
  int _nextOffset = 0;
  int _totalCount = 0;
  bool _hasMore = false;
  bool _isLoading = false;

  bool get _hasUnsavedChanges =>
      _pendingAdditions.isNotEmpty || _pendingDeletedIds.isNotEmpty;

  bool get _hasActiveFilter => _startDate != null || _endDate != null;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loadedEntries.clear();
      _nextOffset = 0;
      _totalCount = 0;
      _hasMore = false;
    });
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await widget.store.query(
      startDate: _startDate,
      endDate: _endDate,
      offset: _nextOffset,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loadedEntries.addAll(result.entries);
      _nextOffset = result.nextOffset;
      _totalCount = result.totalCount;
      _hasMore = result.hasMore;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (!_hasUnsavedChanges) {
      return;
    }

    await widget.store.applyChanges(
      additions: _pendingAdditions,
      deletedIds: _pendingDeletedIds,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _pendingAdditions.clear();
      _pendingDeletedIds.clear();
    });
    await _reload();
  }

  Future<void> _close() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }

    final choice = await showDialog<_UnsavedLogsChoice>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _homeSurfaceColor,
          title: const Text('Unsaved edits'),
          content: const Text(
            'There are unsaved edits. Are you sure you want to close the log screen?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_UnsavedLogsChoice.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('leave-logs-without-saving-button'),
              onPressed: () => Navigator.of(
                context,
              ).pop(_UnsavedLogsChoice.leaveWithoutSaving),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE06A6A),
              ),
              child: const Text('Leave without saving'),
            ),
            TextButton(
              key: const ValueKey('save-leave-logs-button'),
              onPressed: () =>
                  Navigator.of(context).pop(_UnsavedLogsChoice.saveAndLeave),
              child: const Text('Save & Leave'),
            ),
          ],
        );
      },
    );

    if (!mounted || choice == null || choice == _UnsavedLogsChoice.cancel) {
      return;
    }

    if (choice == _UnsavedLogsChoice.saveAndLeave) {
      await _save();
      if (!mounted) {
        return;
      }
    }

    Navigator.of(context).pop();
  }

  Future<void> _openFilterDialog() async {
    var startDate = _startDate;
    var endDate = _endDate;
    final result = await showDialog<({DateTime? startDate, DateTime? endDate})>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _homeSurfaceColor,
              title: const Text('Filter logs'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DateFilterRow(
                    label: 'Starting date',
                    date: startDate,
                    onPick: () async {
                      final pickedDate = await _pickDate(startDate);
                      if (pickedDate == null) {
                        return;
                      }
                      setDialogState(() {
                        startDate = pickedDate;
                      });
                    },
                    onClear: () {
                      setDialogState(() {
                        startDate = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _DateFilterRow(
                    label: 'Ending date',
                    date: endDate,
                    onPick: () async {
                      final pickedDate = await _pickDate(endDate);
                      if (pickedDate == null) {
                        return;
                      }
                      setDialogState(() {
                        endDate = pickedDate;
                      });
                    },
                    onClear: () {
                      setDialogState(() {
                        endDate = null;
                      });
                    },
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  key: const ValueKey('disable-log-filter-button'),
                  onPressed: () {
                    Navigator.of(context).pop((startDate: null, endDate: null));
                  },
                  child: const Text('Disable filter'),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      key: const ValueKey('apply-log-filter-button'),
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop((startDate: startDate, endDate: endDate));
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      _startDate = result.startDate;
      _endDate = result.endDate;
    });
    await _reload();
  }

  Future<DateTime?> _pickDate(DateTime? initialDate) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 20),
    );
  }

  Future<void> _addLogEntry() async {
    final entry = await showDialog<MeditationLogEntry>(
      context: context,
      builder: (context) => const _LogEntryDialog(),
    );

    if (entry == null) {
      return;
    }

    setState(() {
      _pendingAdditions.insert(0, entry);
    });
  }

  Future<void> _editLogEntry(MeditationLogEntry entry) async {
    final editedEntry = await showDialog<MeditationLogEntry>(
      context: context,
      builder: (context) => _LogEntryDialog(entry: entry),
    );

    if (editedEntry == null) {
      return;
    }

    setState(() {
      final pendingIndex = _pendingAdditions.indexWhere(
        (addition) => addition.id == entry.id,
      );
      if (pendingIndex >= 0) {
        _pendingAdditions[pendingIndex] = editedEntry;
      } else {
        _pendingDeletedIds.add(entry.id);
        _pendingAdditions.insert(0, editedEntry);
      }
    });
  }

  void _deleteLogEntry(MeditationLogEntry entry) {
    setState(() {
      final pendingAdditionRemoved =
          _pendingAdditions.indexWhere((addition) => addition.id == entry.id) >=
          0;
      _pendingAdditions.removeWhere((addition) => addition.id == entry.id);
      if (pendingAdditionRemoved) {
        return;
      }

      if (!_pendingDeletedIds.remove(entry.id)) {
        _pendingDeletedIds.add(entry.id);
      }
    });
  }

  List<MeditationLogEntry> get _visibleEntries {
    return [
      for (final entry in _pendingAdditions)
        if (_matchesFilter(entry)) entry,
      for (final entry in _loadedEntries)
        if (!_pendingDeletedIds.contains(entry.id)) entry,
    ];
  }

  bool _matchesFilter(MeditationLogEntry entry) {
    return _filterEntries(
      [entry],
      startDate: _startDate,
      endDate: _endDate,
    ).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final visibleEntries = _visibleEntries;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _LogsTitleBar(
              hasActiveFilter: _hasActiveFilter,
              hasUnsavedChanges: _hasUnsavedChanges,
              onClose: _close,
              onFilter: _openFilterDialog,
              onSave: _save,
            ),
            const Divider(height: 1, thickness: 1, color: _dividerColor),
            Expanded(
              child: ColoredBox(
                color: _homeSurfaceColor,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${visibleEntries.length} shown of $_totalCount saved',
                              style: const TextStyle(
                                color: _mutedTextColor,
                                fontSize: 14,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('add-log-entry-button'),
                            onPressed: _addLogEntry,
                            tooltip: 'Add log entry',
                            color: Colors.white,
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        key: const ValueKey('logs-list'),
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: visibleEntries.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == visibleEntries.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                height: 52,
                                child: OutlinedButton(
                                  key: const ValueKey('load-more-logs-button'),
                                  onPressed: _isLoading ? null : _loadNextPage,
                                  child: Text(
                                    _isLoading ? 'Loading...' : 'Load more',
                                  ),
                                ),
                              ),
                            );
                          }

                          final entry = visibleEntries[index];
                          return _LogEntryRow(
                            entry: entry,
                            onEdit: () => _editLogEntry(entry),
                            onDelete: () => _deleteLogEntry(entry),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogsTitleBar extends StatelessWidget {
  const _LogsTitleBar({
    required this.hasActiveFilter,
    required this.hasUnsavedChanges,
    required this.onClose,
    required this.onFilter,
    required this.onSave,
  });

  final bool hasActiveFilter;
  final bool hasUnsavedChanges;
  final VoidCallback onClose;
  final VoidCallback onFilter;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('close-logs-button'),
              onPressed: onClose,
              tooltip: 'Close',
              color: Colors.white,
              icon: const Icon(Icons.close_rounded),
            ),
            Expanded(
              child: Text(
                'View and Edit Logs',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('filter-logs-button'),
              onPressed: onFilter,
              tooltip: 'Filter',
              color: hasActiveFilter ? const Color(0xFF70D878) : Colors.white,
              icon: const Icon(Icons.filter_alt_outlined),
            ),
            TextButton(
              key: const ValueKey('save-logs-button'),
              onPressed: hasUnsavedChanges ? onSave : null,
              style: TextButton.styleFrom(
                foregroundColor: hasUnsavedChanges
                    ? const Color(0xFF70D878)
                    : _mutedTextColor,
                disabledForegroundColor: _mutedTextColor,
                textStyle: TextStyle(
                  fontWeight: hasUnsavedChanges
                      ? FontWeight.w700
                      : FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _UnsavedLogsChoice { cancel, saveAndLeave, leaveWithoutSaving }

class _DateFilterRow extends StatelessWidget {
  const _DateFilterRow({
    required this.label,
    required this.date,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onPick,
            child: Text(
              date == null ? label : '$label: ${_formatDateOnly(date!)}',
            ),
          ),
        ),
        IconButton(
          onPressed: onClear,
          tooltip: 'Clear $label',
          icon: const Icon(Icons.clear_rounded),
        ),
      ],
    );
  }
}

class _LogEntryRow extends StatelessWidget {
  const _LogEntryRow({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final MeditationLogEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF19191D),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatCsvDateTime(entry.startedAt),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatCsvDuration(entry.duration)} | ${entry.preset.isEmpty ? 'No preset' : entry.preset} | ${entry.activity}',
                      style: const TextStyle(
                        color: _mutedTextColor,
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('edit-log-${entry.id}'),
                onPressed: onEdit,
                tooltip: 'Edit log',
                color: Colors.white,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: ValueKey('delete-log-${entry.id}'),
                onPressed: onDelete,
                tooltip: 'Delete log',
                color: const Color(0xFFE06A6A),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogEntryDialog extends StatefulWidget {
  const _LogEntryDialog({this.entry});

  final MeditationLogEntry? entry;

  @override
  State<_LogEntryDialog> createState() => _LogEntryDialogState();
}

class _LogEntryDialogState extends State<_LogEntryDialog> {
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;
  late final TextEditingController _presetController;
  late final TextEditingController _activityController;
  late DateTime _startedAt;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    final duration = entry?.duration ?? const Duration(minutes: 20);
    _startedAt = entry?.startedAt ?? DateTime.now();
    _hoursController = TextEditingController(text: duration.inHours.toString());
    _minutesController = TextEditingController(
      text: duration.inMinutes.remainder(60).toString(),
    );
    _secondsController = TextEditingController(
      text: duration.inSeconds.remainder(60).toString(),
    );
    _presetController = TextEditingController(text: entry?.preset ?? '');
    _activityController = TextEditingController(
      text: entry?.activity.trim().isEmpty ?? true
          ? 'Meditation'
          : entry!.activity,
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _presetController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  Future<void> _pickStartedAtDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 20),
    );
    if (pickedDate == null) {
      return;
    }

    setState(() {
      _startedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        _startedAt.hour,
        _startedAt.minute,
        _startedAt.second,
      );
    });
  }

  Future<void> _pickStartedAtTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
    );
    if (pickedTime == null) {
      return;
    }

    setState(() {
      _startedAt = DateTime(
        _startedAt.year,
        _startedAt.month,
        _startedAt.day,
        pickedTime.hour,
        pickedTime.minute,
        _startedAt.second,
      );
    });
  }

  Duration _durationFromFields() {
    final hours = _nonNegativeIntFromController(_hoursController);
    final minutes = _nonNegativeIntFromController(_minutesController);
    final seconds = _nonNegativeIntFromController(_secondsController);
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  void _normalizeDurationFields() {
    final duration = _durationFromFields();
    _hoursController.text = duration.inHours.toString();
    _minutesController.text = duration.inMinutes.remainder(60).toString();
    _secondsController.text = duration.inSeconds.remainder(60).toString();
  }

  void _submit() {
    final duration = _durationFromFields();

    Navigator.of(context).pop(
      MeditationLogEntry(
        id: widget.entry?.id ?? _newLogId(),
        startedAt: _startedAt,
        duration: duration,
        preset: _presetController.text.trim(),
        activity: _activityController.text.trim().isEmpty
            ? 'Meditation'
            : _activityController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _homeSurfaceColor,
      title: Text(_isEditing ? 'Edit log entry' : 'Add log entry'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Started at',
              style: TextStyle(
                color: _mutedTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('log-started-at-date-button'),
                    onPressed: _pickStartedAtDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(_formatDateOnly(_startedAt)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('log-started-at-time-button'),
                    onPressed: _pickStartedAtTime,
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(_formatTimeOnly(_startedAt)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Duration',
              style: TextStyle(
                color: _mutedTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _LogDurationField(
                    keyName: 'log-duration-hours-field',
                    label: 'Hours',
                    controller: _hoursController,
                    onEditingComplete: _normalizeDurationFields,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LogDurationField(
                    keyName: 'log-duration-minutes-field',
                    label: 'Minutes',
                    controller: _minutesController,
                    onEditingComplete: _normalizeDurationFields,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LogDurationField(
                    keyName: 'log-duration-seconds-field',
                    label: 'Seconds',
                    controller: _secondsController,
                    onEditingComplete: _normalizeDurationFields,
                  ),
                ),
              ],
            ),
            TextField(
              key: const ValueKey('log-preset-field'),
              controller: _presetController,
              decoration: const InputDecoration(labelText: 'Preset'),
            ),
            TextField(
              key: const ValueKey('log-activity-field'),
              controller: _activityController,
              decoration: const InputDecoration(labelText: 'Activity'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('confirm-add-log-button'),
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _LogDurationField extends StatelessWidget {
  const _LogDurationField({
    required this.keyName,
    required this.label,
    required this.controller,
    required this.onEditingComplete,
  });

  final String keyName;
  final String label;
  final TextEditingController controller;
  final VoidCallback onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey(keyName),
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      onEditingComplete: onEditingComplete,
      decoration: InputDecoration(labelText: label),
    );
  }
}

int _nonNegativeIntFromController(TextEditingController controller) {
  final value = int.tryParse(controller.text.trim()) ?? 0;
  return value < 0 ? 0 : value;
}

String _formatDateOnly(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month/$day/${date.year}';
}

String _formatTimeOnly(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
