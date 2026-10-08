import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import '../game/game_settings.dart';

enum Sfx {
  click('click', 0.55),
  open('open', 0.7),
  close('close', 0.6),
  select('select', 0.8),
  success('success', 0.85),
  error('error', 0.8),
  shift('shift', 0.8),
  energy('energy', 0.9),
  complete('complete', 0.9),
  restore('restore', 0.95),
  orbUnlock('orb_unlock', 0.9),
  reward('reward', 0.8),
  areaUnlock('area_unlock', 0.9),
  teleport('teleport', 0.8);

  const Sfx(this.file, this.gain);

  final String file;
  final double gain;
}

/// Effects and the menu ambience. Every call is safe to make when the audio
/// engine is missing (tests, unsupported hosts): it simply does nothing.
class Sound {
  Sound._() {
    GameSettings.instance.addListener(_syncMusic);
  }

  static final instance = Sound._();

  static const _poolSize = 6;

  /// Off under `flutter test`, where no audio engine exists.
  bool enabled = !Platform.environment.containsKey('FLUTTER_TEST');

  final List<AudioPlayer> _pool = [];
  var _next = 0;
  AudioPlayer? _ambient;
  var _ambientWanted = false;
  var _ready = false;

  Future<void> _prepare() async {
    if (_ready || !enabled) return;
    _ready = true;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {},
          ),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      for (var i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.stop);
        _pool.add(player);
      }
    } catch (_) {
      enabled = false;
    }
  }

  Future<void> play(Sfx sfx, {double volume = 1}) async {
    final settings = GameSettings.instance;
    if (!enabled || !settings.sfx) return;
    try {
      await _prepare();
      if (_pool.isEmpty) return;
      final player = _pool[_next];
      _next = (_next + 1) % _pool.length;
      await player.stop();
      await player.play(
        AssetSource('audio/${sfx.file}.mp3'),
        volume: (sfx.gain * volume * settings.sfxVolume).clamp(0.0, 1.0),
      );
    } catch (_) {
      // A missing or busy player must never break the game.
    }
  }

  Future<void> startAmbient() async {
    _ambientWanted = true;
    final settings = GameSettings.instance;
    if (!enabled || !settings.music) return;
    try {
      await _prepare();
      var player = _ambient;
      if (player == null) {
        player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.loop);
        _ambient = player;
      }
      if (player.state != PlayerState.playing) {
        await player.play(
          AssetSource('audio/ambient.mp3'),
          volume: _musicLevel,
        );
      } else {
        await player.setVolume(_musicLevel);
      }
    } catch (_) {}
  }

  Future<void> stopAmbient() async {
    _ambientWanted = false;
    try {
      await _ambient?.pause();
    } catch (_) {}
  }

  double get _musicLevel => (0.55 * GameSettings.instance.musicVolume).clamp(0.0, 1.0);

  void _syncMusic() {
    if (!enabled) return;
    final settings = GameSettings.instance;
    if (!settings.music) {
      _ambient?.pause();
    } else if (_ambientWanted) {
      startAmbient();
    }
  }
}
