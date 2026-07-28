part of 'main.dart';

class TimerEditScreen extends StatefulWidget {
  const TimerEditScreen({
    super.key,
    this.timer,
    this.existingTimerNames = const <String>{},
  });

  final MeditationTimerPreset? timer;
  final Set<String> existingTimerNames;

  @override
  State<TimerEditScreen> createState() => _TimerEditScreenState();
}

class _TimerEditScreenState extends State<TimerEditScreen> {
  late String _timerName;
  late bool _isInfinite;
  late final TextEditingController _noteController;
  late final TextEditingController _activityController;
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;
  late final TextEditingController _preparationHoursController;
  late final TextEditingController _preparationMinutesController;
  late final TextEditingController _preparationSecondsController;
  late final List<_EditableIntermediateBell> _intermediateBells;
  BellSound? _startingBell;
  BellSound? _endingBell;
  String? _errorText;
  bool _isNormalizingDurationFields = false;
  bool _isNormalizingPreparationFields = false;
  bool _isEditingBells = false;
  int _nextBellId = 0;

  bool get _isCreating => widget.timer == null;

  @override
  void initState() {
    super.initState();

    final timer = widget.timer;
    _timerName = timer?.name ?? 'New timer';
    _isInfinite = timer?.isInfinite ?? false;
    _noteController = TextEditingController(text: timer?.note ?? '');
    _activityController = TextEditingController(
      text: timer?.activity ?? 'Meditation',
    );

    final duration = timer?.duration ?? const Duration(minutes: 20);
    _hoursController = TextEditingController(text: duration.inHours.toString());
    _minutesController = TextEditingController(
      text: (duration.inMinutes % 60).toString().padLeft(2, '0'),
    );
    _secondsController = TextEditingController(
      text: (duration.inSeconds % 60).toString().padLeft(2, '0'),
    );
    final preparationDuration = timer?.preparationDuration ?? Duration.zero;
    _preparationHoursController = TextEditingController(
      text: preparationDuration.inHours.toString(),
    );
    _preparationMinutesController = TextEditingController(
      text: preparationDuration.inMinutes
          .remainder(60)
          .toString()
          .padLeft(2, '0'),
    );
    _preparationSecondsController = TextEditingController(
      text: preparationDuration.inSeconds
          .remainder(60)
          .toString()
          .padLeft(2, '0'),
    );
    _startingBell = timer?.startingBell ?? _woodKnock;
    _endingBell = timer?.endingBell ?? _bellVeryLong;
    _intermediateBells = [
      for (final bell in timer?.intermediateBells ?? const <IntermediateBell>[])
        _EditableIntermediateBell(
          id: 'existing-intermediate-bell-${_nextBellId++}',
          bell: bell,
        ),
    ];
  }

  @override
  void dispose() {
    _noteController.dispose();
    _activityController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _preparationHoursController.dispose();
    _preparationMinutesController.dispose();
    _preparationSecondsController.dispose();
    super.dispose();
  }

