import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/waveform_placeholder.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../state/project_controller.dart';
import '../../models/audio_project.dart';
import '../stem_mixer/stem_mixer_screen.dart';
import '../stem_setup/stem_setup_screen.dart';
import '../chord_viewer/chord_viewer_screen.dart';
import '../record_setup/record_setup_screen.dart';
import '../../services/native_ios_audio_service.dart';
import '../../widgets/video_player_screen.dart';
import '../../state/studio_settings_controller.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String title;
  const ProjectDetailScreen({super.key, required this.title});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _progress = 0.0;
  ChordSegment? _activeChord;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _playSub;
  StreamSubscription? _chordSub;

  // Metronome state variables
  bool _metronomeEnabled = false;
  double _metronomeVol = 0.5;
  int _tempoMultiplier = 1; // 1x, 2x etc

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initListeners());
  }

  void _initListeners() {
    final controller = Provider.of<ProjectController>(context, listen: false);
    final player = controller.playerService.player;

    _posSub = player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        _position = pos;
        if (_duration.inMilliseconds > 0) {
          _progress = pos.inMilliseconds / _duration.inMilliseconds;
        }
        final proj = controller.activeProject;
        if (proj != null && proj.chordSegments.isNotEmpty) {
          _activeChord = controller.getActiveChord(pos, proj.chordSegments);
        }
      });
    });

    _durSub = player.durationStream.listen((dur) {
      if (!mounted || dur == null) return;
      setState(() => _duration = dur);
    });

    _playSub = player.playingStream.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    _chordSub?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final controller = Provider.of<ProjectController>(context);
    final project = controller.activeProject;

    if (project == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0C1B),
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Text(
            'Proyek tidak ditemukan.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final hasChords = project.chordSegments.isNotEmpty;
    final stemReady = project.stemStatus == AnalysisStatus.ready;

    final settingsController = Provider.of<StudioSettingsController>(context);
    final isAppleMusic = settingsController.settings.uiStyle == 1;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isAppleMusic
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF0F0C1B), Color(0xFF151026)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Bar / Top Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          project.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(context, controller, project),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Key / BPM / Time Sig Row
                  Row(
                    children: [
                      _statPill(Icons.music_note_rounded, project.keySignature ?? '—', 'Key', primaryColor),
                      const SizedBox(width: 10),
                      _statPill(
                        Icons.speed_rounded,
                        project.bpm != null ? '${project.bpm!.toInt()} BPM' : '— BPM',
                        'Tempo',
                        primaryColor,
                      ),
                      const SizedBox(width: 10),
                      _statPill(Icons.grid_4x4_rounded, project.timeSignature ?? '4/4', 'Birama', primaryColor),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Live Chord Display Banner
                  GestureDetector(
                    onTap: hasChords
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ChordViewerScreen()),
                            )
                        : null,
                    child: LiquidGlassContainer(
                      borderRadius: 24,
                      tintColor: _activeChord != null ? primaryColor.withValues(alpha: 0.15) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.piano_rounded, color: primaryColor, size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        hasChords ? 'CHORD AKTIF' : 'DETEKSI CHORD',
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _activeChord?.chordName ?? (hasChords ? '—' : 'Belum Dianalisis'),
                                    style: TextStyle(
                                      color: _activeChord != null ? Colors.white : Colors.white38,
                                      fontSize: 42,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  if (hasChords)
                                    Text(
                                      '${_fmt(_position)} / ${_fmt(_duration)}',
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            if (hasChords) ...[
                              _buildNextChordBadge(project),
                              const SizedBox(width: 12),
                            ],
                            Icon(
                              hasChords ? Icons.chevron_right_rounded : Icons.info_outline_rounded,
                              color: Colors.white24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dynamic Audio Player Console
                  LiquidGlassContainer(
                    borderRadius: 24,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          WaveformPlaceholder(
                            height: 60,
                            progress: _progress,
                            isPlaying: _isPlaying,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 28),
                                onPressed: () {
                                  final newPos = _position - const Duration(seconds: 10);
                                  controller.playerService.seek(
                                    newPos < Duration.zero ? Duration.zero : newPos,
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () async {
                                  if (_isPlaying) {
                                    await controller.playerService.pause();
                                  } else {
                                    await controller.playerService.play();
                                  }
                                },
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primaryColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.4),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 28),
                                onPressed: () {
                                  final newPos = _position + const Duration(seconds: 10);
                                  controller.playerService.seek(
                                    newPos > _duration ? _duration : newPos,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Beat & Tempo Metronome Panel
                  _buildMetronomePanel(theme, project),
                  const SizedBox(height: 20),

                  // Futuristic CoreML / Neural Engine Integration Scaffolding
                  _buildCoreMLScaffolding(theme),
                  const SizedBox(height: 24),

                  // Action Buttons Section
                  _sectionLabel('AKSI UTAMA'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _actionCard(
                          icon: Icons.tune_rounded,
                          label: 'Atur Stem',
                          sublabel: stemReady ? 'Mixer aktif' : 'Mulai pisah',
                          color: primaryColor,
                          onTap: () {
                            if (stemReady) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const StemMixerScreen()),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const StemSetupScreen()),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionCard(
                          icon: Icons.piano_rounded,
                          label: 'Lihat Chord',
                          sublabel: hasChords ? '${project.chordSegments.length} chord' : 'Belum ada',
                          color: const Color(0xFF00FFCC),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChordViewerScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionCard(
                          icon: Icons.mic_rounded,
                          label: 'Rekam',
                          sublabel: 'Backing track',
                          color: const Color(0xFFFF8C37),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RecordSetupScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Status AI Rows
                  _sectionLabel('AKURASI AI MODEL'),
                  const SizedBox(height: 12),
                  _statusRow('Stem Separation Engine', project.stemStatus, primaryColor),
                  const SizedBox(height: 6),
                  _statusRow('Chord recognition Neural Network', project.chordStatus, primaryColor),
                  const SizedBox(height: 6),
                  _statusRow('Beat & Downbeat Tracker', project.beatStatus, primaryColor),
                  const SizedBox(height: 24),

                  // Lyrics
                  _sectionLabel('LIRIK LAGU'),
                  const SizedBox(height: 12),
                  _buildLyricsSection(context, project, controller),
                  const SizedBox(height: 24),

                  // Saved recordings
                  _sectionLabel('REKAMAN TERSIMPAN'),
                  const SizedBox(height: 12),
                  if (project.recordings.isEmpty)
                    LiquidGlassContainer(
                      borderRadius: 16,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Belum ada rekaman sesi.',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ),
                      ),
                    )
                  else
                    ...project.recordings.map((take) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _takeTile(context, take, controller),
                        )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetronomePanel(ThemeData theme, AudioProject project) {
    final primaryColor = theme.primaryColor;
    final int bpm = project.bpm?.toInt() ?? 120;

    return LiquidGlassContainer(
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed_rounded, color: primaryColor, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Beat & Metronome Console',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Switch.adaptive(
                  activeThumbColor: primaryColor,
                  activeTrackColor: primaryColor.withValues(alpha: 0.35),
                  value: _metronomeEnabled,
                  onChanged: (val) {
                    setState(() {
                      _metronomeEnabled = val;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pulsing Beat Markers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(4, (index) {
                final isActiveBeat = _isPlaying &&
                    (_position.inMilliseconds % (60000 ~/ bpm) < 150) &&
                    ((_position.inMilliseconds ~/ (60000 ~/ bpm)) % 4 == index);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 50,
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: isActiveBeat
                        ? primaryColor
                        : (index == 0 ? Colors.white30 : Colors.white10),
                    boxShadow: isActiveBeat
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.8),
                              blurRadius: 8,
                            )
                          ]
                        : [],
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Vol & multiplier row
            Row(
              children: [
                const Icon(Icons.volume_down_rounded, color: Colors.white38, size: 16),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: primaryColor,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: primaryColor,
                    ),
                    child: Slider(
                      value: _metronomeVol,
                      onChanged: (val) {
                        setState(() => _metronomeVol = val);
                      },
                    ),
                  ),
                ),
                const Icon(Icons.volume_up_rounded, color: Colors.white38, size: 16),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _tempoMultiplier = _tempoMultiplier == 1 ? 2 : 1;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_tempoMultiplier}x',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoreMLScaffolding(ThemeData theme) {
    final primaryColor = theme.primaryColor;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LiquidGlassContainer(
        borderRadius: 24,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.memory_rounded, color: primaryColor, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'CoreML DSP Hardware Accelerator',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withValues(alpha: 0.8),
                          blurRadius: 6,
                        )
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Neural Engine co-processor active. Real-time audio stems isolation and spectral extraction will utilize Apple Silicon hardware blocks.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              // Futuristic Graph Scaffolding
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(16, (index) {
                  return Container(
                    width: 4,
                    height: (12 + (index % 4) * 8).toDouble(),
                    decoration: BoxDecoration(
                      color: index < 10 ? primaryColor.withValues(alpha: 0.7) : Colors.white10,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextChordBadge(AudioProject project) {
    final nextMs = _position.inMilliseconds;
    final next = project.chordSegments.where((c) => c.startTimeMs > nextMs).fold<ChordSegment?>(null, (prev, c) {
      if (prev == null) return c;
      return c.startTimeMs < prev.startTimeMs ? c : prev;
    });

    if (next == null) return const SizedBox.shrink();
    return Column(
      children: [
        const Text(
          'BERIKUT',
          style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            next.chordName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statPill(IconData icon, String value, String label, Color accentColor) {
    return Expanded(
      child: LiquidGlassContainer(
        borderRadius: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: Colors.white38, size: 16),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassContainer(
        borderRadius: 18,
        tintColor: color.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sublabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      );

  Widget _statusRow(String label, AnalysisStatus status, Color primaryColor) {
    final (text, color, icon) = switch (status) {
      AnalysisStatus.ready => ('Siap', const Color(0xFF00FF99), Icons.check_circle_outline_rounded),
      AnalysisStatus.processing => ('Memproses...', Colors.amber, Icons.autorenew_rounded),
      AnalysisStatus.waitingModel => ('Menunggu Model', Colors.amber, Icons.hourglass_empty_rounded),
      AnalysisStatus.error => ('Error', Colors.redAccent, Icons.error_outline_rounded),
      AnalysisStatus.unavailable => ('Belum Diproses', Colors.white24, Icons.info_outline_rounded),
    };

    return LiquidGlassContainer(
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _takeTile(BuildContext context, RecordingTake take, ProjectController controller) {
    final primaryColor = Theme.of(context).primaryColor;

    return LiquidGlassContainer(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                take.type == RecordingType.video ? Icons.videocam_rounded : Icons.mic_rounded,
                color: primaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    take.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Mode: ${take.mode.name} • ${take.type.name}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white70, size: 20),
              onPressed: () async {
                try {
                  await NativeIosAudioService().shareFile(take.filePath);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal membagikan: $e')),
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 24),
              onPressed: () async {
                if (take.type == RecordingType.video) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerScreen(
                        filePath: take.filePath,
                        title: take.title,
                      ),
                    ),
                  );
                } else {
                  try {
                    await controller.playerService.loadFile(take.filePath);
                    await controller.playerService.play();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal memutar: $e')),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ProjectController controller, AudioProject project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131022),
        title: const Text('Hapus Proyek', style: TextStyle(color: Colors.white)),
        content: Text('Hapus "${project.title}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context);
              await controller.deleteProject(project.id);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsSection(BuildContext context, AudioProject project, ProjectController controller) {
    final hasLyrics = project.lyricLines.isNotEmpty;
    final isSynced = project.syncedLyrics != null && project.syncedLyrics!.isNotEmpty;
    final primaryColor = Theme.of(context).primaryColor;

    return LiquidGlassContainer(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.lyrics_rounded, color: primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      hasLyrics ? (isSynced ? 'Lirik Sinkron' : 'Lirik Polos') : 'Belum Ada Lirik',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (hasLyrics)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSynced ? primaryColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isSynced ? 'Synced LRC' : 'Plain Text',
                      style: TextStyle(
                        color: isSynced ? primaryColor : Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasLyrics) ...[
              Text(
                project.lyricLines.take(2).map((l) => l.text).join('\n'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic),
              ),
              if (project.lyricLines.length > 2) ...[
                const SizedBox(height: 2),
                Text(
                  '... (+${project.lyricLines.length - 2} baris lainnya)',
                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showFullLyricsDialog(context, project),
                      icon: const Icon(Icons.chrome_reader_mode_rounded, size: 16),
                      label: const Text('Lihat', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: primaryColor.withValues(alpha: 0.15),
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showLyricsSearchDialog(context, project, controller),
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: const Text('Cari Lirik', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Lirik lagu ini belum diunduh. Anda bisa mencarinya secara gratis dari database LRCLIB.',
                style: TextStyle(color: Colors.white30, fontSize: 12),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showLyricsSearchDialog(context, project, controller),
                  icon: const Icon(Icons.cloud_download_rounded, size: 16),
                  label: const Text(
                    'Cari Lirik Online',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFullLyricsDialog(BuildContext context, AudioProject project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131022),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Seluruh Lirik',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white10),
              Expanded(
                child: ListView.builder(
                  itemCount: project.lyricLines.length,
                  itemBuilder: (context, index) {
                    final line = project.lyricLines[index];
                    final String timeLabel = project.syncedLyrics != null && project.syncedLyrics!.isNotEmpty
                        ? '[${_fmt(Duration(milliseconds: line.timeMs))}] '
                        : '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (timeLabel.isNotEmpty)
                            const Text(
                              '[LRC] ',
                              style: TextStyle(color: Color(0xFFFF2E93), fontSize: 12, fontFamily: 'monospace'),
                            ),
                          Expanded(
                            child: Text(
                              line.text,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLyricsSearchDialog(BuildContext context, AudioProject project, ProjectController controller) {
    final searchCtrl = TextEditingController(text: project.title);
    List<Map<String, dynamic>> results = [];
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131022),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> performSearch() async {
              if (searchCtrl.text.trim().isEmpty) return;
              setModalState(() => loading = true);
              final list = await controller.searchLyrics(searchCtrl.text.trim());
              setModalState(() {
                results = list;
                loading = false;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cari Lirik di LRCLIB',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Masukkan judul lagu / artis...',
                            hintStyle: const TextStyle(color: Colors.white30),
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => performSearch(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF2E93),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: performSearch,
                        child: const Icon(Icons.search_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 300,
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(color: Color(0xFFFF2E93)),
                          )
                        : results.isEmpty
                            ? const Center(
                                child: Text(
                                  'Tidak ada hasil. Silakan cari dengan kata kunci lain.',
                                  style: TextStyle(color: Colors.white38, fontSize: 13),
                                ),
                              )
                            : ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (context, index) {
                                  final item = results[index];
                                  final String title = item['trackName'] ?? 'Tanpa Judul';
                                  final String artist = item['artistName'] ?? 'Artis Tidak Diketahui';
                                  final String album = item['albumName'] ?? '';
                                  final bool hasLrc = item['syncedLyrics'] != null && (item['syncedLyrics'] as String).isNotEmpty;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      title: Text(
                                        title,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        '$artist ${album.isNotEmpty ? "• $album" : ""}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: hasLrc ? const Color(0xFFFF2E93).withValues(alpha: 0.15) : Colors.white10,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          hasLrc ? 'Synced' : 'Plain',
                                          style: TextStyle(
                                            color: hasLrc ? const Color(0xFFFF2E93) : Colors.white38,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Mengunduh dan menerapkan lirik...')),
                                        );
                                        await controller.applyLyricsToProject(project.id, item);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Lirik berhasil diterapkan!')),
                                          );
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
