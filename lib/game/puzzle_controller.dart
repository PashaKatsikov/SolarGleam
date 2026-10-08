import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../audio/sound.dart';
import 'game_settings.dart';
import 'native_math.dart';
import 'progress.dart';

enum PuzzlePhase { briefing, watching, shifting, input, solved, failed }

class _Flash {
  const _Flash(this.start, this.duration, this.ghost, this.strength);

  final int start;
  final int duration;
  final bool ghost;
  final double strength;
}

/// Runs one puzzle: plays the preview, forwards taps to the Rust core and
/// keeps the transient visual state (flashes, hint ring, shake).
class PuzzleController extends ChangeNotifier {
  PuzzleController(this.region, this.level, {NativeMath? core})
    : core = core ?? NativeMath.instance;

  final int region;
  final int level;
  final NativeMath core;

  /// Ticks while anything animates, so orbs rebuild without the whole screen.
  final ValueNotifier<int> frame = ValueNotifier<int>(0);

  late PuzzleSpec spec;
  var phase = PuzzlePhase.briefing;
  var slotOf = <int>[];
  var entered = 0;
  var attemptsLeft = 0;
  var hintsLeft = 0;
  var replaysLeft = 0;
  int? tokenGlyph;
  var wrongPulse = 0;
  var _lastWrong = false;
  var _paused = false;
  var _run = 0;
  var _disposed = false;

  Applied? applied;
  RewardSpec? reward;

  final Stopwatch _clock = Stopwatch()..start();
  final Stopwatch _input = Stopwatch();
  Timer? _timer;

  List<_Flash?> _flashes = [];
  _Flash? _coreFlash;
  int? _burstAt;
  int? _hintOrb;
  int _hintUntil = 0;
  int? _shakeOrb;
  int _shakeStart = 0;

  int get _now => _clock.elapsedMilliseconds;

  bool get lastTapWrong => _lastWrong;
  bool get paused => _paused;
  int get mistakes => spec.attempts - attemptsLeft;
  bool get canAct => phase == PuzzlePhase.input;

  /// Builds the puzzle in the core. False when the level does not exist.
  bool begin() {
    final next = core.start(region, level);
    if (next == null) return false;
    spec = next;
    _reset();
    return true;
  }

  void _reset() {
    _run++;
    slotOf = [for (final orb in spec.orbs) orb.slot];
    attemptsLeft = spec.attempts;
    hintsLeft = spec.hints;
    replaysLeft = spec.replays;
    entered = 0;
    phase = PuzzlePhase.briefing;
    tokenGlyph = null;
    _flashes = List.filled(spec.orbs.length, null);
    _coreFlash = null;
    _burstAt = null;
    _hintOrb = null;
    _shakeOrb = null;
    _lastWrong = false;
    applied = null;
    reward = null;
    _input
      ..stop()
      ..reset();
    _paused = false;
    _changed();
  }

  /// Starts a fresh puzzle on the same level.
  bool restart() {
    final ok = begin();
    if (ok) startPreview();
    return ok;
  }

  // Visual state -----------------------------------------------------------------

  double _envelope(_Flash? flash) {
    if (flash == null) return 0;
    final t = _now - flash.start;
    if (t < 0 || t > flash.duration) return 0;
    const attack = 70;
    const release = 170;
    double v;
    if (t < attack) {
      v = t / attack;
    } else if (t > flash.duration - release) {
      v = (flash.duration - t) / release;
    } else {
      v = 1;
    }
    v = v.clamp(0.0, 1.0);
    return v * v * (3 - 2 * v) * flash.strength;
  }

  double litOf(int orb) => _envelope(_flashes[orb]);

  bool ghostOf(int orb) {
    final f = _flashes[orb];
    return f != null && f.ghost && _envelope(f) > 0;
  }

  /// 0 when idle, up to 1 while an orb is signalled.
  bool get previewActive => phase == PuzzlePhase.watching || phase == PuzzlePhase.shifting;

  double hintOf(int orb) {
    if (_hintOrb != orb || _now > _hintUntil) return 0;
    return 0.1 + 0.9 * (0.5 + 0.5 * math.sin(_now * 0.012));
  }

  double shakeOf(int orb) {
    if (_shakeOrb != orb) return 0;
    final t = (_now - _shakeStart) / 460;
    return t >= 1 ? 0 : t.clamp(0.01, 1.0);
  }

  /// Strength of the core glow: glyph tokens and the final flare.
  double coreLevel() {
    var v = _envelope(_coreFlash);
    final burst = _burstAt;
    if (burst != null) {
      final t = (_now - burst) / 1800;
      if (t >= 0 && t < 1) v = math.max(v, math.sin(t * math.pi).clamp(0.0, 1.0));
      if (t >= 1) v = math.max(v, 0.55);
    }
    return v;
  }

  bool _animating() {
    final t = _now;
    for (final f in _flashes) {
      if (f != null && t - f.start <= f.duration) return true;
    }
    final core = _coreFlash;
    if (core != null && t - core.start <= core.duration) return true;
    if (_burstAt != null && t - _burstAt! < 1900) return true;
    if (_hintOrb != null && t <= _hintUntil) return true;
    if (_shakeOrb != null && t - _shakeStart < 480) return true;
    return false;
  }

  void _pump() {
    if (_disposed) return;
    _timer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_disposed) return;
      frame.value++;
      if (!_animating()) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  void _changed() {
    if (_disposed) return;
    notifyListeners();
    frame.value++;
    _pump();
  }

