import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/studio_settings_controller.dart';
import '../models/studio_settings.dart';

/// Premium glass container that reads from global GlassSettings.
/// Supports: backdrop blur, saturation, chromatic aberration,
/// elasticity cursor-tracking, over-light tint, and dynamic corner radius.
class LiquidGlassContainer extends StatefulWidget {
  final Widget child;
  final double? borderRadius;  // overrides global setting when provided
  final Color? tintColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool useGlobalSettings; // set false to use static defaults (e.g. nav)

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius,
    this.tintColor,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.useGlobalSettings = true,
  });

  @override
  State<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer>
    with SingleTickerProviderStateMixin {

  Offset _cursorLocal = Offset.zero;
  Offset _shift = Offset.zero;
  late AnimationController _elasticCtrl;
  late Animation<Offset> _elasticAnim;

  @override
  void initState() {
    super.initState();
    _elasticCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _elasticAnim = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
      CurvedAnimation(parent: _elasticCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _elasticCtrl.dispose();
    super.dispose();
  }

  void _onHover(PointerEvent e, StudioSettings s) {
    final elasticity = s.glassElasticity;
    final rb = context.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final local = rb.globalToLocal(e.position);
    final size = rb.size;
    // Normalised -1..1
    final nx = (local.dx / size.width - 0.5) * 2;
    final ny = (local.dy / size.height - 0.5) * 2;
    final target = Offset(nx * elasticity * 4, ny * elasticity * 4);

    _elasticAnim = Tween<Offset>(begin: _shift, end: target).animate(
      CurvedAnimation(parent: _elasticCtrl, curve: Curves.easeOutCubic),
    )..addListener(() {
      setState(() => _shift = _elasticAnim.value);
    });
    _elasticCtrl.forward(from: 0);
    setState(() => _cursorLocal = local);
  }

  void _onExit(StudioSettings s) {
    _elasticAnim = Tween<Offset>(begin: _shift, end: Offset.zero).animate(
      CurvedAnimation(parent: _elasticCtrl, curve: Curves.easeOutCubic),
    )..addListener(() {
      setState(() => _shift = _elasticAnim.value);
    });
    _elasticCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.useGlobalSettings
        ? Provider.of<StudioSettingsController>(context)
        : null;
    final s = ctrl?.settings ?? const StudioSettings();

    final radius = widget.borderRadius ?? s.glassCornerRadius;
    // Blur: map 0–5 → 0–40 sigmas
    final blurSigma = s.glassBlur * 40;
    final saturation = s.glassSaturation / 100.0; // 1.0–2.0
    final chromatic = s.glassChromaticAb;
    final overLight = s.glassOverLight;
    final refractionMode = s.glassRefractionMode;

    // Base tint
    Color baseTint = widget.tintColor ??
        (overLight
            ? Colors.black.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: _tintAlphaForMode(refractionMode)));

    Widget glass = _buildGlassLayers(radius, blurSigma, saturation, chromatic, baseTint, overLight, refractionMode);

    return MouseRegion(
      onHover: (e) => _onHover(e, s),
      onExit: (_) => _onExit(s),
      child: Transform.translate(
        offset: _shift,
        child: Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          child: glass,
        ),
      ),
    );
  }

  double _tintAlphaForMode(int mode) {
    switch (mode) {
      case 1: return 0.04; // polar - very transparent
      case 2: return 0.10; // prominent
      default: return 0.07; // standard
    }
  }

  Widget _buildGlassLayers(
      double radius, double blur, double saturation, double chromatic, Color tint, bool overLight, int refractionMode) {

    final content = widget.child;
    final padding = widget.padding;

    // ── Saturation ColorFilter matrix ────────────────────────────────
    final s = saturation;
    const r = 0.2126; const g = 0.7152; const b = 0.0722;
    final sr = (1 - s) * r; final sg = (1 - s) * g; final sb = (1 - s) * b;

    return Stack(
      children: [
        // ── Layer 1: Blurred + saturated backdrop ────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
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
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: overLight ? 0.0 : 0.09),
                      Colors.white.withValues(alpha: 0.01),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Container(
                  padding: padding,
                  child: content,
                ),
              ),
            ),
          ),
        ),

        // ── Layer 2: Chromatic Aberration (R channel) ─────────────────
        if (chromatic > 0.5)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Transform.translate(
                  offset: Offset(-chromatic * 0.3, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.withValues(alpha: chromatic * 0.015),
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
          ),

        // ── Layer 3: Chromatic Aberration (B channel) ─────────────────
        if (chromatic > 0.5)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Transform.translate(
                  offset: Offset(chromatic * 0.3, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.blue.withValues(alpha: chromatic * 0.015),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ── Layer 4: Top edge shimmer (refraction illusion) ───────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: IgnorePointer(
            child: Container(
              height: radius * 0.6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),

        // ── Layer 5: Cursor-reactive inner highlight ──────────────────
        if (_cursorLocal != Offset.zero)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: CustomPaint(
                  painter: _CursorHighlightPainter(
                    cursor: _cursorLocal,
                    radius: radius,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Paints a soft radial glow following the cursor.
class _CursorHighlightPainter extends CustomPainter {
  final Offset cursor;
  final double radius;
  const _CursorHighlightPainter({required this.cursor, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        radius: 0.5,
        center: Alignment(
          (cursor.dx / size.width) * 2 - 1,
          (cursor.dy / size.height) * 2 - 1,
        ),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CursorHighlightPainter old) => old.cursor != cursor;
}
