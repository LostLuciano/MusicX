import 'package:flutter/material.dart';

/// Centralised design-token provider.
/// All screens read from this to ensure consistent look for each style.
class AppUITheme {
  final int style; // 0 = Spotify, 1 = Apple Music
  final Color primary;

  const AppUITheme({required this.style, required this.primary});

  bool get isSpotify => style == 0;
  bool get isAppleMusic => style == 1;

  // ── Backgrounds ──────────────────────────────────────────────────
  Color get bgBase => isSpotify ? const Color(0xFF121212) : Colors.transparent;
  Color get bgCard => isSpotify ? const Color(0xFF1A1A1A) : Colors.white.withValues(alpha: 0.05);
  Color get bgSurface => isSpotify ? const Color(0xFF242424) : Colors.white.withValues(alpha: 0.08);

  // ── Gradient ──────────────────────────────────────────────────────
  Gradient get backgroundGradient => isSpotify
      ? LinearGradient(
          colors: [primary.withValues(alpha: 0.25), const Color(0xFF121212)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.38],
        )
      : const LinearGradient(
          colors: [Colors.transparent, Colors.transparent],
        );

  // ── Typography ────────────────────────────────────────────────────
  double get titleSize => isSpotify ? 32 : 28;
  FontWeight get titleWeight => FontWeight.w900;
  double get subtitleSize => 13;

  // ── Card shape ────────────────────────────────────────────────────
  double get cardRadius => isSpotify ? 8 : 20;
  double get pillRadius => isSpotify ? 4 : 28;

  // ── Border visibility ─────────────────────────────────────────────
  Border? get cardBorder => isSpotify
      ? null
      : Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1);

  // ── Accent colours ────────────────────────────────────────────────
  Color get accentGreen => const Color(0xFF1DB954); // Spotify green
  Color get accent => isSpotify ? accentGreen : primary;

  // ── Blur amounts ─────────────────────────────────────────────────
  double get blurAmount => isSpotify ? 0 : 24; // Spotify: no blur; AM: heavy blur

  // ── Item padding ─────────────────────────────────────────────────
  EdgeInsets get cardPadding => isSpotify
      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
      : const EdgeInsets.all(16);

  // ── Nav pill ─────────────────────────────────────────────────────
  Color get navBg => isSpotify
      ? const Color(0xFF1A1A1A)
      : Colors.white.withValues(alpha: 0.07);

  Border get navBorder => isSpotify
      ? Border.all(color: Colors.transparent)
      : Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1);
}
