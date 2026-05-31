import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/project_controller.dart';

class ChordViewerScreen extends StatefulWidget {
  const ChordViewerScreen({super.key});

  @override
  State<ChordViewerScreen> createState() => _ChordViewerScreenState();
}

class _ChordViewerScreenState extends State<ChordViewerScreen> {
  int _selectedTab = 0; // 0: Timeline, 1: Details
  int _selectedInstrument = 0; // 0: Gitar, 1: Ukulele, 2: Piano
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;

  final ScrollController _timelineScrollController = ScrollController();
  final ScrollController _gridScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPlayerListeners();
    });
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  void _initPlayerListeners() {
    final controller = Provider.of<ProjectController>(context, listen: false);
    final player = controller.playerService.player;

    player.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = pos;
        });
        _scrollToActiveChord();
      }
    });

    player.durationStream.listen((dur) {
      if (mounted && dur != null) {
        setState(() {
          _totalDuration = dur;
        });
      }
    });

    player.playingStream.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });
  }

  void _scrollToActiveChord() {
    final controller = Provider.of<ProjectController>(context, listen: false);
    final project = controller.activeProject;
    final activeSegment = controller.activeChordSegment;
    if (project == null || activeSegment == null) return;

    final index = project.chordSegments.indexWhere((c) => c.id == activeSegment.id);
    if (index != -1) {
      if (_timelineScrollController.hasClients) {
        final double itemWidth = 92.0;
        final double viewportWidth = MediaQuery.of(context).size.width;
        final double targetOffset = (index * itemWidth) - (viewportWidth / 2) + (itemWidth / 2);
        _timelineScrollController.animateTo(
          targetOffset.clamp(0.0, _timelineScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }

      if (_gridScrollController.hasClients) {
        final uniqueChords = project.chordSegments
            .map((c) => c.chordName)
            .toSet()
            .toList();
        final uniqueIndex = uniqueChords.indexOf(activeSegment.chordName);
        if (uniqueIndex != -1) {
          final row = uniqueIndex ~/ 2;
          final targetOffset = row * 160.0;
          _gridScrollController.animateTo(
            targetOffset.clamp(0.0, _gridScrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showAddChordBottomSheet(BuildContext context, ProjectController controller) {
    final nameController = TextEditingController();
    final int initialStartSec = _currentPosition.inSeconds;
    final startController = TextEditingController(text: initialStartSec.toString());
    final endController = TextEditingController(text: (initialStartSec + 4).toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131022),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tambah Chord Manual',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nama Chord (misal: C, Am, G7)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Mulai (Detik)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: endController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Selesai (Detik)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2E93),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    final String name = nameController.text.trim();
                    final int? startSec = int.tryParse(startController.text);
                    final int? endSec = int.tryParse(endController.text);

                    if (name.isEmpty || startSec == null || endSec == null || startSec >= endSec) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Input tidak valid. Pastikan Mulai < Selesai.')),
                      );
                      return;
                    }

                    await controller.addChordSegment(
                      name,
                      startSec * 1000,
                      endSec * 1000,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Chord $name ditambahkan!')),
                      );
                    }
                  },
                  child: const Text('Simpan Chord', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChordDiagram(String chordName, {bool showLabel = false}) {
    if (_selectedInstrument == 0) {
      return GuitarChordDiagram(chordName: chordName, showLabel: showLabel);
    } else if (_selectedInstrument == 1) {
      return UkuleleChordDiagram(chordName: chordName, showLabel: showLabel);
    } else {
      return PianoChordDiagram(chordName: chordName, showLabel: showLabel);
    }
  }

  Widget _buildInstrumentPill(int index, String label, IconData icon) {
    final isSelected = _selectedInstrument == index;
    final themeColor = index == 0 
        ? const Color(0xFFFF2E93) 
        : (index == 1 ? const Color(0xFF00C6FF) : const Color(0xFFFF8C37));

    return GestureDetector(
      onTap: () => setState(() => _selectedInstrument = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? themeColor.withValues(alpha: 0.15) : const Color(0xFF131022),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? themeColor : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? themeColor : Colors.white38, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ProjectController>(context);
    final project = controller.activeProject;

    if (project == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0C1B),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Tidak ada project aktif.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    final hasChords = project.chordSegments.isNotEmpty;
    final activeChord = controller.activeChordSegment;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        title: Text(project.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Colors.white70),
            onPressed: () => _showAddChordBottomSheet(context, controller),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Chord Large Panel (Top Display)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1934), Color(0xFF131022)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: activeChord != null ? const Color(0xFFFF2E93).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CHORD AKTIF',
                          style: TextStyle(
                            color: Color(0xFFFF8C37),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeChord != null 
                              ? cleanChordName(activeChord.chordName)
                              : '-',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              _formatDuration(_currentPosition),
                              style: const TextStyle(color: Color(0xFFFF2E93), fontWeight: FontWeight.bold),
                            ),
                            Text(
                              ' / ${_formatDuration(_totalDuration)}',
                              style: const TextStyle(color: Colors.white38),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (activeChord != null)
                    _buildChordDiagram(activeChord.chordName, showLabel: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Media Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    color: Colors.white,
                    size: 52,
                  ),
                  onPressed: () async {
                    if (_isPlaying) {
                      await controller.playerService.pause();
                    } else {
                      await controller.playerService.play();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Horizontal Scrolling Timeline Ribbon (Chordify Style)
            if (hasChords) ...[
              const Text(
                'TIMELINE CHORD (AUTO-SCROLL)',
                style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 65,
                child: ListView.builder(
                  controller: _timelineScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: project.chordSegments.length,
                  itemBuilder: (context, index) {
                    final chord = project.chordSegments[index];
                    final isAct = activeChord?.id == chord.id;
                    final displayChord = cleanChordName(chord.chordName);

                    return GestureDetector(
                      onTap: () {
                        controller.playerService.seek(Duration(milliseconds: chord.startTimeMs));
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          gradient: isAct
                              ? const LinearGradient(
                                  colors: [Color(0xFFFF2E93), Color(0xFFFF8C37)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: !isAct ? const Color(0xFF131022) : null,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isAct ? const Color(0xFFFF2E93) : Colors.white.withValues(alpha: 0.08),
                            width: isAct ? 2.5 : 1.0,
                          ),
                          boxShadow: isAct
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFF2E93).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 4,
                              left: 6,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isAct ? Colors.white70 : Colors.white30,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Center(
                              child: Text(
                                displayChord,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Sub Tab Selector
            Row(
              children: [
                _buildSubTab(0, 'Diagram Latihan'),
                _buildSubTab(1, 'Info Proyek'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab View Contents
            Expanded(
              child: _selectedTab == 0
                  ? (!hasChords
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.music_note_outlined, size: 48, color: Colors.white24),
                              const SizedBox(height: 12),
                              const Text(
                                'Chord belum dianalisis.',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Instrument selectors (Guitar, Ukulele, Piano)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildInstrumentPill(0, 'Gitar', Icons.music_note_rounded),
                                const SizedBox(width: 12),
                                _buildInstrumentPill(1, 'Ukulele', Icons.album_rounded),
                                const SizedBox(width: 12),
                                _buildInstrumentPill(2, 'Piano', Icons.piano_rounded),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Unique chord diagrams summary grid
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final uniqueChords = project.chordSegments
                                      .map((c) => c.chordName)
                                      .toSet()
                                      .toList();

                                  return GridView.builder(
                                    controller: _gridScrollController,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 1.1,
                                    ),
                                    itemCount: uniqueChords.length,
                                    itemBuilder: (context, idx) {
                                      final chordName = uniqueChords[idx];
                                      final isAct = activeChord?.chordName == chordName;
                                      final clean = cleanChordName(chordName);

                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF131022),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isAct 
                                                ? const Color(0xFFFF2E93) 
                                                : Colors.white.withValues(alpha: 0.06),
                                            width: isAct ? 2.5 : 1.0,
                                          ),
                                          boxShadow: isAct
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xFFFF2E93).withValues(alpha: 0.35),
                                                    blurRadius: 10,
                                                    spreadRadius: 1,
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              clean,
                                              style: TextStyle(
                                                color: isAct ? const Color(0xFFFF8C37) : Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Expanded(
                                              child: Center(
                                                child: _buildChordDiagram(chordName, showLabel: false),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                }
                              ),
                            ),
                          ],
                        ))
                  : SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131022),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Nama File', project.title),
                            _buildInfoRow('Platform', 'Web / Local Simulator Offline'),
                            _buildInfoRow('Total Segment', '${project.chordSegments.length} akor terindeks'),
                            _buildInfoRow('Metodologi', 'Manual Input / CoreML CRNN Inference Ready'),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTab(int index, String label) {
    final isSelected = _selectedTab == index;
    final activeColor = const Color(0xFFFF2E93);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? activeColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// Chord Clean Helper
String cleanChordName(String name) {
  String clean = name;
  if (clean.endsWith(':maj')) {
    clean = clean.substring(0, clean.length - 4);
  } else if (clean.endsWith(':min')) {
    clean = '${clean.substring(0, clean.length - 4)}m';
  }
  return clean;
}

// Guitar Chord Diagram
const Map<String, List<String>> _guitarFingerings = {
  'C': ['x', '3', '2', '0', '1', '0'],
  'G': ['3', '2', '0', '0', '0', '3'],
  'Am': ['x', '0', '2', '2', '1', '0'],
  'F': ['1', '3', '3', '2', '1', '1'],
  'Dm': ['x', 'x', '0', '2', '3', '1'],
  'Em': ['0', '2', '2', '0', '0', '0'],
  'A': ['x', '0', '2', '2', '2', '0'],
  'D': ['x', 'x', '0', '2', '3', '2'],
  'E': ['0', '2', '2', '1', '0', '0'],
  'C7': ['x', '3', '2', '3', '1', '0'],
  'G7': ['3', '2', '0', '0', '0', '1'],
  'A7': ['x', '0', '2', '0', '2', '0'],
  'D7': ['x', 'x', '0', '2', '1', '2'],
  'E7': ['0', '2', '0', '1', '0', '0'],
  'B7': ['x', '2', '1', '2', '0', '2'],
  'Bm': ['x', '2', '4', '4', '3', '2'],
};

class GuitarChordDiagram extends StatelessWidget {
  final String chordName;
  final bool showLabel;
  const GuitarChordDiagram({super.key, required this.chordName, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final clean = cleanChordName(chordName);
    final fingering = _guitarFingerings[clean] ?? ['0', '0', '0', '0', '0', '0'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 60,
          margin: const EdgeInsets.only(top: 4),
          child: CustomPaint(
            painter: GuitarFretboardPainter(fingering),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(
            'Gitar ($clean)',
            style: const TextStyle(color: Color(0xFFFF8C37), fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }
}

class GuitarFretboardPainter extends CustomPainter {
  final List<String> fingering;
  GuitarFretboardPainter(this.fingering);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.2;

    final activePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF2E93), Color(0xFFFF8C37)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final double width = size.width;
    final double height = size.height;

    // Draw 5 fret lines
    final double fretSpacing = height / 4.0;
    for (int i = 0; i <= 4; i++) {
      final double y = i * fretSpacing;
      canvas.drawLine(Offset(0, y), Offset(width, y), linePaint);
    }

    // Draw 6 string lines
    final double stringSpacing = width / 5.0;
    for (int i = 0; i < 6; i++) {
      final double x = i * stringSpacing;
      canvas.drawLine(Offset(x, 0), Offset(x, height), linePaint);
    }

    // Draw finger positions
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int stringIdx = 0; stringIdx < 6; stringIdx++) {
      final val = fingering[stringIdx];
      final double x = stringIdx * stringSpacing;

      if (val == 'x') {
        textPainter.text = const TextSpan(
          text: '×',
          style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, -14));
      } else if (val == '0') {
        textPainter.text = const TextSpan(
          text: '○',
          style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, -12));
      } else {
        final int? fret = int.tryParse(val);
        if (fret != null && fret > 0 && fret <= 4) {
          final double y = (fret - 0.5) * fretSpacing;
          canvas.drawCircle(Offset(x, y), 5.0, activePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GuitarFretboardPainter oldDelegate) {
    return oldDelegate.fingering != fingering;
  }
}

// Ukulele Chord Diagram
const Map<String, List<String>> _ukuleleFingerings = {
  'C': ['0', '0', '0', '3'],
  'G': ['0', '2', '3', '2'],
  'Am': ['2', '0', '0', '0'],
  'F': ['2', '0', '1', '0'],
  'Dm': ['2', '2', '1', '0'],
  'Em': ['0', '4', '3', '2'],
  'A': ['2', '1', '0', '0'],
  'D': ['2', '2', '2', '0'],
  'E': ['4', '4', '4', '2'],
  'G7': ['0', '2', '1', '2'],
  'C7': ['0', '0', '0', '1'],
  'E7': ['1', '2', '0', '2'],
  'D7': ['2', '0', '2', '0'],
  'A7': ['1', '0', '0', '0'],
  'B7': ['4', '3', '2', '2'],
  'Bm': ['4', '2', '2', '2'],
};

class UkuleleChordDiagram extends StatelessWidget {
  final String chordName;
  final bool showLabel;
  const UkuleleChordDiagram({super.key, required this.chordName, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final clean = cleanChordName(chordName);
    final fingering = _ukuleleFingerings[clean] ?? ['0', '0', '0', '0'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 55,
          height: 60,
          margin: const EdgeInsets.only(top: 4),
          child: CustomPaint(
            painter: UkuleleFretboardPainter(fingering),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(
            'Ukulele ($clean)',
            style: const TextStyle(color: Color(0xFFFF8C37), fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }
}

class UkuleleFretboardPainter extends CustomPainter {
  final List<String> fingering;
  UkuleleFretboardPainter(this.fingering);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.2;

    final activePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF2E93), Color(0xFFFF8C37)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final double width = size.width;
    final double height = size.height;

    // Draw 5 fret lines
    final double fretSpacing = height / 4.0;
    for (int i = 0; i <= 4; i++) {
      final double y = i * fretSpacing;
      canvas.drawLine(Offset(0, y), Offset(width, y), linePaint);
    }

    // Draw 4 string lines
    final double stringSpacing = width / 3.0;
    for (int i = 0; i < 4; i++) {
      final double x = i * stringSpacing;
      canvas.drawLine(Offset(x, 0), Offset(x, height), linePaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int stringIdx = 0; stringIdx < 4; stringIdx++) {
      final val = fingering[stringIdx];
      final double x = stringIdx * stringSpacing;

      if (val == 'x') {
        textPainter.text = const TextSpan(
          text: '×',
          style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, -14));
      } else if (val == '0') {
        textPainter.text = const TextSpan(
          text: '○',
          style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, -12));
      } else {
        final int? fret = int.tryParse(val);
        if (fret != null && fret > 0 && fret <= 4) {
          final double y = (fret - 0.5) * fretSpacing;
          canvas.drawCircle(Offset(x, y), 5.0, activePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant UkuleleFretboardPainter oldDelegate) {
    return oldDelegate.fingering != fingering;
  }
}

// Piano Keyboard Diagram
const Map<String, List<int>> _pianoWhiteKeys = {
  'C': [0, 2, 4],
  'Cm': [0, 4],
  'G': [4, 6, 8],
  'Gm': [4, 8],
  'Am': [5, 7, 9],
  'A': [5, 9],
  'F': [3, 5, 7],
  'Fm': [3, 7],
  'Dm': [1, 3, 5],
  'D': [1, 5],
  'Em': [2, 4, 6],
  'E': [2, 6],
  'E7': [2, 6, 8],
  'G7': [4, 6, 8],
  'C7': [0, 2, 4],
  'A7': [5, 9],
  'D7': [1, 5, 7],
  'B7': [6, 9],
  'Bm': [6, 8],
};

const Map<String, List<double>> _pianoBlackKeys = {
  'C': [],
  'Cm': [1.5], // Eb
  'G': [],
  'Gm': [5.5], // Bb
  'Am': [],
  'A': [7.5], // C#
  'F': [],
  'Fm': [4.5], // Ab
  'Dm': [],
  'D': [3.5], // F#
  'Em': [],
  'E': [4.5], // G#
  'E7': [4.5],
  'G7': [],
  'C7': [5.5], // Bb
  'A7': [7.5], // C#
  'D7': [3.5], // F#
  'B7': [8.5, 3.5], // D#, F#
  'Bm': [3.5], // F#
};

class PianoChordDiagram extends StatelessWidget {
  final String chordName;
  final bool showLabel;
  const PianoChordDiagram({super.key, required this.chordName, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final clean = cleanChordName(chordName);
    final whites = _pianoWhiteKeys[clean] ?? [0, 2, 4];
    final blacks = _pianoBlackKeys[clean] ?? [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 130,
          height: 50,
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          child: CustomPaint(
            painter: PianoKeyboardPainter(whiteKeysPressed: whites, blackKeysPressed: blacks),
          ),
        ),
        if (showLabel) ...[
          Text(
            'Piano ($clean)',
            style: const TextStyle(color: Color(0xFFFF8C37), fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }
}

class PianoKeyboardPainter extends CustomPainter {
  final List<int> whiteKeysPressed;
  final List<double> blackKeysPressed;
  PianoKeyboardPainter({required this.whiteKeysPressed, required this.blackKeysPressed});

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    final int totalWhiteKeys = 10;
    final double whiteWidth = width / totalWhiteKeys;

    final whitePaint = Paint()
      ..color = const Color(0xFF1E1934)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final activePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF2E93), Color(0xFFFF8C37)],
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    // Draw White Keys
    for (int i = 0; i < totalWhiteKeys; i++) {
      final double left = i * whiteWidth;
      final rect = Rect.fromLTWH(left, 0, whiteWidth, height);
      final isPressed = whiteKeysPressed.contains(i);
      canvas.drawRect(rect, isPressed ? activePaint : whitePaint);
      canvas.drawRect(rect, borderPaint);
    }

    // Draw Black Keys
    final double blackWidth = whiteWidth * 0.6;
    final double blackHeight = height * 0.65;
    final blackPaint = Paint()
      ..color = const Color(0xFF0F0C1B)
      ..style = PaintingStyle.fill;

    final List<double> blackPositions = [0.5, 1.5, 3.5, 4.5, 5.5, 7.5, 8.5];
    for (final pos in blackPositions) {
      final double center = pos * whiteWidth;
      final double left = center - (blackWidth / 2);
      final rect = Rect.fromLTWH(left, 0, blackWidth, blackHeight);
      final isPressed = blackKeysPressed.contains(pos);
      canvas.drawRect(rect, isPressed ? activePaint : blackPaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PianoKeyboardPainter oldDelegate) {
    return oldDelegate.whiteKeysPressed != whiteKeysPressed || oldDelegate.blackKeysPressed != blackKeysPressed;
  }
}
