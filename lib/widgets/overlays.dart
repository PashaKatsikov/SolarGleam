import 'package:flutter/material.dart';

import '../game/slot_math.dart';
import '../theme/gleam_theme.dart';

class PaytableSheet extends StatelessWidget {
  const PaytableSheet({
    super.key,
    required this.bet,
    required this.onClose,
    this.title = 'Playable',
  });

  final int bet;
  final VoidCallback onClose;
  final String title;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final lineBet = bet ~/ paylineCount;
    return _Panel(
      title: title,
      onClose: onClose,
      child: SizedBox(
        height: height * 0.62,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          children: [
            Text(
              'Pays for a bet of ${formatGleam(bet)} gleam. '
              'Four reels, four rows, 20 paylines. Wins run from the left, '
              'three or more of a kind. Wild replaces every symbol except Bonus. '
              'Gleam is virtual and has no cash value.',
              style: cinzel(
                13,
                GleamColors.ivory,
                weight: 600,
                height: 1.45,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 14),
            for (final symbol in paytableOrder) _row(symbol, lineBet),
            const SizedBox(height: 8),
            Text(
              '3 Bonus symbols anywhere award 8 free spins and 5× the bet. '
              '4 or more award 12 free spins and 20× the bet. '
              'Line wins during free spins are doubled.',
              style: cinzel(
                13,
                GleamColors.goldLight,
                weight: 600,
                height: 1.45,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(SlotSymbol symbol, int lineBet) {
    final def = symbolDefs[symbol]!;
    final detail = symbol == SlotSymbol.bonus
        ? '3 · 8 free spins\n4 · 12 free spins'
        : '3 · ${formatGleam(def.pay3 * lineBet)}\n4 · ${formatGleam(def.pay4 * lineBet)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: Image.asset(def.asset, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              def.name,
              style: cinzel(16, GleamColors.goldLight, weight: 700),
            ),
          ),
          Text(
            detail,
            textAlign: TextAlign.right,
            style: rajdhani(18, GleamColors.ivory, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class RefillSheet extends StatelessWidget {
  const RefillSheet({
    super.key,
    required this.onRestore,
    required this.onClose,
  });

  final VoidCallback onRestore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Solar Vault',
      onClose: onClose,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The vault is empty. Restore 10,000 gleam and keep playing. '
              'Gleam cannot be exchanged for money.',
              style: cinzel(
                14,
                GleamColors.ivory,
                weight: 600,
                height: 1.45,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 18),
            GoldTextButton(label: 'Restore gleam', onPressed: onRestore),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.onClose,
    required this.child,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Material(
      color: const Color(0xC006040E),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: height * 0.86,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xF20C1022),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: GleamColors.gold, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66F0A020), blurRadius: 28),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: cinzel(22, GleamColors.goldLight),
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(
                              Icons.close,
                              color: GleamColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GoldTextButton extends StatelessWidget {
  const GoldTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF8A5A12), Color(0xFFF8D78A), Color(0xFFC8882B)],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x88F0A020), blurRadius: 16),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Text(
            label,
            style: cinzel(15, GleamColors.ink, letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}
