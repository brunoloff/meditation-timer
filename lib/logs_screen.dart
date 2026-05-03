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

  void _deleteLogEntry(MeditationLogEntry entry) {
    setState(() {
      _pendingAdditions.removeWhere((addition) => addition.id == entry.id);
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
  const _LogEntryRow({required this.entry, required this.onDelete});

  final MeditationLogEntry entry;
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
  const _LogEntryDialog();

  @override
  State<_LogEntryDialog> createState() => _LogEntryDialogState();
}

class _LogEntryDialogState extends State<_LogEntryDialog> {
  final TextEditingController _durationController = TextEditingController(
    text: '0:20:0',
  );
  final TextEditingController _presetController = TextEditingController();
  final TextEditingController _activityController = TextEditingController(
    text: 'Meditation',
  );
  DateTime _startedAt = DateTime.now();
  String? _errorText;

  @override
  void dispose() {
    _durationController.dispose();
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

  void _submit() {
    final duration = _parseLogDuration(_durationController.text);
    if (duration == null) {
      setState(() {
        _errorText = 'Use h:m:s duration format';
      });
      return;
    }

    Navigator.of(context).pop(
      MeditationLogEntry(
        id: _newLogId(),
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
      title: const Text('Add log entry'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorText != null) ...[
              Text(
                _errorText!,
                style: const TextStyle(color: Color(0xFFE06A6A)),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const ValueKey('log-started-at-date-button'),
                onPressed: _pickStartedAtDate,
                child: Text(_formatCsvDateTime(_startedAt)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('log-duration-field'),
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration'),
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
          child: const Text('Add'),
        ),
      ],
    );
  }
}

Duration? _parseLogDuration(String value) {
  final parts = value.split(':');
  if (parts.length != 3) {
    return null;
  }

  final hours = int.tryParse(parts[0].trim());
  final minutes = int.tryParse(parts[1].trim());
  final seconds = int.tryParse(parts[2].trim());

  if (hours == null ||
      minutes == null ||
      seconds == null ||
      hours < 0 ||
      minutes < 0 ||
      seconds < 0) {
    return null;
  }

  return Duration(hours: hours, minutes: minutes, seconds: seconds);
}

String _formatDateOnly(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month/$day/${date.year}';
}
