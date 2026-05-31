import 'dart:math';
import 'package:flutter/material.dart';

// Deterministic random number generator (Linear Congruential Generator)
class LCG {
  int seed;
  LCG(this.seed);
  
  double nextDouble() {
    seed = (1103515245 * seed + 12345) & 0x7fffffff;
    return seed / 2147483647.0;
  }
}

class WaveformPlaceholder extends StatelessWidget {
  final double height;
  final bool isPlaying;
  final double progress; // Value between 0.0 and 1.0
  final String? seedString;

  const WaveformPlaceholder({
    super.key,
    this.height = 80,
    this.isPlaying = false,
    this.progress = 0.3,
    this.seedString,
  });

  double _getEnvelope(double x) {
    if (x < 0.08) {
      // Intro: fade in
      return 0.2 + (x / 0.08) * 0.3;
    } else if (x < 0.28) {
      // Verse 1: medium
      return 0.5 + sin((x - 0.08) * 10) * 0.1;
    } else if (x < 0.45) {
      // Chorus 1: loud
      return 0.85 + cos((x - 0.28) * 8) * 0.15;
    } else if (x < 0.60) {
      // Verse 2: medium
      return 0.55 + sin((x - 0.45) * 12) * 0.1;
    } else if (x < 0.78) {
      // Chorus 2: loud
      return 0.9 + cos((x - 0.60) * 7) * 0.1;
    } else if (x < 0.88) {
      // Bridge: quiet/build-up
      return 0.4 + ((x - 0.78) / 0.1) * 0.4;
    } else if (x < 0.96) {
      // Chorus 3 / Outro climax: very loud
      return 0.95;
    } else {
      // Outro: fade out
      return 0.95 * (1.0 - (x - 0.96) / 0.04);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Generate deterministic seed from seedString
    final int seed = seedString != null ? seedString.hashCode : 42;
    final lcg = LCG(seed);
    const int barCount = 60;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131022),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(barCount, (index) {
              final double barProgress = index / barCount;
              final bool isPassed = barProgress <= progress;

              // Compute a realistic amplitude value using song structure envelope and LCG
              final double envelope = _getEnvelope(barProgress);
              final double rand = 0.4 + 0.6 * lcg.nextDouble();
              final double heightFactor = (envelope * rand).clamp(0.1, 1.0);

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  height: height * heightFactor * 0.8,
                  decoration: BoxDecoration(
                    gradient: isPassed
                        ? const LinearGradient(
                            colors: [Color(0xFFFF2E93), Color(0xFFFF8C37)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          )
                        : null,
                    color: !isPassed
                        ? Colors.white.withValues(alpha: 0.1)
                        : null,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          // Vertical progress indicator line
          Align(
            alignment: Alignment(progress * 2 - 1, 0),
            child: Container(
              width: 3,
              height: height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF2E93), Color(0xFFFF8C37)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
