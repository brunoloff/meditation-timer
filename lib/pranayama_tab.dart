part of 'main.dart';

class _PranayamaTab extends StatelessWidget {
  const _PranayamaTab({
    required this.recentPresetsCollapsed,
    required this.recentPresets,
    required this.isEditingPresetPositions,
    required this.expandedFolders,
    required this.presetEntries,
    required this.activePreset,
    required this.elapsed,
    required this.isPaused,
    required this.onToggleRecentPresets,
    required this.onAddPreset,
    required this.onAddFolder,
    required this.onTogglePresetPositionEditing,
    required this.onEditPreset,
    required this.onDeletePreset,
    required this.onEditFolderTitle,
    required this.onDeleteFolder,
    required this.onToggleFolder,
    required this.onReorderPresetEntry,
    required this.onStartPreset,
    required this.onTogglePause,
    required this.onStop,
  });

  final bool recentPresetsCollapsed;
  final List<PranayamaPreset> recentPresets;
  final bool isEditingPresetPositions;
  final Set<String> expandedFolders;
  final List<PranayamaBrowserEntry> presetEntries;
  final PranayamaPreset? activePreset;
  final Duration elapsed;
  final bool isPaused;
  final VoidCallback onToggleRecentPresets;
  final VoidCallback onAddPreset;
  final VoidCallback onAddFolder;
  final VoidCallback onTogglePresetPositionEditing;
  final ValueChanged<PranayamaPreset> onEditPreset;
  final ValueChanged<PranayamaPreset> onDeletePreset;
  final ValueChanged<PranayamaFolder> onEditFolderTitle;
  final ValueChanged<PranayamaFolder> onDeleteFolder;
  final ValueChanged<String> onToggleFolder;
  final ReorderCallback onReorderPresetEntry;
  final ValueChanged<PranayamaPreset> onStartPreset;
  final VoidCallback onTogglePause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('pranayama-tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PranayamaGuidePanel(
          preset: activePreset,
          elapsed: elapsed,
          isPaused: isPaused,
          onTogglePause: onTogglePause,
          onStop: onStop,
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Recent presets',
          actionLabel: recentPresetsCollapsed ? 'Expand' : 'Minimize',
          actionText: recentPresetsCollapsed ? '+' : '-',
          onActionPressed: onToggleRecentPresets,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: recentPresetsCollapsed
              ? const SizedBox(
                  key: ValueKey('recent-pranayama-presets-collapsed'),
                  height: 8,
                )
              : Column(
                  key: const ValueKey('recent-pranayama-presets-expanded'),
                  children: [
                    const SizedBox(height: 12),
                    if (recentPresets.isEmpty)
                      const _EmptyPranayamaRecentPresetsMessage()
                    else
                      for (final preset in recentPresets)
                        _PranayamaPresetRow(
                          preset: preset,
                          onTap: () => onStartPreset(preset),
                          keySuffix: 'recent',
                        ),
                  ],
                ),
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Presets',
          actions: [
            _HeaderAction(
              key: const ValueKey('add-pranayama-preset-button'),
              tooltip: 'Add preset',
              icon: const Icon(Icons.add_rounded),
              onPressed: onAddPreset,
            ),
            _HeaderAction(
              key: const ValueKey('add-pranayama-folder-button'),
              tooltip: 'Add folder',
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: onAddFolder,
            ),
            _HeaderAction(
              key: const ValueKey('edit-pranayama-positions-button'),
              tooltip: isEditingPresetPositions ? 'Finish editing' : 'Edit',
              icon: Icon(
                isEditingPresetPositions
                    ? Icons.check_rounded
                    : Icons.edit_outlined,
              ),
              onPressed: onTogglePresetPositionEditing,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isEditingPresetPositions)
          _EditablePranayamaBrowser(
            entries: presetEntries,
            onReorder: onReorderPresetEntry,
            onEditPreset: onEditPreset,
            onDeletePreset: onDeletePreset,
            onEditFolderTitle: onEditFolderTitle,
            onDeleteFolder: onDeleteFolder,
          )
        else
          _PranayamaBrowser(
            entries: presetEntries,
            expandedFolders: expandedFolders,
            onToggleFolder: onToggleFolder,
            onStartPreset: onStartPreset,
          ),
        const SizedBox(height: 420),
      ],
    );
  }
}

class _PranayamaGuidePanel extends StatelessWidget {
  const _PranayamaGuidePanel({
    required this.preset,
    required this.elapsed,
    required this.isPaused,
    required this.onTogglePause,
    required this.onStop,
  });

  final PranayamaPreset? preset;
  final Duration elapsed;
  final bool isPaused;
  final VoidCallback onTogglePause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final phase = preset == null
        ? const _PranayamaPhaseSnapshot(
            label: 'Ready',
            progress: 0,
            breathCount: 0,
            cycleProgress: 0,
          )
        : _phaseSnapshotForPranayama(preset!, elapsed);
    final activeSegment = preset == null
        ? null
        : _pranayamaSegmentAtElapsed(preset!, elapsed).segment;
    final activeCycleDuration = activeSegment?.cycleDuration ?? Duration.zero;
    final bpm = preset == null || activeCycleDuration == Duration.zero
        ? 0.0
        : 60 / activeCycleDuration.inMilliseconds * 1000;

    return Material(
      color: const Color(0xFF13201F),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PranayamaWavePainter(
                      preset: preset,
                      elapsed: elapsed,
                      isActive: preset != null,
                    ),
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 20,
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Color(0xFFBFDAD7),
                      fontSize: 15,
                      fontFeatures: [FontFeature.tabularFigures()],
                      letterSpacing: 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Clock: ${_formatTimerDisplay(elapsed)}'),
                        Text('Breaths: ${phase.breathCount}'),
                        Text('BPM: ${bpm.toStringAsFixed(1)}'),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    isPaused && preset != null ? 'Paused' : phase.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF75D4C5)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 8,
                        ),
                        child: Text(
                          preset?.name ?? 'Choose a preset',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (activeSegment != null)
                  _PranayamaTimingTable(segment: activeSegment),
                if (preset != null) const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('toggle-pranayama-button'),
                        onPressed: preset == null ? null : onTogglePause,
                        icon: Icon(
                          isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                        label: Text(isPaused ? 'Resume' : 'Pause'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('stop-pranayama-button'),
                        onPressed: preset == null ? null : onStop,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Stop'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PranayamaTimingTable extends StatelessWidget {
  const _PranayamaTimingTable({required this.segment});

  final PranayamaSegment segment;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: _TimingHeader('Inhale')),
            Expanded(child: _TimingHeader('Hold')),
            Expanded(child: _TimingHeader('Exhale')),
            Expanded(child: _TimingHeader('Hold')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _TimingValue(segment.inBreath)),
            Expanded(child: _TimingValue(segment.firstHold)),
            Expanded(child: _TimingValue(segment.outBreath)),
            Expanded(child: _TimingValue(segment.secondHold)),
          ],
        ),
      ],
    );
  }
}

