import 'package:flutter_test/flutter_test.dart';
import 'package:solar_gleam/game/native_math.dart';

/// The orb indices that solve a puzzle, derived only from what the player sees.
List<int> answerOf(PuzzleSpec spec) {
  final seq = <int>[];
  for (final e in spec.events) {
    switch (e.kind) {
      case PreviewKind.real:
        seq.add(e.value);
      case PreviewKind.glyph:
        seq.add(spec.orbs.indexWhere((o) => o.glyph == e.value));
      case PreviewKind.ghost:
        break;
    }
  }
  return spec.modes & 2 != 0 ? seq.reversed.toList() : seq;
}

void main() {
  final core = NativeMath.instance;

  test('every level builds a puzzle that its visible answer solves', () {
    for (var r = 0; r < 6; r++) {
      for (var l = 0; l < 8; l++) {
        for (var run = 0; run < 12; run++) {
          final spec = core.start(r, l)!;
          expect(spec.orbs.length, greaterThanOrEqualTo(3));
          final answer = answerOf(spec);
          expect(answer.length, spec.sequenceLength, reason: 'region $r level $l');
          TapOutcome? last;
          for (final orb in answer) {
            last = core.tap(orb).outcome;
          }
          expect(last, TapOutcome.solved, reason: 'region $r level $l');
          final reward = core.finish(elapsedMs: 6000, repeat: false)!;
          expect(reward.stars, inInclusiveRange(1, 3));
          expect(reward.energy, greaterThan(0));
        }
      }
    }
  });

  test('a wrong tap costs an attempt and never solves', () {
    final spec = core.start(0, 0)!;
    final answer = answerOf(spec);
    final wrong = (answer.first + 1) % spec.orbs.length;
    final result = core.tap(wrong);
    expect(result.outcome, TapOutcome.wrong);
    expect(result.attemptsLeft, spec.attempts - 1);
  });

  test('regions open in order and cost energy', () {
    expect(core.quote(0, previousDone: 8, energy: 0).status, UnlockStatus.free);
    expect(core.quote(1, previousDone: 3, energy: 99999).status, UnlockStatus.locked);
    expect(core.quote(1, previousDone: 8, energy: 0).status, UnlockStatus.short);
    final ok = core.quote(1, previousDone: 8, energy: 99999);
    expect(ok.status, UnlockStatus.payable);
    expect(ok.cost, greaterThan(0));
  });
}
