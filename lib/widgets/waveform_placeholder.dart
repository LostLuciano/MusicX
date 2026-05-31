import 'dart:math';
import 'package:flutter/material.dart';
import '../services/native_ios_audio_service.dart';

// Deterministic random number generator (Linear Congruential Generator)
class LCG {
  int seed;
  LCG(this.seed);
  
  double nextDouble() {
    seed = (1103515245 * seed + 12345) & 0x7fffffff;
    return seed / 2147483647.0;
  }
}

class WaveformPlaceholder extends StatefulWidget {
  final double height;
  final bool isPlaying;
  final double progress; // Value between 0.0 and 1.0
  final String? seedString;
  final String? audioPath;
  final ValueChanged<double>? onSeek;

  const WaveformPlaceholder({
    super.key,
    this.height = 80,
    this.isPlaying = false,
    this.progress = 0.3,
    this.seedString,
    this.audioPath,
    this.onSeek,
  });

  @override
  State<WaveformPlaceholder> createState() => _WaveformPlaceholderState();
}

class _WaveformPlaceholderState extends State<WaveformPlaceholder> {
  List<double> _waveform = [];
  bool _isLoading = false;

  double _getEnvelope(double x) {
    if (x < 0.08) {
      return 0.2 + (x / 0.08) * 0.3;
    } else if (x < 0.28) {
      return 0.5 + sin((x - 0.08) * 10) * 0.1;
    } else if (x < 0.45) {
      return 0.85 + cos((x - 0.28) * 8) * 0.15;
    } else if (x < 0.60) {
      return 0.55 + sin((x - 0.45) * 12) * 0.1;
    } else if (x < 0.78) {
      return 0.9 + cos((x - 0.60) * 7) * 0.1;
    } else if (x < 0.88) {
      return 0.4 + ((x - 0.78) / 0.1) * 0.4;
    } else if (x < 0.96) {
      return 0.95;
    } else {
      return 0.95 * (1.0 - (x - 0.96) / 0.04);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWaveform();
  }

  @override
  void didUpdateWidget(covariant WaveformPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioPath != widget.audioPath) {
      _loadWaveform();
    }
  }

  Future<void> _loadWaveform() async {
    final path = widget.audioPath;
    if (path == null || path.isEmpty) {
      _generateFallbackWave();
      return;
    }
    
    if (path.startsWith('assets/')) {
      _generateFallbackWave();
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final data = await NativeIosAudioService().getWaveformData(path, binsCount: 60);
      if (data != null && data.isNotEmpty) {
        if (mounted) {
          setState(() {
            _waveform = data;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Failed to extract real waveform: $e');
    }

    if (mounted) {
      _generateFallbackWave();
    }
  }

  void _generateFallbackWave() {
    final int seed = widget.seedString != null 
        ? widget.seedString.hashCode 
        : (widget.audioPath != null ? widget.audioPath.hashCode : 42);
    final lcg = LCG(seed);
    const int barCount = 60;
    final List<double> list = [];
    for (int i = 0; i < barCount; i++) {
      final double progress = i / barCount;
      final double envelope = _getEnvelope(progress);
      final double rand = 0.4 + 0.6 * lcg.nextDouble();
      list.add((envelope * rand).clamp(0.1, 1.0));
    }
    if (mounted) {
      setState(() {
        _waveform = list;
        _isLoading = false;
      });
    }
  }

  void _handleSeek(BuildContext context, double localX) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box != null && box.size.width > 0) {
      final double newProgress = (localX / box.size.width).clamp(0.0, 1.0);
      widget.onSeek?.call(newProgress);
    }
  }

  @override
  Widget build(BuildContext context) {
    const int barCount = 60;

    Widget content = Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131022),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _isLoading ? 0.5 : 1.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(barCount, (index) {
                final double barProgress = index / barCount;
                final bool isPassed = barProgress <= widget.progress;

                final double heightFactor = _waveform.length > index ? _waveform[index] : 0.15;

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    height: widget.height * heightFactor * 0.8,
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
          ),
          if (_isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFF2E93),
              ),
            ),
          // Vertical progress indicator line
          if (!_isLoading)
            Align(
              alignment: Alignment(widget.progress * 2 - 1, 0),
              child: Container(
                width: 3,
                height: widget.height,
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

    if (widget.onSeek != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => _handleSeek(context, details.localPosition.dx),
        onTapDown: (details) => _handleSeek(context, details.localPosition.dx),
        child: content,
      );
    }

    return content;
  }
}
