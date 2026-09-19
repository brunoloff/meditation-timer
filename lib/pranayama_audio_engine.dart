part of 'main.dart';

const _pranayamaAudioStartLead = Duration(milliseconds: 90);
const _pranayamaAudioLookAhead = Duration(seconds: 45);
const _pranayamaAudioMaxQueuedCycles = 24;
const _pranayamaTonePlaybackVolume = 0.65;
const _pranayamaTransitionCancelTolerance = Duration(milliseconds: 75);

class _PranayamaAudioEngine {
  final _SoLoudAudioBackend _backend = _SoLoudAudioBackend.instance;
  final Map<String, Future<AudioSource?>> _sourceFutures =
      <String, Future<AudioSource?>>{};
  final Map<String, AudioSource> _sources = <String, AudioSource>{};

  bool _hasClockAnchor = false;
  Duration _anchorElapsed = Duration.zero;
  Duration _anchorEngineTime = Duration.zero;

  bool get hasClockAnchor => _hasClockAnchor && _isReady;

  bool get _isReady => _backend.isReady;

  SoLoud? get _playerOrNull => _backend.playerOrNull;

  Future<bool> ensureReady() => _backend.ensureReady();

  Duration? get currentElapsed {
    if (!hasClockAnchor) {
      return null;
    }

    final player = _playerOrNull;
    if (player == null || !player.isInitialized) {
      return null;
    }

    final engineTime = player.getEngineTime();
    if (engineTime < _anchorEngineTime) {
      return _anchorElapsed;
    }

    final elapsed = _anchorElapsed + (engineTime - _anchorEngineTime);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Duration? get currentEngineTime {
    final player = _playerOrNull;
    if (player == null || !player.isInitialized) {
      return null;
    }
    return player.getEngineTime();
  }

  void setClockAnchor({
    required Duration elapsed,
    required Duration engineTime,
  }) {
    _anchorElapsed = elapsed.isNegative ? Duration.zero : elapsed;
    _anchorEngineTime = engineTime;
    _hasClockAnchor = true;
  }

  void releaseClockAnchor() {
    _hasClockAnchor = false;
    _anchorElapsed = Duration.zero;
    _anchorEngineTime = Duration.zero;
  }

  Duration? engineTimeForElapsed(Duration elapsed) {
    if (!hasClockAnchor) {
      return null;
    }
    return _anchorEngineTime + (elapsed - _anchorElapsed);
  }

  Future<AudioSource?> sourceForClip({
    required String key,
    required _PranayamaToneClip clip,
  }) async {
    final cachedSource = _sources[key];
    final player = _playerOrNull;
    if (cachedSource != null &&
        player != null &&
        player.isInitialized &&
        player.isValidAudioSource(cachedSource)) {
      return cachedSource;
    }

    final sourceFuture = _sourceFutures.putIfAbsent(key, () async {
      if (!await ensureReady()) {
        return null;
      }

      try {
        final readyPlayer = _playerOrNull;
        if (readyPlayer == null) {
          return null;
        }

        final source = await readyPlayer.loadMem(
          'pranayama-tone-$key.wav',
          clip.bytes,
          mode: LoadMode.memory,
        );
        _sources[key] = source;
        return source;
      } on Object catch (error) {
        debugPrint('Could not load pranayama tone into SoLoud: $error');
        return null;
      } finally {
        _sourceFutures.remove(key);
      }
    });

    return sourceFuture;
  }

  SoundHandle? playScheduled({
    required AudioSource source,
    required Duration atEngineTime,
    required Duration duration,
  }) {
    if (!_isReady || duration <= Duration.zero) {
      return null;
    }

    try {
      final player = _playerOrNull;
      if (player == null || !player.isInitialized) {
        return null;
      }

      final handle = player.playScheduled(
        source,
        atEngineTime,
        duration: duration,
        volume: _pranayamaTonePlaybackVolume,
      );
      return handle;
    } on Object catch (error) {
      debugPrint('Could not schedule pranayama tone: $error');
      return null;
    }
  }

  Future<void> stopHandles(Iterable<SoundHandle> handles) async {
    if (!_isReady) {
      return;
    }
    final player = _playerOrNull;
    if (player == null || !player.isInitialized) {
      return;
    }

    final handleList = handles.where((handle) => !handle.isError).toSet();
    if (handleList.isEmpty) {
      return;
    }

    final engineTime = player.getEngineTime();
    for (final handle in handleList) {
      try {
        // Handles created by playScheduled can still be waiting for their
        // engine-clock start time. stopScheduled explicitly invalidates all
        // future voices before any per-handle stop Future can delay cleanup.
        player.stopScheduled(handle, engineTime);
      } on Object {
        // Some handles may already have ended or been stopped by a previous
        // transition. The follow-up stop() call is allowed to be best-effort.
      }
    }

    for (final handle in handleList) {
      if (handle.isError) {
        continue;
      }
      unawaited(
        player.stop(handle).catchError((_) {
          // The handle may already have ended naturally. That is harmless.
        }),
      );
    }
  }

  void stopHandlesAt(Iterable<SoundHandle> handles, Duration engineTime) {
    if (!_isReady) {
      return;
    }
    final player = _playerOrNull;
    if (player == null || !player.isInitialized) {
      return;
    }

    for (final handle in handles.where((handle) => !handle.isError).toSet()) {
      try {
        player.stopScheduled(handle, engineTime);
      } on Object {
        // Handles may already be stopped by a newer transition.
      }
    }
  }

  Future<void> disposeSources() async {
    if (!_isReady) {
      _sources.clear();
      return;
    }
    final player = _playerOrNull;
    if (player == null || !player.isInitialized) {
      _sources.clear();
      return;
    }

    for (final source in List<AudioSource>.of(_sources.values)) {
      try {
        await player.disposeSource(source);
      } on Object {
        // Sources can already be gone after hot restart or engine shutdown.
      }
    }
    _sources.clear();
  }

  Future<void> dispose() async {
    releaseClockAnchor();
    await disposeSources();
  }
}

class _ScheduledPranayamaCycle {
  const _ScheduledPranayamaCycle({
    required this.handle,
    required this.timelineId,
    required this.engineStartTime,
    required this.engineEndTime,
    required this.startElapsed,
    required this.endElapsed,
  });

  final SoundHandle handle;
  final String timelineId;
  final Duration engineStartTime;
  final Duration engineEndTime;
  final Duration startElapsed;
  final Duration endElapsed;
}