  void _flash(int orb, int ms, {bool ghost = false, double strength = 1}) {
    if (orb < 0 || orb >= _flashes.length) return;
    _flashes[orb] = _Flash(_now, ms, ghost, strength);
  }

  // Timing ---------------------------------------------------------------------------

  /// Waits `ms` of unpaused time. False when the run was cancelled meanwhile.
  Future<bool> _wait(int ms, int token) async {
    var left = ms;
    while (left > 0) {
      if (token != _run || _disposed) return false;
      final step = math.min(left, 40);
      await Future<void>.delayed(Duration(milliseconds: step));
      if (!_paused) left -= step;
    }
    return token == _run && !_disposed;
  }

  // Flow ---------------------------------------------------------------------------

  /// Plays the preview, then hands over to the player.
  Future<void> startPreview({bool replay = false}) async {
    final token = ++_run;
    final sound = Sound.instance;
    final settings = GameSettings.instance;
    phase = PuzzlePhase.watching;
    entered = 0;
    _hintOrb = null;
    tokenGlyph = null;
    _lastWrong = false;

    final home = [for (final orb in spec.orbs) orb.slot];
    final moved = !listEquals(slotOf, home);
    slotOf = home;
    _changed();
    if (moved) {
      sound.play(Sfx.shift, volume: 0.6);
      if (!await _wait(700, token)) return;
    }
    if (!await _wait(replay ? 450 : 750, token)) return;

    for (final event in spec.events) {
      switch (event.kind) {
        case PreviewKind.real:
          _flash(event.value, spec.flashMs);
          sound.play(Sfx.select);
          settings.light();
        case PreviewKind.ghost:
          _flash(event.value, (spec.flashMs * 0.85).round(), ghost: true, strength: 0.9);
          sound.play(Sfx.shift, volume: 0.4);
        case PreviewKind.glyph:
          tokenGlyph = event.value;
          _coreFlash = _Flash(_now, spec.flashMs, false, 1);
          sound.play(Sfx.select);
          settings.light();
      }
      _changed();
      if (!await _wait(spec.flashMs, token)) return;
      tokenGlyph = null;
      _changed();
      if (!await _wait(spec.gapMs, token)) return;
    }

    if (spec.shifts) {
      phase = PuzzlePhase.shifting;
      _changed();
      if (!await _wait(650, token)) return;
      slotOf = List.of(spec.shiftTo);
      sound.play(Sfx.shift);
      settings.medium();
      _changed();
      if (!await _wait(1100, token)) return;
    }

    phase = PuzzlePhase.input;
    _input
      ..reset()
      ..start();
    _changed();
  }

  void tapOrb(int orb) {
    if (phase != PuzzlePhase.input || _paused) return;
    final sound = Sound.instance;
    final settings = GameSettings.instance;
    final result = core.tap(orb);
    switch (result.outcome) {
      case TapOutcome.ignored:
        return;
      case TapOutcome.right:
        entered = result.entered;
        _lastWrong = false;
        _flash(orb, 300, strength: 0.85);
        sound.play(Sfx.select);
        settings.tick();
      case TapOutcome.wrong:
        entered = 0;
        attemptsLeft = result.attemptsLeft;
        _lastWrong = true;
        wrongPulse++;
        _flash(orb, 420, ghost: true);
        _shakeOrb = orb;
        _shakeStart = _now;
        sound.play(Sfx.error);
        settings.heavy();
      case TapOutcome.lost:
        entered = 0;
        attemptsLeft = 0;
        _lastWrong = true;
        wrongPulse++;
        _flash(orb, 420, ghost: true);
        _shakeOrb = orb;
        _shakeStart = _now;
        _input.stop();
        phase = PuzzlePhase.failed;
        sound.play(Sfx.error);
        settings.heavy();
      case TapOutcome.solved:
        entered = result.length;
        _flash(orb, 380, strength: 0.9);
        _input.stop();
        _solve();
    }
    _changed();
  }

  void _solve() {
    final repeat = Progress.instance.stars[region][level] > 0;
    final won = core.finish(elapsedMs: _input.elapsedMilliseconds, repeat: repeat);
    phase = PuzzlePhase.solved;
    _burstAt = _now;
    Sound.instance.play(Sfx.energy);
    GameSettings.instance.heavy();
    if (won != null) {
      reward = won;
      applied = Progress.instance.record(spec, won);
    }
  }

  /// Points at the next orb to tap. Returns false when no hint is left.
  bool useHint() {
    if (phase != PuzzlePhase.input || hintsLeft <= 0) return false;
    final orb = core.hint();
    if (orb < 0) return false;
    hintsLeft--;
    _hintOrb = orb;
    _hintUntil = _now + 2200;
    Sound.instance.play(Sfx.orbUnlock, volume: 0.7);
    GameSettings.instance.medium();
    _changed();
    return true;
  }

  /// Watch the preview once more. The answer restarts from the first orb.
  bool useReplay() {
    if (phase != PuzzlePhase.input || replaysLeft <= 0) return false;
    if (!core.replay()) return false;
    replaysLeft--;
    _input.stop();
    startPreview(replay: true);
    return true;
  }

  void pause() {
    if (_paused) return;
    _paused = true;
    _input.stop();
    _changed();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    if (phase == PuzzlePhase.input) _input.start();
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _run++;
    _timer?.cancel();
    frame.dispose();
    super.dispose();
  }
}
