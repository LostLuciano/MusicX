import 'dart:ui';
import 'package:flutter/material.dart';

class ProjectListTile extends StatelessWidget {
  final String title;
  final String keyName;
  final int bpm;
  final String duration;
  final String date;
  final VoidCallback onTap;
  final VoidCallback onPlayTap;
  final bool isPlaying;

  const ProjectListTile({
    super.key,
    required this.title,
    required this.keyName,
    required this.bpm,
    required this.duration,
    required this.date,
    required this.onTap,
    required this.onPlayTap,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.07),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Album art
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withValues(alpha: 0.55)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.audio_file_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    // Title and meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _tag(keyName),
                              const SizedBox(width: 6),
                              if (bpm > 0)
                                Text(
                                  '$bpm BPM',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.38),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            date,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.25),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Play button
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: isPlaying ? 0.25 : 0.1),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                        onPressed: onPlayTap,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
