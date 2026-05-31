import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_ui_theme.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final int uiStyle;
  final Function(int) onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.uiStyle = 0,
  });

  static const _items = [
    (Icons.home_filled, Icons.home_outlined, 'Beranda', 0),
    (Icons.folder_rounded, Icons.folder_outlined, 'Proyek', 1),
    (Icons.mic_rounded, Icons.mic_none_rounded, 'Rekam', 3),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profil', 4),
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final ui = AppUITheme(style: uiStyle, primary: primaryColor);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 28, top: 4),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(child: _buildPill(ui)),
            const SizedBox(width: 10),
            _buildFAB(ui),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(AppUITheme ui) {
    if (ui.isSpotify) {
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _items.map((item) => _NavItem(
            filledIcon: item.$1, outlineIcon: item.$2, label: item.$3,
            index: item.$4, currentIndex: currentIndex, accent: ui.accent, onTap: onTap,
          )).toList(),
        ),
      );
    }

    // Apple Music: frosted glass pill
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: LinearGradient(
              colors: [Colors.white.withValues(alpha: 0.09), Colors.white.withValues(alpha: 0.04)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _items.map((item) => _NavItem(
              filledIcon: item.$1, outlineIcon: item.$2, label: item.$3,
              index: item.$4, currentIndex: currentIndex, accent: ui.accent, onTap: onTap,
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(AppUITheme ui) {
    if (ui.isSpotify) {
      return GestureDetector(
        onTap: () => onTap(2),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: ui.accent,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: ui.accent.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.black, size: 26),
        ),
      );
    }

    // Apple Music: glass + radial gradient
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: GestureDetector(
          onTap: () => onTap(2),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [ui.accent, ui.accent.withValues(alpha: 0.6)]),
              boxShadow: [BoxShadow(color: ui.accent.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData filledIcon;
  final IconData outlineIcon;
  final String label;
  final int index;
  final int currentIndex;
  final Color accent;
  final Function(int) onTap;

  const _NavItem({
    required this.filledIcon, required this.outlineIcon, required this.label,
    required this.index, required this.currentIndex, required this.accent, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = currentIndex == index;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sel ? filledIcon : outlineIcon, color: sel ? accent : Colors.white.withValues(alpha: 0.35), size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: sel ? Colors.white : Colors.white.withValues(alpha: 0.35),
                fontSize: 9,
                fontWeight: sel ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