  Future<void> _editTitle() async {
    var editedName = _timerName;
    String? errorText;
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        void submit(StateSetter setDialogState) {
          final trimmedName = editedName.trim();
          if (trimmedName.isEmpty) {
            setDialogState(() {
              errorText = 'Enter a timer title';
            });
            return;
          }

          if (widget.existingTimerNames.contains(trimmedName)) {
            setDialogState(() {
              errorText = 'A timer with this title already exists';
            });
            return;
          }

          Navigator.of(context).pop(trimmedName);
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _homeSurfaceColor,
              title: const Text('Timer title'),
              content: TextFormField(
                key: const ValueKey('timer-title-field'),
                initialValue: _timerName,
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
                  key: const ValueKey('save-timer-title-button'),
                  onPressed: () => submit(setDialogState),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newName == null) {
      return;
    }

    setState(() {
      _timerName = newName;
      _errorText = null;
    });
  }

  void _saveTimer() {
    final trimmedName = _timerName.trim();
    if (trimmedName.isEmpty) {
      setState(() {
        _errorText = 'Enter a timer title';
      });
      return;
    }

    if (widget.existingTimerNames.contains(trimmedName)) {
      setState(() {
        _errorText = 'A timer with this title already exists';
      });
      return;
    }

    final duration = _isInfinite
        ? null
        : _normalizeDurationFields(enforceMinimum: true);
    final preparationDuration = _normalizePreparationFields();

    Navigator.of(context).pop(
      MeditationTimerPreset(
        id: widget.timer?.id ?? _newTimerId(),
        name: trimmedName,
        note: _noteController.text.trim(),
        activity: _activityController.text.trim().isEmpty
            ? 'Meditation'
            : _activityController.text.trim(),
        duration: duration,
        preparationDuration: preparationDuration,
        startingBell: _startingBell,
        endingBell: _endingBell,
        intermediateBells: [for (final bell in _intermediateBells) bell.bell],
      ),
    );
  }

  void _addIntermediateBell() {
    setState(() {
      _isEditingBells = true;
      _intermediateBells.add(
        _EditableIntermediateBell(
          id: 'new-intermediate-bell-${DateTime.now().microsecondsSinceEpoch}-${_nextBellId++}',
          bell: const IntermediateBell(
            startTime: Duration(minutes: 5),
            bell: _woodKnock,
          ),
        ),
      );
    });
  }

  void _toggleIntermediateBellEditing() {
    setState(() {
      _isEditingBells = !_isEditingBells;
    });
  }

  void _updateIntermediateBell(String id, IntermediateBell bell) {
    setState(() {
      final index = _intermediateBells.indexWhere((entry) => entry.id == id);
      if (index == -1) {
        return;
      }

      _intermediateBells[index] = _EditableIntermediateBell(id: id, bell: bell);
    });
  }

  void _deleteIntermediateBell(String id) {
    setState(() {
      _intermediateBells.removeWhere((entry) => entry.id == id);
    });
  }

  void _reorderIntermediateBell(int oldIndex, int newIndex) {
    setState(() {
      final bell = _intermediateBells.removeAt(oldIndex);
      _intermediateBells.insert(newIndex, bell);
    });
  }

  Duration? _normalizeDurationFields({bool enforceMinimum = false}) {
    if (_isNormalizingDurationFields) {
      return null;
    }

    // Users may type overflow values like 90 minutes or 3600 seconds. Duration
    // does the carry for us, then the controllers are rewritten to canonical
    // hh:mm:ss fields so saved timers are always valid.
    final hours = _nonNegativeFieldValue(_hoursController);
    final minutes = _nonNegativeFieldValue(_minutesController);
    final seconds = _nonNegativeFieldValue(_secondsController);
    final duration = Duration(hours: hours, minutes: minutes, seconds: seconds);

    if (duration.inHours > 999) {
      // Past this point the duration editor becomes unwieldy; use the explicit
      // infinite state rather than preserving a huge finite value.
      setState(() {
        _isInfinite = true;
        _errorText = null;
      });
      return null;
    }

    final normalizedDuration = enforceMinimum && duration == Duration.zero
        ? const Duration(seconds: 1)
        : duration;

    if (enforceMinimum ||
        _hasBlankDurationField(
                  _hoursController,
                  _minutesController,
                  _secondsController,
                ) ==
                false &&
            (minutes >= 60 || seconds >= 60)) {
      _updateDurationFields(normalizedDuration);
    }
    return normalizedDuration;
  }

  Duration _normalizePreparationFields() {
    if (_isNormalizingPreparationFields) {
      return _durationFromFields(
        _preparationHoursController,
        _preparationMinutesController,
        _preparationSecondsController,
      );
    }

    final hours = _nonNegativeFieldValue(_preparationHoursController);
    final minutes = _nonNegativeFieldValue(_preparationMinutesController);
    final seconds = _nonNegativeFieldValue(_preparationSecondsController);
    final duration = Duration(hours: hours, minutes: minutes, seconds: seconds);
    final normalizedDuration = duration.inHours > 999
        ? const Duration(hours: 999)
        : duration;

    if (duration.inHours > 999 ||
        _hasBlankDurationField(
                  _preparationHoursController,
                  _preparationMinutesController,
                  _preparationSecondsController,
                ) ==
                false &&
            (minutes >= 60 || seconds >= 60)) {
      _updatePreparationFields(normalizedDuration);
    }

    return normalizedDuration;
  }

  Duration _durationFromFields(
    TextEditingController hoursController,
    TextEditingController minutesController,
    TextEditingController secondsController,
  ) {
    return Duration(
      hours: _nonNegativeFieldValue(hoursController),
      minutes: _nonNegativeFieldValue(minutesController),
      seconds: _nonNegativeFieldValue(secondsController),
    );
  }

  int _nonNegativeFieldValue(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim()) ?? 0;
    return value < 0 ? 0 : value;
  }

