part of 'main.dart';

class SoundSelectionResult {
  const SoundSelectionResult(this.sound);

  final BellSound? sound;
}

class SelectSoundScreen extends StatefulWidget {
  const SelectSoundScreen({super.key, required this.allowNone});

  final bool allowNone;

  @override
  State<SelectSoundScreen> createState() => _SelectSoundScreenState();
}

class _SelectSoundScreenState extends State<SelectSoundScreen> {
  final Set<String> _selectedTags = <String>{};
  final _BellAudioEngine _bellAudioEngine = _BellAudioEngine.instance;
  late final String _previewAudioGroup =
      'sound-preview-${identityHashCode(this)}';
  late final Future<List<BellSound>> _soundsFuture = _loadDefaultBellSounds();

  @override
  void dispose() {
    unawaited(_bellAudioEngine.stopGroup(_previewAudioGroup));
    super.dispose();
  }

  Future<void> _playSound(BellSound sound) async {
    await _bellAudioEngine.play(
      sound,
      group: _previewAudioGroup,
      replaceGroup: true,
    );
  }

  void _selectSound(BellSound? sound) {
    Navigator.of(context).pop(SoundSelectionResult(sound));
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _SelectSoundTitleBar(onCancel: () => Navigator.of(context).pop()),
            const Divider(height: 1, thickness: 1, color: _dividerColor),
            Expanded(
              child: FutureBuilder<List<BellSound>>(
                future: _soundsFuture,
                builder: (context, snapshot) {
                  final sounds = snapshot.data ?? _bellSounds;
                  final tags = _allSoundTags(sounds);
                  final visibleSounds = _filteredSounds(sounds, _selectedTags);

                  return ListView(
                    key: const ValueKey('select-sound-list'),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      if (tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in tags)
                              FilterChip(
                                key: ValueKey('sound-tag-$tag'),
                                label: Text(tag),
                                selected: _selectedTags.contains(tag),
                                onSelected: (_) => _toggleTag(tag),
                                backgroundColor: const Color(0xFF19191D),
                                selectedColor: const Color(0xFF78BFA7),
                                checkmarkColor: Colors.black,
                                labelStyle: TextStyle(
                                  color: _selectedTags.contains(tag)
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                                side: const BorderSide(color: _dividerColor),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (widget.allowNone) ...[
                        _SoundListRow(
                          key: const ValueKey('sound-option-none'),
                          title: 'None',
                          subtitle: 'Do not play a bell here',
                          tags: const [],
                          onSelect: () => _selectSound(null),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (visibleSounds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 36),
                          child: Center(
                            child: Text(
                              'No sounds match these tags',
                              style: TextStyle(
                                color: _mutedTextColor,
                                fontSize: 16,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        )
                      else
                        for (final sound in visibleSounds) ...[
                          _SoundListRow(
                            key: ValueKey('sound-option-${sound.assetPath}'),
                            title: sound.name,
                            subtitle: sound.info.isEmpty
                                ? sound.assetPath.split('/').last
                                : sound.info,
                            tags: sound.tags,
                            onSelect: () => _selectSound(sound),
                            onPlay: () => _playSound(sound),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectSoundTitleBar extends StatelessWidget {
  const _SelectSoundTitleBar({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const ValueKey('cancel-sound-selection-button'),
              onPressed: onCancel,
              color: Colors.white,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          const Text(
            'Select sound',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundListRow extends StatelessWidget {
  const _SoundListRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.onSelect,
    this.onPlay,
  });

  final String title;
  final String subtitle;
  final List<String> tags;
  final VoidCallback onSelect;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF19191D),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedTextColor,
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in tags)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF101012),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: _dividerColor),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Color(0xFFCCCCD2),
                                    fontSize: 12,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (onPlay != null) ...[
                const SizedBox(width: 12),
                IconButton(
                  key: ValueKey('play-sound-$title'),
                  onPressed: onPlay,
                  color: Colors.white,
                  tooltip: 'Play sound',
                  icon: const Icon(Icons.play_arrow_rounded, size: 30),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<List<BellSound>> _loadDefaultBellSounds() async {
  try {
    final jsonText = await rootBundle.loadString(
      'assets/audio/bells/default-sounds.json',
    );
    final decoded = jsonDecode(jsonText);
    if (decoded is! List) {
      return _bellSounds;
    }

    final sounds = <BellSound>[];
    for (final item in decoded) {
      if (item is! Map<String, Object?>) {
        continue;
      }

      final title = item['title'];
      final filename = item['filename'];
      if (title is! String || filename is! String) {
        continue;
      }

      final tags = item['tags'];
      final info = item['info'];
      final url = item['url'];
      sounds.add(
        BellSound(
          name: title,
          assetPath: '$_bellAssetRoot/$filename',
          tags: tags is List
              ? [
                  for (final tag in tags)
                    if (tag is String) tag,
                ]
              : const [],
          info: info is String ? info : '',
          url: url is String ? url : '',
        ),
      );
    }

    return sounds.isEmpty ? _bellSounds : sounds;
  } on Object {
    return _bellSounds;
  }
}

List<String> _allSoundTags(List<BellSound> sounds) {
  return {
    for (final sound in sounds)
      for (final tag in sound.tags) tag,
  }.toList()..sort();
}

List<BellSound> _filteredSounds(List<BellSound> sounds, Set<String> tags) {
  if (tags.isEmpty) {
    return sounds;
  }

  return [
    for (final sound in sounds)
      if (tags.every(sound.tags.contains)) sound,
  ];
}
