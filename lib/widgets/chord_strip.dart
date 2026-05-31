import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/project_controller.dart';

class ChordStrip extends StatelessWidget {
  const ChordStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ProjectController>(context);
    final project = controller.activeProject;

    if (project == null || project.chordSegments.isEmpty) {
      return Container(
        height: 44,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF131022),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note_outlined, color: Colors.white38, size: 16),
            const SizedBox(width: 8),
            Text(
              'Belum ada chord. Tap + di Chord Viewer untuk tambah.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
            ),
          ],
        ),
      );
    }

    final activeSegment = controller.activeChordSegment;
    final segments = project.chordSegments;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: segments.length,
        itemBuilder: (context, index) {
          final chord = segments[index];
          final isActive = activeSegment?.id == chord.id;

          return GestureDetector(
            onTap: () {
              controller.playerService.seek(Duration(milliseconds: chord.startTimeMs));
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [Color(0xFFFF2E93), Color(0xFFFF8C37)],
                      )
                    : null,
                color: !isActive ? const Color(0xFF131022) : null,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Text(
                  cleanChordName(chord.chordName),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    shadows: isActive
                        ? [
                            const Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Chord Clean Helper
String cleanChordName(String name) {
  String clean = name.trim();
  if (clean.contains(':')) {
    final parts = clean.split(':');
    final root = parts[0];
    final type = parts[1].toLowerCase();
    
    if (type == 'maj' || type == 'major') {
      clean = root;
    } else if (type == 'min' || type == 'minor' || type == 'm') {
      clean = '${root}m';
    } else if (type == '7' || type == 'dominant7') {
      clean = '${root}7';
    } else if (type == 'min7' || type == 'm7') {
      clean = '${root}m7';
    } else if (type == 'maj7' || type == 'major7') {
      clean = '${root}maj7';
    } else if (type == 'sus2') {
      clean = '${root}sus2';
    } else if (type == 'sus4') {
      clean = '${root}sus4';
    } else if (type == 'dim') {
      clean = '${root}dim';
    } else if (type == 'aug') {
      clean = '${root}aug';
    } else {
      clean = root + type;
    }
  }
  if (clean.contains('/')) {
    clean = clean.split('/')[0];
  }
  return clean;
}