class _TimingHeader extends StatelessWidget {
  const _TimingHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFFC4CED6),
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _TimingValue extends StatelessWidget {
  const _TimingValue(this.duration);

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}

class _PranayamaWavePainter extends CustomPainter {
  const _PranayamaWavePainter({
    required this.preset,
    required this.elapsed,
    required this.isActive,
  });

  final PranayamaPreset? preset;
  final Duration elapsed;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0x55D4E0E6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final transitionLinePaint = Paint()
      ..color = const Color(0x88E26E6E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final activeDotPaint = Paint()..color = const Color(0xFF75D4C5);
    final transitionDotPaint = Paint()..color = const Color(0xFFE26E6E);
    final fillPaint = Paint()..color = const Color(0x2618C6B0);
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
    final fillPath = Path.from(path)
      ..lineTo(guide.end.dx, size.height)
      ..lineTo(guide.start.dx, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
    _drawDashedLine(
      canvas,
      guide.leadingStart,
      guide.start,
      transitionLinePaint,
    );
    _drawDashedLine(canvas, guide.end, guide.trailingEnd, transitionLinePaint);
    for (final dot in guide.transitionDots) {
      canvas.drawCircle(dot, 9, transitionDotPaint);
    }
    canvas.drawCircle(guide.activeDot, isActive ? 11 : 8, activeDotPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 8.0;
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
  bool shouldRepaint(covariant _PranayamaWavePainter oldDelegate) {
    return oldDelegate.preset != preset ||
        oldDelegate.elapsed != elapsed ||
        oldDelegate.isActive != isActive;
  }
}

class _PranayamaPathGuide {
  const _PranayamaPathGuide({
    required this.leadingStart,
    required this.start,
    required this.afterInhale,
    required this.afterFirstHold,
    required this.afterExhale,
    required this.end,
    required this.trailingEnd,
    required this.activeDot,
    required this.transitionDots,
  });

  final Offset leadingStart;
  final Offset start;
  final Offset afterInhale;
  final Offset afterFirstHold;
  final Offset afterExhale;
  final Offset end;
  final Offset trailingEnd;
  final Offset activeDot;
  final List<Offset> transitionDots;

  static _PranayamaPathGuide fromPreset(
    PranayamaPreset? preset, {
    required Duration elapsed,
    required Size size,
  }) {
    final segmentPosition = preset == null
        ? null
        : _pranayamaSegmentAtElapsed(preset, elapsed);
    final localElapsed = segmentPosition?.localElapsed ?? elapsed;
    final segment = segmentPosition?.segment;
    final inBreath = segment?.inBreath ?? const Duration(seconds: 5);
    final firstHold = segment?.firstHold ?? Duration.zero;
    final outBreath = segment?.outBreath ?? const Duration(seconds: 6);
    final secondHold = segment?.secondHold ?? Duration.zero;
    final totalDuration = inBreath + firstHold + outBreath + secondHold;
    final totalMilliseconds = totalDuration.inMilliseconds <= 0
        ? 1
        : totalDuration.inMilliseconds;
    final graphDurationMilliseconds =
        totalMilliseconds + _pranayamaLeadDuration.inMilliseconds * 2;
    final bottom = size.height * 0.82;
    final top = size.height * 0.18;

    double xAtGraphDuration(Duration duration) {
      return size.width * duration.inMilliseconds / graphDurationMilliseconds;
    }

    final leadingStart = Offset(0, bottom);
    final start = Offset(xAtGraphDuration(_pranayamaLeadDuration), bottom);
    final afterInhale = Offset(
      xAtGraphDuration(_pranayamaLeadDuration + inBreath),
      top,
    );
    final afterFirstHold = Offset(
      xAtGraphDuration(_pranayamaLeadDuration + inBreath + firstHold),
      top,
    );
    final afterExhale = Offset(
      xAtGraphDuration(
        _pranayamaLeadDuration + inBreath + firstHold + outBreath,
      ),
      bottom,
    );
    final end = Offset(
      xAtGraphDuration(
        _pranayamaLeadDuration + inBreath + firstHold + outBreath + secondHold,
      ),
      bottom,
    );
    final trailingEnd = Offset(size.width, bottom);

    final elapsedInCycle = localElapsed.inMilliseconds % totalMilliseconds;
    final activeDot = _dotForElapsed(
      elapsedInCycle: elapsedInCycle,
      inBreath: inBreath,
      firstHold: firstHold,
      outBreath: outBreath,
      secondHold: secondHold,
      start: start,
      afterInhale: afterInhale,
      afterFirstHold: afterFirstHold,
      afterExhale: afterExhale,
      end: end,
    );
    final transitionDots = preset == null
        ? const <Offset>[]
        : _transitionDotsForElapsed(
            elapsedInCycle: elapsedInCycle,
            elapsed: localElapsed,
            effectiveDuration: _effectivePranayamaSegmentDuration(segment!),
            totalMilliseconds: totalMilliseconds,
            leadDurationMilliseconds: _pranayamaLeadDuration.inMilliseconds,
            leadingStart: leadingStart,
            start: start,
            end: end,
            trailingEnd: trailingEnd,
          );

    return _PranayamaPathGuide(
      leadingStart: leadingStart,
      start: start,
      afterInhale: afterInhale,
      afterFirstHold: afterFirstHold,
      afterExhale: afterExhale,
      end: end,
      trailingEnd: trailingEnd,
      activeDot: activeDot,
      transitionDots: transitionDots,
    );
  }

  static List<Offset> _transitionDotsForElapsed({
    required int elapsedInCycle,
    required Duration elapsed,
    required Duration? effectiveDuration,
    required int totalMilliseconds,
    required int leadDurationMilliseconds,
    required Offset leadingStart,
    required Offset start,
    required Offset end,
    required Offset trailingEnd,
  }) {
    if (leadDurationMilliseconds <= 0) {
      return const [];
    }

    final dots = <Offset>[];
    final cycleIndex = elapsed.inMilliseconds ~/ totalMilliseconds;
    if (cycleIndex > 0 && elapsedInCycle < leadDurationMilliseconds) {
      final progress = elapsedInCycle / leadDurationMilliseconds;
      dots.add(Offset.lerp(end, trailingEnd, progress)!);
    }

    final isLastCycle =
        effectiveDuration != null &&
        cycleIndex >= effectiveDuration.inMilliseconds ~/ totalMilliseconds - 1;
    final millisecondsUntilNextCycle = totalMilliseconds - elapsedInCycle;
    if (!isLastCycle &&
        millisecondsUntilNextCycle <= leadDurationMilliseconds) {
      final progress =
          1 - millisecondsUntilNextCycle / leadDurationMilliseconds;
      dots.add(Offset.lerp(leadingStart, start, progress)!);
    }

    return dots;
  }

  static Offset _dotForElapsed({
    required int elapsedInCycle,
    required Duration inBreath,
    required Duration firstHold,
    required Duration outBreath,
    required Duration secondHold,
    required Offset start,
    required Offset afterInhale,
    required Offset afterFirstHold,
    required Offset afterExhale,
    required Offset end,
  }) {
    var phaseStart = 0;

    Offset interpolate(Offset begin, Offset finish, Duration duration) {
      final phaseMilliseconds = duration.inMilliseconds;
      if (phaseMilliseconds <= 0) {
        return finish;
      }

      final progress =
          (elapsedInCycle - phaseStart).clamp(0, phaseMilliseconds) /
          phaseMilliseconds;
      return Offset.lerp(begin, finish, progress)!;
    }

    final inhaleEnd = phaseStart + inBreath.inMilliseconds;
    if (elapsedInCycle < inhaleEnd) {
      return interpolate(start, afterInhale, inBreath);
    }
    phaseStart = inhaleEnd;

    final firstHoldEnd = phaseStart + firstHold.inMilliseconds;
    if (elapsedInCycle < firstHoldEnd) {
      return interpolate(afterInhale, afterFirstHold, firstHold);
    }
    phaseStart = firstHoldEnd;

    final exhaleEnd = phaseStart + outBreath.inMilliseconds;
    if (elapsedInCycle < exhaleEnd) {
      return interpolate(afterFirstHold, afterExhale, outBreath);
    }
    phaseStart = exhaleEnd;

    return interpolate(afterExhale, end, secondHold);
  }
}

class _EmptyPranayamaRecentPresetsMessage extends StatelessWidget {
  const _EmptyPranayamaRecentPresetsMessage();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Text(
        'No recent presets yet',
        style: TextStyle(
          color: _mutedTextColor,
          fontSize: 14,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PranayamaBrowser extends StatelessWidget {
  const _PranayamaBrowser({
    required this.entries,
    required this.expandedFolders,
    required this.onToggleFolder,
    required this.onStartPreset,
  });

  final List<PranayamaBrowserEntry> entries;
  final Set<String> expandedFolders;
  final ValueChanged<String> onToggleFolder;
  final ValueChanged<PranayamaPreset> onStartPreset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [for (final entry in entries) ..._widgetsForEntry(entry)],
    );
  }

  List<Widget> _widgetsForEntry(PranayamaBrowserEntry entry) {
    return switch (entry) {
      PranayamaPresetEntry(:final preset) => [
        _PranayamaPresetRow(preset: preset, onTap: () => onStartPreset(preset)),
      ],
      PranayamaFolderEntry(:final folder) => [
        _PranayamaFolderRow(
          folder: folder,
          isExpanded: expandedFolders.contains(folder.name),
          onTap: () => onToggleFolder(folder.name),
        ),
        if (expandedFolders.contains(folder.name))
          for (final preset in folder.presets)
            _PranayamaPresetRow(
              preset: preset,
              isNested: true,
              onTap: () => onStartPreset(preset),
            ),
      ],
    };
  }
}

class _EditablePranayamaBrowser extends StatelessWidget {
  const _EditablePranayamaBrowser({
    required this.entries,
    required this.onReorder,
    required this.onEditPreset,
    required this.onDeletePreset,
    required this.onEditFolderTitle,
    required this.onDeleteFolder,
  });

  final List<PranayamaBrowserEntry> entries;
  final ReorderCallback onReorder;
  final ValueChanged<PranayamaPreset> onEditPreset;
  final ValueChanged<PranayamaPreset> onDeletePreset;
  final ValueChanged<PranayamaFolder> onEditFolderTitle;
  final ValueChanged<PranayamaFolder> onDeleteFolder;

  @override
  Widget build(BuildContext context) {
    final rows = _editablePranayamaRowsFor(entries);

    return ReorderableListView.builder(
      key: const ValueKey('editable-pranayama-browser'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: rows.length,
      onReorderItem: onReorder,
      itemBuilder: (context, index) {
        final row = rows[index];

        return KeyedSubtree(
          key: ValueKey('editable-pranayama-${row.id}'),
          child: _EditablePranayamaBrowserEntry(
            row: row,
            index: index,
            onEditPreset: onEditPreset,
            onDeletePreset: onDeletePreset,
            onEditFolderTitle: onEditFolderTitle,
            onDeleteFolder: onDeleteFolder,
          ),
        );
      },
    );
  }
}

class _EditablePranayamaBrowserEntry extends StatelessWidget {
  const _EditablePranayamaBrowserEntry({
    required this.row,
    required this.index,
    required this.onEditPreset,
    required this.onDeletePreset,
    required this.onEditFolderTitle,
    required this.onDeleteFolder,
  });

  final _EditablePranayamaBrowserRow row;
  final int index;
  final ValueChanged<PranayamaPreset> onEditPreset;
  final ValueChanged<PranayamaPreset> onDeletePreset;
  final ValueChanged<PranayamaFolder> onEditFolderTitle;
  final ValueChanged<PranayamaFolder> onDeleteFolder;

  @override
  Widget build(BuildContext context) {
    final dragHandle = ReorderableDragStartListener(
      key: ValueKey('drag-handle-pranayama-${row.id}'),
      index: index,
      child: const Padding(
        padding: EdgeInsets.only(left: 12),
        child: Icon(Icons.drag_handle_rounded, color: Colors.white, size: 28),
      ),
    );

    return switch (row) {
      _EditablePranayamaPresetRow(:final preset, :final folderName) =>
        _PranayamaPresetRow(
          preset: preset,
          onTap: null,
          isNested: folderName != null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: ValueKey('edit-pranayama-${row.id}'),
                onPressed: () => onEditPreset(preset),
                tooltip: 'Edit preset',
                color: Colors.white,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: ValueKey('delete-pranayama-${row.id}'),
                onPressed: () => onDeletePreset(preset),
                tooltip: 'Delete preset',
                color: const Color(0xFFE06A6A),
                icon: const Icon(Icons.delete_outline),
              ),
              dragHandle,
            ],
          ),
        ),
      _EditablePranayamaFolderRow(:final folder) => _PranayamaFolderRow(
        folder: folder,
        isExpanded: true,
        onTap: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('edit-pranayama-folder-title-${folder.name}'),
              onPressed: () => onEditFolderTitle(folder),
              tooltip: 'Edit folder title',
              color: Colors.white,
              icon: const Icon(Icons.drive_file_rename_outline),
            ),
            IconButton(
              key: ValueKey('delete-pranayama-folder-${folder.name}'),
              onPressed: folder.presets.isEmpty
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

class _PranayamaPresetRow extends StatelessWidget {
  const _PranayamaPresetRow({
    required this.preset,
    required this.onTap,
    this.isNested = false,
    this.keySuffix,
    this.trailing,
  });

  final PranayamaPreset preset;
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
            'pranayama-${preset.name}-${keySuffix ?? (isNested ? 'nested' : 'root')}',
          ),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.air_rounded,
                  color: Color(0xFFB7B7BC),
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pranayamaPresetDetails(preset),
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

class _PranayamaFolderRow extends StatelessWidget {
  const _PranayamaFolderRow({
    required this.folder,
    required this.isExpanded,
    required this.onTap,
    this.trailing,
  });

  final PranayamaFolder folder;
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
          key: ValueKey('pranayama-folder-${folder.name}'),
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

class PranayamaEditScreen extends StatefulWidget {
  const PranayamaEditScreen({
    super.key,
    this.preset,
    this.existingPresetNames = const <String>{},
  });

  final PranayamaPreset? preset;
  final Set<String> existingPresetNames;

  @override
  State<PranayamaEditScreen> createState() => _PranayamaEditScreenState();
}

class _PranayamaEditScreenState extends State<PranayamaEditScreen> {
  late String _presetName;
  late final TextEditingController _noteController;
  late final List<_EditablePranayamaSegment> _segments;
  String? _errorText;
  bool _isNormalizingDurationFields = false;
  bool _isEditingSegments = false;
  int _nextSegmentId = 0;

  bool get _isCreating => widget.preset == null;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    _presetName = preset?.name ?? 'New preset';
    _noteController = TextEditingController(text: preset?.note ?? '');
    _segments = [
      for (final segment in preset?.segments ?? [_defaultPranayamaSegment()])
        _EditablePranayamaSegment.fromSegment(
          id: 'editable-pranayama-segment-${_nextSegmentId++}',
          segment: segment,
        ),
    ];
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final segment in _segments) {
      segment.dispose();
    }
    super.dispose();
  }

  Future<void> _editTitle() async {
    var editedName = _presetName;
    String? errorText;
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        void submit(StateSetter setDialogState) {
          final trimmedName = editedName.trim();
          if (trimmedName.isEmpty) {
            setDialogState(() {
              errorText = 'Enter a preset title';
            });
            return;
          }

          if (widget.existingPresetNames.contains(trimmedName)) {
            setDialogState(() {
              errorText = 'A preset with this title already exists';
            });
            return;
          }

          Navigator.of(context).pop(trimmedName);
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _homeSurfaceColor,
              title: const Text('Preset title'),
              content: TextFormField(
                key: const ValueKey('pranayama-title-field'),
                initialValue: _presetName,
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
                  key: const ValueKey('save-pranayama-title-button'),
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
      _presetName = newName;
      _errorText = null;
    });
  }

  void _savePreset() {
    final trimmedName = _presetName.trim();
    if (trimmedName.isEmpty) {
      setState(() {
        _errorText = 'Enter a preset title';
      });
      return;
    }

    if (widget.existingPresetNames.contains(trimmedName)) {
      setState(() {
        _errorText = 'A preset with this title already exists';
      });
      return;
    }

    if (_segments.isEmpty) {
      setState(() {
        _segments.add(_newEditablePranayamaSegment());
      });
    }

    final savedSegments = <PranayamaSegment>[];
    for (var index = 0; index < _segments.length; index += 1) {
      savedSegments.add(
        _segmentFromControllers(
          _segments[index],
          isLast: index == _segments.length - 1,
          enforceMinimumDuration: true,
        ),
      );
    }

    Navigator.of(context).pop(
      PranayamaPreset(
        id: widget.preset?.id ?? _newPranayamaPresetId(),
        name: trimmedName,
        note: _noteController.text.trim(),
        segments: savedSegments,
      ),
    );
  }

  void _addSegment() {
    setState(() {
      _isEditingSegments = true;
      _segments.add(_newEditablePranayamaSegment());
    });
  }

  void _toggleSegmentEditing() {
    setState(() {
      _isEditingSegments = !_isEditingSegments;
    });
  }

  void _deleteSegment(String id) {
    if (_segments.length <= 1) {
      setState(() {
        _errorText = 'A preset needs at least one segment';
      });
      return;
    }

    setState(() {
      final index = _segments.indexWhere((segment) => segment.id == id);
      if (index == -1) {
        return;
      }
      _segments.removeAt(index).dispose();
      _errorText = null;
    });
  }

  void _reorderSegment(int oldIndex, int newIndex) {
    setState(() {
      final segment = _segments.removeAt(oldIndex);
      _segments.insert(newIndex, segment);
      _errorText = null;
    });
  }

  _EditablePranayamaSegment _newEditablePranayamaSegment() {
    return _EditablePranayamaSegment.fromSegment(
      id: 'new-pranayama-segment-${DateTime.now().microsecondsSinceEpoch}-${_nextSegmentId++}',
      segment: _defaultPranayamaSegment(),
    );
  }

  PranayamaSegment _segmentFromControllers(
    _EditablePranayamaSegment segment, {
    required bool isLast,
    bool enforceMinimumDuration = false,
  }) {
    final duration = !isLast || !segment.isInfinite
        ? _normalizeDurationFields(
            segment,
            enforceMinimum: enforceMinimumDuration,
          )
        : null;
    final inBreath = _secondsDurationFromController(
      segment.inBreathController,
      enforceMinimum: true,
    );
    final firstHold = _secondsDurationFromController(
      segment.firstHoldController,
    );
    final outBreath = _secondsDurationFromController(
      segment.outBreathController,
      enforceMinimum: true,
    );
    final secondHold = _secondsDurationFromController(
      segment.secondHoldController,
    );

    return PranayamaSegment(
      id: segment.segmentId,
      duration: duration,
      inBreath: inBreath,
      firstHold: firstHold,
      outBreath: outBreath,
      secondHold: secondHold,
    );
  }

  Duration? _normalizeDurationFields(
    _EditablePranayamaSegment segment, {
    bool enforceMinimum = false,
  }) {
    if (_isNormalizingDurationFields) {
      return null;
    }

    // Accept forgiving input (for example 90 minutes) and immediately fold it
    // back into canonical hh:mm:ss fields. This mirrors the timer editor.
    final hours = _nonNegativeFieldValue(segment.hoursController);
    final minutes = _nonNegativeFieldValue(segment.minutesController);
    final seconds = _nonNegativeFieldValue(segment.secondsController);
    final duration = Duration(hours: hours, minutes: minutes, seconds: seconds);

    if (duration.inHours > 999) {
      if (identical(segment, _segments.last)) {
        // Very large finite breath sessions are not useful to edit by hand; flip
        // the last segment to the explicit infinite duration state.
        setState(() {
          segment.isInfinite = true;
          _errorText = null;
        });
        return null;
      }

      _updateDurationFields(segment, const Duration(hours: 999));
      return const Duration(hours: 999);
    }

    final normalizedDuration = enforceMinimum && duration == Duration.zero
        ? const Duration(seconds: 1)
        : duration;

    if (enforceMinimum ||
        !_hasBlankDurationField(
              segment.hoursController,
              segment.minutesController,
              segment.secondsController,
            ) &&
            (minutes >= 60 || seconds >= 60)) {
      _updateDurationFields(segment, normalizedDuration);
    }
    return normalizedDuration;
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

  Duration _secondsDurationFromController(
    TextEditingController controller, {
    bool enforceMinimum = false,
  }) {
    final seconds = _nonNegativeFieldValue(controller);
    final normalizedSeconds = enforceMinimum && seconds == 0 ? 1 : seconds;
    _setControllerText(controller, normalizedSeconds.toString());
    return Duration(seconds: normalizedSeconds);
  }

  void _updateDurationFields(
    _EditablePranayamaSegment segment,
    Duration duration,
  ) {
    _isNormalizingDurationFields = true;
    _setControllerText(segment.hoursController, duration.inHours.toString());
    _setControllerText(
      segment.minutesController,
      duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
    );
    _setControllerText(
      segment.secondsController,
      duration.inSeconds.remainder(60).toString().padLeft(2, '0'),
    );
    _isNormalizingDurationFields = false;
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TimerEditTitleBar(
              title: _isCreating ? 'Create new preset' : 'Edit preset',
              onCancel: () => Navigator.of(context).pop(),
              onSave: _savePreset,
            ),
            const Divider(height: 1, thickness: 1, color: _dividerColor),
            Expanded(
              child: ColoredBox(
                color: _homeSurfaceColor,
                child: SingleChildScrollView(
                  key: const ValueKey('pranayama-edit-scroll-view'),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorText != null) ...[
                        _TimerEditErrorBanner(errorText: _errorText!),
                        const SizedBox(height: 16),
                      ],
                      _TimerTitleEditor(
                        timerName: _presetName,
                        onEditTitle: _editTitle,
                      ),
                      const SizedBox(height: 16),
                      _NoteEditor(controller: _noteController),
                      const SizedBox(height: 24),
                      _SectionHeader(
                        title: 'Segments',
                        actions: [
                          _HeaderAction(
                            key: const ValueKey('add-pranayama-segment-button'),
                            tooltip: 'Add segment',
                            icon: const Icon(Icons.add_rounded),
                            onPressed: _addSegment,
                          ),
                          _HeaderAction(
                            key: const ValueKey(
                              'edit-pranayama-segments-button',
                            ),
                            tooltip: _isEditingSegments
                                ? 'Finish editing'
                                : 'Edit',
                            icon: Icon(
                              _isEditingSegments
                                  ? Icons.check_rounded
                                  : Icons.edit_outlined,
                            ),
                            onPressed: _toggleSegmentEditing,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isEditingSegments)
                        ReorderableListView.builder(
                          key: const ValueKey(
                            'editable-pranayama-segments-list',
                          ),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: _segments.length,
                          onReorderItem: _reorderSegment,
                          itemBuilder: (context, index) {
                            final segment = _segments[index];
                            return KeyedSubtree(
                              key: ValueKey('editable-${segment.id}'),
                              child: _PranayamaSegmentEditor(
                                index: index,
                                segment: segment,
                                isLast: index == _segments.length - 1,
                                isEditing: true,
                                onDurationChanged: () {
                                  _normalizeDurationFields(segment);
                                },
                                onInfiniteChanged: (isInfinite) {
                                  setState(() {
                                    segment.isInfinite = isInfinite;
                                    _errorText = null;
                                  });
                                },
                                onBreathChanged: () {
                                  _normalizeBreathFields(segment);
                                },
                                onDelete: _segments.length <= 1
                                    ? null
                                    : () => _deleteSegment(segment.id),
                                dragHandle: ReorderableDragStartListener(
                                  key: ValueKey(
                                    'drag-handle-pranayama-segment-${segment.id}',
                                  ),
                                  index: index,
                                  child: const Icon(
                                    Icons.drag_handle_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        for (
                          var index = 0;
                          index < _segments.length;
                          index += 1
                        )
                          _PranayamaSegmentEditor(
                            index: index,
                            segment: _segments[index],
                            isLast: index == _segments.length - 1,
                            isEditing: false,
                            onDurationChanged: () {
                              _normalizeDurationFields(_segments[index]);
                            },
                            onInfiniteChanged: (isInfinite) {
                              setState(() {
                                _segments[index].isInfinite = isInfinite;
                                _errorText = null;
                              });
                            },
                            onBreathChanged: () {
                              _normalizeBreathFields(_segments[index]);
                            },
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

  void _normalizeBreathFields(_EditablePranayamaSegment _) {
    // Breath phase fields are plain second counts, so there is nothing to carry
    // while typing. Final save still parses and clamps them, but leaving this as
    // a no-op lets users erase the last digit before entering a replacement.
  }
}

PranayamaSegment _defaultPranayamaSegment() {
  return PranayamaSegment(
    id: 'segment-${DateTime.now().microsecondsSinceEpoch}',
    duration: const Duration(minutes: 10),
    inBreath: const Duration(seconds: 5),
    firstHold: Duration.zero,
    outBreath: const Duration(seconds: 6),
    secondHold: Duration.zero,
  );
}

class _EditablePranayamaSegment {
  _EditablePranayamaSegment.fromSegment({
    required this.id,
    required PranayamaSegment segment,
  }) : segmentId = segment.id,
       isInfinite = segment.isInfinite,
       hoursController = TextEditingController(
         text: (segment.duration ?? const Duration(minutes: 10)).inHours
             .toString(),
       ),
       minutesController = TextEditingController(
         text: (segment.duration ?? const Duration(minutes: 10)).inMinutes
             .remainder(60)
             .toString()
             .padLeft(2, '0'),
       ),
       secondsController = TextEditingController(
         text: (segment.duration ?? const Duration(minutes: 10)).inSeconds
             .remainder(60)
             .toString()
             .padLeft(2, '0'),
       ),
       inBreathController = TextEditingController(
         text: segment.inBreath.inSeconds.toString(),
       ),
       firstHoldController = TextEditingController(
         text: segment.firstHold.inSeconds.toString(),
       ),
       outBreathController = TextEditingController(
         text: segment.outBreath.inSeconds.toString(),
       ),
       secondHoldController = TextEditingController(
         text: segment.secondHold.inSeconds.toString(),
       );

  final String id;
  final String segmentId;
  bool isInfinite;
  final TextEditingController hoursController;
  final TextEditingController minutesController;
  final TextEditingController secondsController;
  final TextEditingController inBreathController;
  final TextEditingController firstHoldController;
  final TextEditingController outBreathController;
  final TextEditingController secondHoldController;

  void dispose() {
    hoursController.dispose();
    minutesController.dispose();
    secondsController.dispose();
    inBreathController.dispose();
    firstHoldController.dispose();
    outBreathController.dispose();
    secondHoldController.dispose();
  }
}

class _PranayamaSegmentEditor extends StatelessWidget {
  const _PranayamaSegmentEditor({
    required this.index,
    required this.segment,
    required this.isLast,
    required this.isEditing,
    required this.onDurationChanged,
    required this.onInfiniteChanged,
    required this.onBreathChanged,
    this.onDelete,
    this.dragHandle,
  });

  final int index;
  final _EditablePranayamaSegment segment;
  final bool isLast;
  final bool isEditing;
  final VoidCallback onDurationChanged;
  final ValueChanged<bool> onInfiniteChanged;
  final VoidCallback onBreathChanged;
  final VoidCallback? onDelete;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _TimerEditPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Segment ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (isEditing) ...[
                  IconButton(
                    key: ValueKey('delete-pranayama-segment-${segment.id}'),
                    onPressed: onDelete,
                    tooltip: 'Delete segment',
                    color: const Color(0xFFE06A6A),
                    disabledColor: const Color(0xFF6A4444),
                    icon: const Icon(Icons.delete_outline),
                  ),
                  ?dragHandle,
                ],
              ],
            ),
            const SizedBox(height: 14),
            _DurationEditor(
              title: 'Segment duration',
              isInfinite: isLast && segment.isInfinite,
              hoursController: segment.hoursController,
              minutesController: segment.minutesController,
              secondsController: segment.secondsController,
              onDurationChanged: onDurationChanged,
              onInfiniteChanged: onInfiniteChanged,
              showInfiniteToggle: isLast,
              wrapInPanel: false,
            ),
            const SizedBox(height: 14),
            _PranayamaBreathEditor(
              inBreathController: segment.inBreathController,
              firstHoldController: segment.firstHoldController,
              outBreathController: segment.outBreathController,
              secondHoldController: segment.secondHoldController,
              onChanged: onBreathChanged,
              wrapInPanel: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _PranayamaBreathEditor extends StatelessWidget {
  const _PranayamaBreathEditor({
    required this.inBreathController,
    required this.firstHoldController,
    required this.outBreathController,
    required this.secondHoldController,
    required this.onChanged,
    this.wrapInPanel = true,
  });

  final TextEditingController inBreathController;
  final TextEditingController firstHoldController;
  final TextEditingController outBreathController;
  final TextEditingController secondHoldController;
  final VoidCallback onChanged;
  final bool wrapInPanel;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Breath cycle',
          style: TextStyle(
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
                key: const ValueKey('pranayama-in-breath-field'),
                label: 'In-breath',
                controller: inBreathController,
                enabled: true,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DurationNumberField(
                key: const ValueKey('pranayama-first-hold-field'),
                label: 'Hold',
                controller: firstHoldController,
                enabled: true,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DurationNumberField(
                key: const ValueKey('pranayama-out-breath-field'),
                label: 'Out-breath',
                controller: outBreathController,
                enabled: true,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DurationNumberField(
                key: const ValueKey('pranayama-second-hold-field'),
                label: 'Hold',
                controller: secondHoldController,
                enabled: true,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );

    if (!wrapInPanel) {
      return content;
    }

    return _TimerEditPanel(child: content);
  }
}

sealed class _EditablePranayamaBrowserRow {
  const _EditablePranayamaBrowserRow();

  String get id;
}

class _EditablePranayamaPresetRow extends _EditablePranayamaBrowserRow {
  const _EditablePranayamaPresetRow({required this.preset, this.folderName});

  final PranayamaPreset preset;
  final String? folderName;

  @override
  String get id => folderName == null
      ? 'preset-${preset.name}'
      : 'preset-$folderName-${preset.name}';
}

class _EditablePranayamaFolderRow extends _EditablePranayamaBrowserRow {
  const _EditablePranayamaFolderRow({required this.folder});

  final PranayamaFolder folder;

  @override
  String get id => 'folder-${folder.name}';
}

List<_EditablePranayamaBrowserRow> _editablePranayamaRowsFor(
  List<PranayamaBrowserEntry> entries,
) {
  final rows = <_EditablePranayamaBrowserRow>[];

  for (final entry in entries) {
    switch (entry) {
      case PranayamaPresetEntry(:final preset):
        rows.add(_EditablePranayamaPresetRow(preset: preset));
      case PranayamaFolderEntry(:final folder):
        rows.add(_EditablePranayamaFolderRow(folder: folder));
        rows.addAll([
          for (final preset in folder.presets)
            _EditablePranayamaPresetRow(
              preset: preset,
              folderName: folder.name,
            ),
        ]);
    }
  }

  return rows;
}

List<PranayamaBrowserEntry> _removeEditablePranayamaRow(
  List<PranayamaBrowserEntry> entries,
  _EditablePranayamaBrowserRow row,
) {
  return switch (row) {
    _EditablePranayamaPresetRow(:final preset) => [
      for (final entry in entries)
        ...switch (entry) {
          PranayamaPresetEntry(preset: final entryPreset)
              when entryPreset.name == preset.name =>
            const <PranayamaBrowserEntry>[],
          PranayamaPresetEntry() => [entry],
          PranayamaFolderEntry(:final folder) => [
            PranayamaFolderEntry(
              folder.withPresets([
                for (final folderPreset in folder.presets)
                  if (folderPreset.name != preset.name) folderPreset,
              ]),
            ),
          ],
        },
    ],
    _EditablePranayamaFolderRow(:final folder) => [
      for (final entry in entries)
        if (entry case PranayamaFolderEntry(
          folder: final entryFolder,
        ) when entryFolder.name == folder.name)
          ...const <PranayamaBrowserEntry>[]
        else
          entry,
    ],
  };
}

List<PranayamaBrowserEntry> _replacePranayamaPreset(
  List<PranayamaBrowserEntry> entries,
  String oldPresetName,
  PranayamaPreset updatedPreset,
) {
  return [
    for (final entry in entries)
      switch (entry) {
        PranayamaPresetEntry(preset: final preset)
            when preset.name == oldPresetName =>
          PranayamaPresetEntry(updatedPreset),
        PranayamaPresetEntry() => entry,
        PranayamaFolderEntry(:final folder) => PranayamaFolderEntry(
          folder.withPresets([
            for (final preset in folder.presets)
              preset.name == oldPresetName ? updatedPreset : preset,
          ]),
        ),
      },
  ];
}

List<PranayamaBrowserEntry> _removePranayamaPreset(
  List<PranayamaBrowserEntry> entries,
  String presetName,
) {
  return [
    for (final entry in entries)
      ...switch (entry) {
        PranayamaPresetEntry(preset: final preset)
            when preset.name == presetName =>
          const <PranayamaBrowserEntry>[],
        PranayamaPresetEntry() => [entry],
        PranayamaFolderEntry(:final folder) => [
          PranayamaFolderEntry(
            folder.withPresets([
              for (final preset in folder.presets)
                if (preset.name != presetName) preset,
            ]),
          ),
        ],
      },
  ];
}

List<PranayamaBrowserEntry> _insertPranayamaPresetRow(
  List<PranayamaBrowserEntry> entries,
  List<_EditablePranayamaBrowserRow> rows,
  int targetIndex,
  PranayamaPreset preset,
) {
  final targetFolderName = _targetPranayamaFolderNameFor(rows, targetIndex);

  if (targetFolderName != null) {
    return [
      for (final entry in entries)
        switch (entry) {
          PranayamaPresetEntry() => entry,
          PranayamaFolderEntry(:final folder)
              when folder.name == targetFolderName =>
            PranayamaFolderEntry(
              folder.withPresets(
                _insertPranayamaPresetIntoFolder(rows, targetIndex, preset),
              ),
            ),
          PranayamaFolderEntry() => entry,
        },
    ];
  }

  final targetTopLevelIndex = _targetPranayamaTopLevelIndexFor(
    rows,
    targetIndex,
  );
  final updatedEntries = List<PranayamaBrowserEntry>.of(entries);
  updatedEntries.insert(targetTopLevelIndex, PranayamaPresetEntry(preset));
  return updatedEntries;
}

List<PranayamaPreset> _insertPranayamaPresetIntoFolder(
  List<_EditablePranayamaBrowserRow> rows,
  int targetIndex,
  PranayamaPreset preset,
) {
  final folderName = _targetPranayamaFolderNameFor(rows, targetIndex)!;
  final existingPresets = [
    for (final row in rows)
      if (row case _EditablePranayamaPresetRow(
        preset: final rowPreset,
        folderName: final rowFolderName?,
      ))
        if (rowFolderName == folderName) rowPreset,
  ];
  final targetChildIndex = rows.take(targetIndex).where((row) {
    return row is _EditablePranayamaPresetRow && row.folderName == folderName;
  }).length;

  existingPresets.insert(targetChildIndex, preset);
  return existingPresets;
}

List<PranayamaBrowserEntry> _insertPranayamaFolderRow(
  List<PranayamaBrowserEntry> entries,
  List<_EditablePranayamaBrowserRow> rows,
  int targetIndex,
  PranayamaFolder folder,
) {
  final targetTopLevelIndex = _targetPranayamaTopLevelIndexFor(
    rows,
    targetIndex,
  );
  final updatedEntries = List<PranayamaBrowserEntry>.of(entries);
  updatedEntries.insert(targetTopLevelIndex, PranayamaFolderEntry(folder));
  return updatedEntries;
}

String? _targetPranayamaFolderNameFor(
  List<_EditablePranayamaBrowserRow> rows,
  int targetIndex,
) {
  if (targetIndex == 0) {
    return null;
  }

  final previousRow = rows[targetIndex - 1];
  return switch (previousRow) {
    _EditablePranayamaFolderRow(:final folder) => folder.name,
    _EditablePranayamaPresetRow(:final folderName) => folderName,
  };
}

int _targetPranayamaTopLevelIndexFor(
  List<_EditablePranayamaBrowserRow> rows,
  int targetIndex,
) {
  return rows.take(targetIndex).where((row) {
    return row is _EditablePranayamaFolderRow ||
        row is _EditablePranayamaPresetRow && row.folderName == null;
  }).length;
}

List<Map<String, Object?>> _encodePranayamaEntries(
  List<PranayamaBrowserEntry> entries,
) {
  return [
    for (final entry in entries)
      switch (entry) {
        PranayamaPresetEntry(:final preset) => {
          'type': 'preset',
          'preset': _encodePranayamaPreset(preset),
        },
        PranayamaFolderEntry(:final folder) => {
          'type': 'folder',
          'folder': folder.name,
          'presets': [
            for (final preset in folder.presets) _encodePranayamaPreset(preset),
          ],
        },
      },
  ];
}

Map<String, Object?> _encodePranayamaPreset(PranayamaPreset preset) {
  return {
    'id': preset.id,
    'name': preset.name,
    'note': preset.note,
    'segments': [
      for (final segment in preset.segments) _encodePranayamaSegment(segment),
    ],
  };
}

Map<String, Object?> _encodePranayamaSegment(PranayamaSegment segment) {
  return {
    'id': segment.id,
    'durationSeconds': segment.duration?.inSeconds,
    'inBreathSeconds': segment.inBreath.inSeconds,
    'firstHoldSeconds': segment.firstHold.inSeconds,
    'outBreathSeconds': segment.outBreath.inSeconds,
    'secondHoldSeconds': segment.secondHold.inSeconds,
  };
}

List<PranayamaBrowserEntry>? _decodePranayamaEntries(String? encodedEntries) {
  if (encodedEntries == null) {
    return null;
  }

  try {
    // Pranayama ordering is user-editable and persisted as a small tree.
    // Decode all-or-nothing so corrupt storage does not create half-folders or
    // duplicate titles that the editor cannot safely manipulate.
    final decoded = jsonDecode(encodedEntries);
    if (decoded is! List) {
      return null;
    }

    final entries = <PranayamaBrowserEntry>[];
    final usedPresets = <String>{};
    final usedFolders = <String>{};

    for (final item in decoded) {
      if (item is! Map<String, Object?>) {
        return null;
      }

      switch (item['type']) {
        case 'preset':
          final preset = _decodePranayamaPreset(item['preset']);
          if (preset == null || usedPresets.contains(preset.name)) {
            return null;
          }

          entries.add(PranayamaPresetEntry(preset));
          usedPresets.add(preset.name);
        case 'folder':
          final folderName = item['folder'];
          final encodedPresets = item['presets'];
          if (folderName is! String ||
              encodedPresets is! List ||
              usedFolders.contains(folderName)) {
            return null;
          }

          final presets = <PranayamaPreset>[];
          for (final encodedPreset in encodedPresets) {
            final preset = _decodePranayamaPreset(encodedPreset);
            if (preset == null || usedPresets.contains(preset.name)) {
              return null;
            }

            presets.add(preset);
            usedPresets.add(preset.name);
          }

          entries.add(
            PranayamaFolderEntry(
              PranayamaFolder(name: folderName, presets: presets),
            ),
          );
          usedFolders.add(folderName);
        default:
          return null;
      }
    }

    return entries.isEmpty ? null : entries;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

PranayamaPreset? _decodePranayamaPreset(Object? encodedPreset) {
  if (encodedPreset is! Map<String, Object?>) {
    return null;
  }

  final name = encodedPreset['name'];
  final id = encodedPreset['id'];
  final note = encodedPreset['note'];
  final encodedSegments = encodedPreset['segments'];
  final durationSeconds = encodedPreset['durationSeconds'];
  final inBreathSeconds = encodedPreset['inBreathSeconds'];
  final firstHoldSeconds = encodedPreset['firstHoldSeconds'];
  final outBreathSeconds = encodedPreset['outBreathSeconds'];
  final secondHoldSeconds = encodedPreset['secondHoldSeconds'];

  if (name is! String || name.trim().isEmpty) {
    return null;
  }
  if (id != null && (id is! String || id.trim().isEmpty)) {
    return null;
  }
  if (note != null && note is! String) {
    return null;
  }
  final segments = <PranayamaSegment>[];
  if (encodedSegments is List) {
    for (final encodedSegment in encodedSegments) {
      final segment = _decodePranayamaSegment(encodedSegment);
      if (segment == null) {
        return null;
      }
      segments.add(segment);
    }
  } else {
    // Backward-compatible migration for presets saved before multi-segment
    // pranayama existed.
    final segment = _decodePranayamaSegment({
      'id': 'segment-${id is String ? id : _legacyPranayamaPresetId(name)}',
      'durationSeconds': durationSeconds,
      'inBreathSeconds': inBreathSeconds,
      'firstHoldSeconds': firstHoldSeconds,
      'outBreathSeconds': outBreathSeconds,
      'secondHoldSeconds': secondHoldSeconds,
    });
    if (segment == null) {
      return null;
    }
    segments.add(segment);
  }

  if (segments.isEmpty) {
    return null;
  }
  for (var index = 0; index < segments.length - 1; index += 1) {
    if (segments[index].isInfinite) {
      return null;
    }
  }

  return PranayamaPreset(
    id: id as String? ?? _legacyPranayamaPresetId(name),
    name: name,
    note: note as String? ?? '',
    segments: segments,
  );
}

PranayamaSegment? _decodePranayamaSegment(Object? encodedSegment) {
  if (encodedSegment is! Map<String, Object?>) {
    return null;
  }

  final id = encodedSegment['id'];
  final durationSeconds = encodedSegment['durationSeconds'];
  final inBreathSeconds = encodedSegment['inBreathSeconds'];
  final firstHoldSeconds = encodedSegment['firstHoldSeconds'];
  final outBreathSeconds = encodedSegment['outBreathSeconds'];
  final secondHoldSeconds = encodedSegment['secondHoldSeconds'];

  if (id != null && (id is! String || id.trim().isEmpty)) {
    return null;
  }
  if (durationSeconds != null &&
      (durationSeconds is! int || durationSeconds < 0)) {
    return null;
  }
  if (inBreathSeconds is! int ||
      firstHoldSeconds is! int ||
      outBreathSeconds is! int ||
      secondHoldSeconds is! int ||
      inBreathSeconds <= 0 ||
      outBreathSeconds <= 0 ||
      firstHoldSeconds < 0 ||
      secondHoldSeconds < 0) {
    return null;
  }

  return PranayamaSegment(
    id: id as String? ?? 'segment-${DateTime.now().microsecondsSinceEpoch}',
    duration: durationSeconds == null
        ? null
        : Duration(seconds: durationSeconds as int),
    inBreath: Duration(seconds: inBreathSeconds),
    firstHold: Duration(seconds: firstHoldSeconds),
    outBreath: Duration(seconds: outBreathSeconds),
    secondHold: Duration(seconds: secondHoldSeconds),
  );
}

PranayamaPreset? _pranayamaPresetByIdInEntries(
  String presetId,
  List<PranayamaBrowserEntry> entries,
) {
  for (final entry in entries) {
    switch (entry) {
      case PranayamaPresetEntry(:final preset):
        if (preset.id == presetId) {
          return preset;
        }
      case PranayamaFolderEntry(:final folder):
        for (final preset in folder.presets) {
          if (preset.id == presetId) {
            return preset;
          }
        }
    }
  }

  return null;
}

class _PranayamaPhaseSnapshot {
  const _PranayamaPhaseSnapshot({
    required this.label,
    required this.progress,
    required this.breathCount,
    required this.cycleProgress,
  });

  final String label;
  final double progress;
  final int breathCount;
  final double cycleProgress;
}

_PranayamaPhaseSnapshot _phaseSnapshotForPranayama(
  PranayamaPreset preset,
  Duration elapsed,
) {
  final segmentPosition = _pranayamaSegmentAtElapsed(preset, elapsed);
  final segment = segmentPosition.segment;
  final localElapsed = segmentPosition.localElapsed;
  final cycleMilliseconds = segment.cycleDuration.inMilliseconds;
  if (cycleMilliseconds <= 0) {
    return const _PranayamaPhaseSnapshot(
      label: 'Ready',
      progress: 0,
      breathCount: 0,
      cycleProgress: 0,
    );
  }

  final elapsedMilliseconds = localElapsed.inMilliseconds.clamp(0, 1 << 62);
  final cycleElapsed = elapsedMilliseconds % cycleMilliseconds;
  final cycleProgress = cycleElapsed / cycleMilliseconds;
  var cursor = cycleElapsed;

  _PranayamaPhaseSnapshot snapshotFor(
    String label,
    Duration phaseDuration,
    int phaseStart,
  ) {
    final denominator = phaseDuration.inMilliseconds;
    final progress = denominator <= 0
        ? 1.0
        : ((cycleElapsed - phaseStart) / denominator).clamp(0.0, 1.0);
    return _PranayamaPhaseSnapshot(
      label: label,
      progress: progress,
      breathCount: elapsedMilliseconds ~/ cycleMilliseconds,
      cycleProgress: cycleProgress,
    );
  }

  final phases = [
    ('Inhale', segment.inBreath),
    ('Hold', segment.firstHold),
    ('Exhale', segment.outBreath),
    ('Hold', segment.secondHold),
  ];

  var phaseStart = 0;
  for (final (label, duration) in phases) {
    if (duration == Duration.zero) {
      continue;
    }
    final phaseEnd = phaseStart + duration.inMilliseconds;
    if (cursor < phaseEnd) {
      return snapshotFor(label, duration, phaseStart);
    }
    phaseStart = phaseEnd;
  }

  return _PranayamaPhaseSnapshot(
    label: 'Inhale',
    progress: 0,
    breathCount: elapsedMilliseconds ~/ cycleMilliseconds,
    cycleProgress: cycleProgress,
  );
}

String _pranayamaPresetDetails(PranayamaPreset preset) {
  final duration = preset.isInfinite
      ? 'Infinite'
      : _formatDuration(preset.duration!);
  final rhythm = preset.segments.length == 1
      ? _pranayamaSegmentRhythm(preset.firstSegment)
      : '${preset.segments.length} segments';
  final note = preset.note.trim();
  return note.isEmpty ? '$duration | $rhythm' : '$duration | $note';
}

String _pranayamaSegmentRhythm(PranayamaSegment segment) {
  return '${segment.inBreath.inSeconds}-${segment.firstHold.inSeconds}-${segment.outBreath.inSeconds}-${segment.secondHold.inSeconds}';
}

String _formatTimerDisplay(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }

  return '$minutes:$seconds';
}