  bool _hasBlankDurationField(
    TextEditingController hoursController,
    TextEditingController minutesController,
    TextEditingController secondsController,
  ) {
    return hoursController.text.trim().isEmpty ||
        minutesController.text.trim().isEmpty ||
        secondsController.text.trim().isEmpty;
  }

  void _updateDurationFields(Duration duration) {
    _isNormalizingDurationFields = true;
    _setDurationFieldText(_hoursController, duration.inHours.toString());
    _setDurationFieldText(
      _minutesController,
      duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
    );
    _setDurationFieldText(
      _secondsController,
      duration.inSeconds.remainder(60).toString().padLeft(2, '0'),
    );
    _isNormalizingDurationFields = false;
  }

  void _updatePreparationFields(Duration duration) {
    _isNormalizingPreparationFields = true;
    _setDurationFieldText(
      _preparationHoursController,
      duration.inHours.toString(),
    );
    _setDurationFieldText(
      _preparationMinutesController,
      duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
    );
    _setDurationFieldText(
      _preparationSecondsController,
      duration.inSeconds.remainder(60).toString().padLeft(2, '0'),
    );
    _isNormalizingPreparationFields = false;
  }

  void _setDurationFieldText(TextEditingController controller, String text) {
    if (controller.text == text) {
      return;
    }

    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TimerEditTitleBar(
              title: _isCreating ? 'Create new timer' : 'Edit timer',
              onCancel: () => Navigator.of(context).pop(),
              onSave: _saveTimer,
            ),
            const Divider(height: 1, thickness: 1, color: _dividerColor),
            Expanded(
              child: ColoredBox(
                color: _homeSurfaceColor,
                child: SingleChildScrollView(
                  key: const ValueKey('timer-edit-scroll-view'),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorText != null) ...[
                        _TimerEditErrorBanner(errorText: _errorText!),
                        const SizedBox(height: 16),
                      ],
                      _TimerTitleEditor(
                        timerName: _timerName,
                        onEditTitle: _editTitle,
                      ),
                      const SizedBox(height: 16),
                      _NoteEditor(controller: _noteController),
                      const SizedBox(height: 16),
                      _ActivityEditor(controller: _activityController),
                      const SizedBox(height: 24),
                      _DurationEditor(
                        isInfinite: _isInfinite,
                        hoursController: _hoursController,
                        minutesController: _minutesController,
                        secondsController: _secondsController,
                        onDurationChanged: () {
                          _normalizeDurationFields();
                        },
                        onInfiniteChanged: (isInfinite) {
                          setState(() {
                            _isInfinite = isInfinite;
                            _errorText = null;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      _DurationEditor(
                        title: 'Preparation time',
                        fieldKeyPrefix: 'preparation',
                        isInfinite: false,
                        showInfiniteToggle: false,
                        hoursController: _preparationHoursController,
                        minutesController: _preparationMinutesController,
                        secondsController: _preparationSecondsController,
                        onDurationChanged: _normalizePreparationFields,
                        onInfiniteChanged: (_) {},
                      ),
                      const SizedBox(height: 24),
                      _BellEditor(
                        label: 'Starting bell',
                        value: _startingBell,
                        onChanged: (bell) {
                          setState(() {
                            _startingBell = bell;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _BellEditor(
                        label: 'Ending bell',
                        value: _endingBell,
                        onChanged: (bell) {
                          setState(() {
                            _endingBell = bell;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      _IntermediateBellsEditor(
                        bells: _intermediateBells,
                        isEditing: _isEditingBells,
                        onAddBell: _addIntermediateBell,
                        onToggleEditing: _toggleIntermediateBellEditing,
                        onUpdateBell: _updateIntermediateBell,
                        onDeleteBell: _deleteIntermediateBell,
                        onReorderBell: _reorderIntermediateBell,
                      ),
                      const SizedBox(height: 520),
                    ],
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

class _EditableIntermediateBell {
  const _EditableIntermediateBell({required this.id, required this.bell});

  final String id;
  final IntermediateBell bell;
}

class _TimerEditTitleBar extends StatelessWidget {
  const _TimerEditTitleBar({
    required this.title,
    required this.onCancel,
    required this.onSave,
  });

  final String title;
  final VoidCallback onCancel;
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
              key: const ValueKey('cancel-timer-edit-button'),
              onPressed: onCancel,
              tooltip: 'Cancel',
              color: Colors.white,
              icon: const Icon(Icons.close_rounded),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('save-timer-edit-button'),
              onPressed: onSave,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
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

class _TimerEditErrorBanner extends StatelessWidget {
  const _TimerEditErrorBanner({required this.errorText});

  final String errorText;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF3B1D1D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE06A6A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          errorText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _TimerTitleEditor extends StatelessWidget {
  const _TimerTitleEditor({required this.timerName, required this.onEditTitle});

  final String timerName;
  final VoidCallback onEditTitle;

  @override
  Widget build(BuildContext context) {
    return _TimerEditPanel(
      child: Row(
        children: [
          Expanded(
            child: Text(
              timerName,
              key: const ValueKey('timer-edit-title'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('edit-timer-title-button'),
            onPressed: onEditTitle,
            tooltip: 'Edit title',
            color: Colors.white,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _NoteEditor extends StatelessWidget {
  const _NoteEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _TimerEditPanel(
      child: TextField(
        key: const ValueKey('timer-note-field'),
        controller: controller,
        minLines: 1,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: 'Note',
          hintText: 'None',
          filled: true,
          fillColor: const Color(0xFF101012),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _ActivityEditor extends StatelessWidget {
  const _ActivityEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _TimerEditPanel(
      child: TextField(
        key: const ValueKey('timer-activity-field'),
        controller: controller,
        decoration: InputDecoration(
          labelText: 'Activity',
          filled: true,
          fillColor: const Color(0xFF101012),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _DurationEditor extends StatelessWidget {
  const _DurationEditor({
    required this.isInfinite,
    required this.hoursController,
    required this.minutesController,
    required this.secondsController,
    required this.onDurationChanged,
    required this.onInfiniteChanged,
    this.title = 'Duration',
    this.fieldKeyPrefix = 'duration',
    this.showInfiniteToggle = true,
    this.wrapInPanel = true,
  });

  final bool isInfinite;
  final TextEditingController hoursController;
  final TextEditingController minutesController;
  final TextEditingController secondsController;
  final VoidCallback onDurationChanged;
  final ValueChanged<bool> onInfiniteChanged;
  final String title;
  final String fieldKeyPrefix;
  final bool showInfiniteToggle;
  final bool wrapInPanel;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _DurationNumberField(
                key: ValueKey('$fieldKeyPrefix-hours-field'),
                label: 'Hours',
                controller: hoursController,
                enabled: !isInfinite,
                onChanged: onDurationChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DurationNumberField(
                key: ValueKey('$fieldKeyPrefix-minutes-field'),
                label: 'Minutes',
                controller: minutesController,
                enabled: !isInfinite,
                onChanged: onDurationChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DurationNumberField(
                key: ValueKey('$fieldKeyPrefix-seconds-field'),
                label: 'Seconds',
                controller: secondsController,
                enabled: !isInfinite,
                onChanged: onDurationChanged,
              ),
            ),
          ],
        ),
        if (showInfiniteToggle) ...[
          const SizedBox(height: 12),
          CheckboxListTile(
            key: ValueKey('$fieldKeyPrefix-infinite-checkbox'),
            value: isInfinite,
            onChanged: (value) => onInfiniteChanged(value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Infinite duration',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            activeColor: Colors.white,
            checkColor: Colors.black,
          ),
        ],
      ],
    );

    if (!wrapInPanel) {
      return content;
    }

    return _TimerEditPanel(child: content);
  }
}

class _DurationNumberField extends StatelessWidget {
  const _DurationNumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFF101012),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _BellEditor extends StatelessWidget {
  const _BellEditor({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final BellSound? value;
  final ValueChanged<BellSound?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _TimerEditPanel(
      child: _BellSelectionField(
        key: ValueKey(
          label == 'Starting bell'
              ? 'starting-bell-field'
              : 'ending-bell-field',
        ),
        label: label,
        value: value,
        allowNone: true,
        onChanged: onChanged,
      ),
    );
  }
}

class _BellSelectionField extends StatelessWidget {
  const _BellSelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.allowNone,
    required this.onChanged,
  });

  final String label;
  final BellSound? value;
  final bool allowNone;
  final ValueChanged<BellSound?> onChanged;

  Future<void> _openSelector(BuildContext context) async {
    final result = await Navigator.of(context).push<SoundSelectionResult>(
      MaterialPageRoute<SoundSelectionResult>(
        builder: (_) => SelectSoundScreen(allowNone: allowNone),
      ),
    );

    if (result != null) {
      onChanged(result.sound);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = value == null ? 'None' : value!.name;
    return Material(
      color: const Color(0xFF101012),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openSelector(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: const Color(0xFF101012),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded, color: _mutedTextColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntermediateBellsEditor extends StatelessWidget {
  const _IntermediateBellsEditor({
    required this.bells,
    required this.isEditing,
    required this.onAddBell,
    required this.onToggleEditing,
    required this.onUpdateBell,
    required this.onDeleteBell,
    required this.onReorderBell,
  });

  final List<_EditableIntermediateBell> bells;
  final bool isEditing;
  final VoidCallback onAddBell;
  final VoidCallback onToggleEditing;
  final void Function(String id, IntermediateBell bell) onUpdateBell;
  final ValueChanged<String> onDeleteBell;
  final ReorderCallback onReorderBell;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Bells',
          actions: [
            _HeaderAction(
              key: const ValueKey('add-intermediate-bell-button'),
              tooltip: 'Add bell',
              icon: const Icon(Icons.add_rounded),
              onPressed: onAddBell,
            ),
            _HeaderAction(
              key: const ValueKey('edit-intermediate-bells-button'),
              tooltip: isEditing ? 'Finish editing' : 'Edit',
              icon: Icon(isEditing ? Icons.check_rounded : Icons.edit_outlined),
              onPressed: onToggleEditing,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (bells.isEmpty)
          const _EmptyIntermediateBellRow()
        else if (isEditing)
          ReorderableListView.builder(
            key: const ValueKey('editable-intermediate-bells-list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: bells.length,
            onReorderItem: onReorderBell,
            itemBuilder: (context, index) {
              final entry = bells[index];
              return _IntermediateBellEditorRow(
                key: ValueKey(entry.id),
                id: entry.id,
                index: index,
                bell: entry.bell,
                onChanged: onUpdateBell,
                onDelete: onDeleteBell,
              );
            },
          )
        else
          for (final entry in bells)
            _IntermediateBellSummaryRow(bell: entry.bell),
      ],
    );
  }
}

class _EmptyIntermediateBellRow extends StatelessWidget {
  const _EmptyIntermediateBellRow();

  @override
  Widget build(BuildContext context) {
    return _TimerEditPanel(
      child: const Text(
        'No intermediate bells',
        style: TextStyle(
          color: _mutedTextColor,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _IntermediateBellSummaryRow extends StatelessWidget {
  const _IntermediateBellSummaryRow({required this.bell});

  final IntermediateBell bell;

  @override
  Widget build(BuildContext context) {
    final repeatText = bell.repeatInterval == null
        ? 'No repeat'
        : 'Repeats every ${_formatDuration(bell.repeatInterval!)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF19191D),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFFB7B7BC),
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bell.bell.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatClockDuration(bell.startTime)} | $repeatText',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _IntermediateBellEditorRow extends StatefulWidget {
  const _IntermediateBellEditorRow({
    super.key,
    required this.id,
    required this.index,
    required this.bell,
    required this.onChanged,
    required this.onDelete,
  });

  final String id;
  final int index;
  final IntermediateBell bell;
  final void Function(String id, IntermediateBell bell) onChanged;
  final ValueChanged<String> onDelete;

  @override
  State<_IntermediateBellEditorRow> createState() =>
      _IntermediateBellEditorRowState();
}

class _IntermediateBellEditorRowState
    extends State<_IntermediateBellEditorRow> {
  late IntermediateBell _bell;
  late final TextEditingController _startHoursController;
  late final TextEditingController _startMinutesController;
  late final TextEditingController _startSecondsController;
  late final TextEditingController _repeatHoursController;
  late final TextEditingController _repeatMinutesController;
  late final TextEditingController _repeatSecondsController;
  bool _isNormalizing = false;

  @override
  void initState() {
    super.initState();
    _bell = widget.bell;
    _startHoursController = TextEditingController();
    _startMinutesController = TextEditingController();
    _startSecondsController = TextEditingController();
    _repeatHoursController = TextEditingController();
    _repeatMinutesController = TextEditingController();
    _repeatSecondsController = TextEditingController();
    _syncControllersFromBell(widget.bell);
  }

  @override
  void didUpdateWidget(covariant _IntermediateBellEditorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bell != widget.bell) {
      _bell = widget.bell;
      _syncControllersFromBell(widget.bell);
    }
  }

  @override
  void dispose() {
    _startHoursController.dispose();
    _startMinutesController.dispose();
    _startSecondsController.dispose();
    _repeatHoursController.dispose();
    _repeatMinutesController.dispose();
    _repeatSecondsController.dispose();
    super.dispose();
  }

  void _syncControllersFromBell(IntermediateBell bell) {
    _isNormalizing = true;
    _setDurationFields(
      bell.startTime,
      _startHoursController,
      _startMinutesController,
      _startSecondsController,
    );
    _setDurationFields(
      bell.repeatInterval ?? const Duration(minutes: 5),
      _repeatHoursController,
      _repeatMinutesController,
      _repeatSecondsController,
    );
    _isNormalizing = false;
  }

  void _updateBell(IntermediateBell bell) {
    _bell = bell;
    widget.onChanged(widget.id, bell);
  }

  void _normalizeStartTime() {
    if (_isNormalizing) {
      return;
    }

    final startTime = _durationFromControllers(
      _startHoursController,
      _startMinutesController,
      _startSecondsController,
    );
    _canonicalizeDurationFieldsIfNeeded(
      startTime,
      _startHoursController,
      _startMinutesController,
      _startSecondsController,
    );
    _updateBell(_bell.copyWith(startTime: startTime));
  }

  void _normalizeRepeatInterval() {
    if (_isNormalizing || _bell.repeatInterval == null) {
      return;
    }

    final repeatInterval = _durationFromControllers(
      _repeatHoursController,
      _repeatMinutesController,
      _repeatSecondsController,
    );
    _canonicalizeDurationFieldsIfNeeded(
      repeatInterval,
      _repeatHoursController,
      _repeatMinutesController,
      _repeatSecondsController,
    );
    _updateBell(_bell.copyWith(repeatInterval: repeatInterval));
  }

  void _setRepeatEnabled(bool enabled) {
    if (!enabled) {
      _updateBell(_bell.copyWith(clearRepeatInterval: true));
      return;
    }

    final repeatInterval = _durationFromControllers(
      _repeatHoursController,
      _repeatMinutesController,
      _repeatSecondsController,
      enforceMinimum: true,
    );
    _setDurationFields(
      repeatInterval,
      _repeatHoursController,
      _repeatMinutesController,
      _repeatSecondsController,
    );
    _updateBell(_bell.copyWith(repeatInterval: repeatInterval));
  }

  Duration _durationFromControllers(
    TextEditingController hoursController,
    TextEditingController minutesController,
    TextEditingController secondsController, {
    bool enforceMinimum = false,
  }) {
    final duration = Duration(
      hours: _nonNegativeTextValue(hoursController.text),
      minutes: _nonNegativeTextValue(minutesController.text),
      seconds: _nonNegativeTextValue(secondsController.text),
    );
    return enforceMinimum && duration == Duration.zero
        ? const Duration(seconds: 1)
        : duration;
  }

  int _nonNegativeTextValue(String text) {
    final value = int.tryParse(text.trim()) ?? 0;
    return value < 0 ? 0 : value;
  }

  void _canonicalizeDurationFieldsIfNeeded(
    Duration duration,
    TextEditingController hoursController,
    TextEditingController minutesController,
    TextEditingController secondsController, {
    bool enforceMinimum = false,
  }) {
    final hasBlankField =
        hoursController.text.trim().isEmpty ||
        minutesController.text.trim().isEmpty ||
        secondsController.text.trim().isEmpty;
    final minutes = _nonNegativeTextValue(minutesController.text);
    final seconds = _nonNegativeTextValue(secondsController.text);
    if (enforceMinimum || !hasBlankField && (minutes >= 60 || seconds >= 60)) {
      _setDurationFields(
        duration,
        hoursController,
        minutesController,
        secondsController,
      );
    }
  }

  void _setDurationFields(
    Duration duration,
    TextEditingController hoursController,
    TextEditingController minutesController,
    TextEditingController secondsController,
  ) {
    _isNormalizing = true;
    _setControllerText(hoursController, duration.inHours.toString());
    _setControllerText(
      minutesController,
      duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
    );
    _setControllerText(
      secondsController,
      duration.inSeconds.remainder(60).toString().padLeft(2, '0'),
    );
    _isNormalizing = false;
  }

  void _setControllerText(TextEditingController controller, String text) {
    if (controller.text == text) {
      return;
    }

    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _TimerEditPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bell ${widget.index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('delete-intermediate-bell-${widget.id}'),
                  onPressed: () => widget.onDelete(widget.id),
                  tooltip: 'Delete bell',
                  color: const Color(0xFFE06A6A),
                  icon: const Icon(Icons.delete_outline),
                ),
                ReorderableDragStartListener(
                  key: ValueKey('drag-handle-intermediate-bell-${widget.id}'),
                  index: widget.index,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _BellSelectionField(
              key: ValueKey('intermediate-bell-sound-${widget.id}'),
              label: 'Bell',
              value: _bell.bell,
              allowNone: false,
              onChanged: (bell) {
                if (bell == null) {
                  return;
                }

                _updateBell(_bell.copyWith(bell: bell));
              },
            ),
            const SizedBox(height: 12),
            _DurationControlGroup(
              title: 'Starting time',
              fieldKeyPrefix: 'intermediate-bell-${widget.index}-start',
              hoursController: _startHoursController,
              minutesController: _startMinutesController,
              secondsController: _startSecondsController,
              enabled: true,
              onChanged: _normalizeStartTime,
            ),
            CheckboxListTile(
              key: ValueKey('intermediate-bell-repeat-${widget.id}'),
              value: _bell.repeatInterval != null,
              onChanged: (value) => _setRepeatEnabled(value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Repeat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              activeColor: Colors.white,
              checkColor: Colors.black,
            ),
            _DurationControlGroup(
              title: 'Repeat every',
              fieldKeyPrefix: 'intermediate-bell-${widget.index}-repeat',
              hoursController: _repeatHoursController,
              minutesController: _repeatMinutesController,
              secondsController: _repeatSecondsController,
              enabled: _bell.repeatInterval != null,
              onChanged: _normalizeRepeatInterval,
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationControlGroup extends StatelessWidget {
  const _DurationControlGroup({
    required this.title,
    this.fieldKeyPrefix,
    required this.hoursController,
    required this.minutesController,
    required this.secondsController,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String? fieldKeyPrefix;
  final TextEditingController hoursController;
  final TextEditingController minutesController;
  final TextEditingController secondsController;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DurationNumberField(
                key: fieldKeyPrefix == null
                    ? null
                    : ValueKey('$fieldKeyPrefix-hours-field'),
                label: 'Hours',
                controller: hoursController,
                enabled: enabled,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DurationNumberField(
                key: fieldKeyPrefix == null
                    ? null
                    : ValueKey('$fieldKeyPrefix-minutes-field'),
                label: 'Minutes',
                controller: minutesController,
                enabled: enabled,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DurationNumberField(
                key: fieldKeyPrefix == null
                    ? null
                    : ValueKey('$fieldKeyPrefix-seconds-field'),
                label: 'Seconds',
                controller: secondsController,
                enabled: enabled,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimerEditPanel extends StatelessWidget {
  const _TimerEditPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF19191D),
      borderRadius: BorderRadius.circular(8),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
