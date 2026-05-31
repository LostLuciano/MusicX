import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/studio_settings_controller.dart';
import '../models/studio_settings.dart';

class PhoneFrameLayout extends StatelessWidget {
  final Widget child;

  const PhoneFrameLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final settingsController = Provider.of<StudioSettingsController>(context);
    final settings = settingsController.settings;
    final primaryColor = Color(settings.themeColorValue);
    final isAppleMusic = settings.uiStyle == 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 600;

        Widget mainAppCanvas = _buildAppCanvas(
          context,
          child,
          isAppleMusic,
          primaryColor,
          settings,
          isDesktop,
        );

        if (isDesktop) {
          return Container(
            color: const Color(0xFF05030A), // Absolute deep dark outside background
            child: Center(
              child: Container(
                width: 410,
                height: 860,
                margin: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: isAppleMusic ? Colors.transparent : const Color(0xFF0F0C1B),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: mainAppCanvas,
              ),
            ),
          );
        }

        // Standard mobile display
        return mainAppCanvas;
      },
    );
  }

  Widget _buildAppCanvas(
    BuildContext context,
    Widget child,
    bool isAppleMusic,
    Color primaryColor,
    StudioSettings settings,
    bool isDesktop,
  ) {
    if (!isAppleMusic) {
      // Sleek, flat Spotify-like theme
      return Container(
        color: const Color(0xFF0F0C1B),
        child: child,
      );
    }

    // Modern dynamic glass container wrapping the entire application
    final blur = settings.glassBlur * 8.0; // Scaled for beautiful ambient blur
    final saturation = settings.glassSaturation / 100.0;
    final chromatic = settings.glassChromaticAb;
    final overLight = settings.glassOverLight;

    // Saturation ColorFilter matrix
    final s = saturation;
    const r = 0.2126; const g = 0.7152; const b = 0.0722;
    final sr = (1 - s) * r; final sg = (1 - s) * g; final sb = (1 - s) * b;

    return Stack(
      children: [
        // 1. Opaque base dark layer
        Positioned.fill(
          child: Container(
            color: const Color(0xFF07050E),
          ),
        ),

        // 2. Animated Flowing Ambient Blobs
        Positioned.fill(
          child: FlowingAmbientBackground(
            primaryColor: primaryColor,
            settings: settings,
          ),
        ),

        // 3. Backdrop blur & saturation filter
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix([
              sr + s, sg,     sb,     0, 0,
              sr,     sg + s, sb,     0, 0,
              sr,     sg,     sb + s, 0, 0,
              0,      0,      0,      1, 0,
            ]),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(
                color: overLight 
                    ? Colors.black.withValues(alpha: 0.15) 
                    : Colors.white.withValues(alpha: 0.02),
              ),
            ),
          ),
        ),

        // 4. Global Chromatic Aberration overlays
        if (chromatic > 0.5) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(-chromatic * 0.15, 0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withValues(alpha: chromatic * 0.008),
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(chromatic * 0.15, 0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.blue.withValues(alpha: chromatic * 0.008),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],

        // 5. The actual app screen content
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}

class FlowingAmbientBackground extends StatefulWidget {
  final Color primaryColor;
  final StudioSettings settings;

  const FlowingAmbientBackground({
    super.key,
    required this.primaryColor,
    required this.settings,
  });

  @override
  State<FlowingAmbientBackground> createState() => _FlowingAmbientBackgroundState();
}

class _FlowingAmbientBackgroundState extends State<FlowingAmbientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryColor;
    // complementary/analogous glow color for premium looks
    final secondary = HSLColor.fromColor(primary)
        .withHue((HSLColor.fromColor(primary).hue + 60) % 360)
        .toColor();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final dx1 = 120 * math.sin(progress * 2 * math.pi);
        final dy1 = 80 * math.cos(progress * 2 * math.pi);

        final dx2 = 90 * math.cos((progress + 0.3) * 2 * math.pi);
        final dy2 = 130 * math.sin((progress + 0.3) * 2 * math.pi);

        final dx3 = 70 * math.sin((progress + 0.6) * 2 * math.pi);
        final dy3 = 90 * math.cos((progress + 0.6) * 2 * math.pi);

        return Stack(
          children: [
            // Top-left blob
            Positioned(
              left: -50 + dx1,
              top: 100 + dy1,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.08),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.12),
                      blurRadius: 90,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            // Bottom-right blob
            Positioned(
              right: -60 + dx2,
              bottom: 120 + dy2,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: secondary.withValues(alpha: 0.06),
                  boxShadow: [
                    BoxShadow(
                      color: secondary.withValues(alpha: 0.10),
                      blurRadius: 110,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
            // Center floating blob
            Positioned(
              left: 80 + dx3,
              bottom: 300 + dy3,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.05),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.08),
                      blurRadius: 80,
                      spreadRadius: 15,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
