part of 'main.dart';

const _soloudOutputSampleRate = 44100;
// SoLoud can run with very small buffers, but this app values clean sustained
// tones over game-like trigger latency. A larger mixer buffer prevents the
// faint crackle that low-latency underruns can sound like on phones/laptops.
const _soloudOutputBufferSize = 2048;

class _SoLoudAudioBackend {
  _SoLoudAudioBackend._();

  static final _SoLoudAudioBackend instance = _SoLoudAudioBackend._();

  SoLoud? _soLoud;
  Future<bool>? _initialization;
  bool _disabled = false;

  bool get isReady {
    final player = playerOrNull;
    return player != null && player.isInitialized;
  }

  SoLoud? get playerOrNull {
    if (_disabled) {
      return null;
    }

    try {
      return _soLoud ??= SoLoud.instance;
    } on Object {
      _disabled = true;
      return null;
    }
  }

  Future<bool> ensureReady() async {
    final player = playerOrNull;
    if (player == null) {
      return false;
    }
    if (player.isInitialized) {
      return true;
    }

    final initialization = _initialization ??= _initialize(player);
    return initialization;
  }

  Future<bool> _initialize(SoLoud player) async {
    try {
      await player.init(
        sampleRate: _soloudOutputSampleRate,
        bufferSize: _soloudOutputBufferSize,
        channels: Channels.stereo,
        lowLatency: true,
      );
      return true;
    } on Object catch (error) {
      _disabled = true;
      debugPrint('Could not initialize SoLoud audio: $error');
      return false;
    } finally {
      _initialization = null;
    }
  }
}

class _BellAudioEngine {
  _BellAudioEngine._();

  static final _BellAudioEngine instance = _BellAudioEngine._();

  final _SoLoudAudioBackend _backend = _SoLoudAudioBackend.instance;
  final Map<String, Future<AudioSource?>> _sourceFutures =
      <String, Future<AudioSource?>>{};
  final Map<String, AudioSource> _sources = <String, AudioSource>{};
  final Map<String, SoundHandle> _groupHandles = <String, SoundHandle>{};

  Future<SoundHandle?> play(
    BellSound sound, {
    String? group,
    bool replaceGroup = false,
  }) async {
    if (replaceGroup && group != null) {
      await stopGroup(group);
    }

    final source = await _sourceForSound(sound);
    if (source == null) {
      return null;
    }

    final player = _backend.playerOrNull;
    if (player == null || !player.isInitialized) {
      return null;
    }

    try {
      final handle = player.play(source, volume: 1);
      if (group != null) {
        _groupHandles[group] = handle;
      }
      return handle;
    } on Object catch (error) {
      debugPrint('Could not play bell sound with SoLoud: $error');
      return null;
    }
  }

  Future<void> stopGroup(String group) async {
    final handle = _groupHandles.remove(group);
    if (handle == null || handle.isError || !_backend.isReady) {
      return;
    }

    final player = _backend.playerOrNull;
    if (player == null || !player.isInitialized) {
      return;
    }

    try {
      await player.stop(handle);
    } on Object {
      // Handles disappear once a sound finishes naturally.
    }
  }

  Future<AudioSource?> _sourceForSound(BellSound sound) async {
    final assetKey = _flutterAssetKeyForBellPath(sound.assetPath);
    final cachedSource = _sources[assetKey];
    final player = _backend.playerOrNull;
    if (cachedSource != null &&
        player != null &&
        player.isInitialized &&
        player.isValidAudioSource(cachedSource)) {
      return cachedSource;
    }

    final sourceFuture = _sourceFutures.putIfAbsent(assetKey, () async {
      if (!await _backend.ensureReady()) {
        return null;
      }

      try {
        final readyPlayer = _backend.playerOrNull;
        if (readyPlayer == null || !readyPlayer.isInitialized) {
          return null;
        }

        final source = await readyPlayer.loadAsset(
          assetKey,
          mode: LoadMode.memory,
        );
        _sources[assetKey] = source;
        return source;
      } on Object catch (error) {
        debugPrint('Could not load bell sound into SoLoud: $error');
        return null;
      } finally {
        _sourceFutures.remove(assetKey);
      }
    });

    return sourceFuture;
  }
}

String _flutterAssetKeyForBellPath(String storedAssetPath) {
  if (storedAssetPath.startsWith('assets/')) {
    return storedAssetPath;
  }

  // Timer presets keep bell paths in the old audioplayers AssetSource format
  // ("audio/bells/foo.mp3"). Flutter's root asset bundle and SoLoud's
  // loadAsset() expect the full pubspec asset key ("assets/audio/bells/foo.mp3").
  if (storedAssetPath.startsWith('audio/')) {
    return 'assets/$storedAssetPath';
  }

  return storedAssetPath;
}

String bellAssetKeyForTesting(String storedAssetPath) {
  return _flutterAssetKeyForBellPath(storedAssetPath);
}
