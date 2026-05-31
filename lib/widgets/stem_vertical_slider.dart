import 'package:flutter/material.dart';

class StemVerticalSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double volume; // 0.0 to 1.0
  final bool isMuted;
  final bool isSoloed;
  final ValueChanged<double> onChanged;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onSoloToggle;

  const StemVerticalSlider({
    super.key,
    required this.label,
    required this.icon,
    required this.volume,
    required this.onChanged,
    this.isMuted = false,
    this.isSoloed = false,
    this.onMuteToggle,
    this.onSoloToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = isSoloed ? const Color(0xFFFF8C37) : theme.primaryColor;
    final effectiveVolume = isMuted ? 0.0 : volume;

    return Column(
      children: [
        // The vertical slider body
        Expanded(
          child: GestureDetector(
            onVerticalDragUpdate: isMuted
                ? null
                : (details) {
                    final RenderBox renderBox =
                        context.findRenderObject() as RenderBox;
                    final localY =
                        renderBox.globalToLocal(details.globalPosition).dy;
                    final trackHeight = renderBox.size.height - 40;
                    if (trackHeight > 0) {
                      final double rawVolume = 1.0 - (localY / trackHeight);
                      onChanged(rawVolume.clamp(0.0, 1.0));
                    }
                  },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                final activeHeight = height * effectiveVolume;

                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Background track
                    Container(
                      width: 16,
                      height: height,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSoloed ? const Color(0xFFFF8C37).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.03),
                          width: 1,
                        ),
                      ),
                    ),
                    // Active gradient level
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 16,
                      height: activeHeight.clamp(0.0, height),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isMuted
                              ? [Colors.white24, Colors.white10]
                              : [primaryColor, primaryColor.withValues(alpha: 0.5)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isMuted
                            ? []
                            : [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                      ),
                    ),
                    // Accent indicator dot
                    if (!isMuted)
                      Positioned(
                        bottom: (activeHeight - 8).clamp(0.0, height - 16),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Mute toggle icon
        GestureDetector(
          onTap: onMuteToggle,
          onLongPress: onSoloToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isMuted
                  ? primaryColor.withValues(alpha: 0.2)
                  : (isSoloed ? const Color(0xFFFF8C37).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isMuted
                    ? primaryColor
                    : (isSoloed ? const Color(0xFFFF8C37) : Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Icon(
              icon,
              color: isMuted ? primaryColor : (isSoloed ? const Color(0xFFFF8C37) : Colors.white54),
              size: 16,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Label
        GestureDetector(
          onTap: onMuteToggle,
          onLongPress: onSoloToggle,
          child: Text(
            label,
            style: TextStyle(
              color: isMuted ? primaryColor : (isSoloed ? const Color(0xFFFF8C37) : Colors.white60),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}
