import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/chord_strip.dart';
import '../../widgets/stem_vertical_slider.dart';
import '../../widgets/waveform_placeholder.dart';
import '../../widgets/transport_controls.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../state/project_controller.dart';
import '../../state/studio_settings_controller.dart';
import '../../models/audio_project.dart';
import '../chord_viewer/chord_viewer_screen.dart';
import '../profile/profile_sub_screens.dart';

class StemMixerScreen extends StatefulWidget {
  const StemMixerScreen({super.key});

  @override
  State<StemMixerScreen> createState() => _StemMixerScreenState();
}

class _StemMixerScreenState extends State<StemMixerScreen> {
  bool _isPlaying = false;
  int _activeTab = 0; // 0: Akor, 1: Lirik, 2: Mixer
  double _playbackProgress = 0.0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Stems volume
  double _vocalsVol = 1.0;
  double _bassVol = 1.0;
  double _drumsVol = 1.0;
  double _pianoVol = 1.0;
  double _guitarVol = 1.0;
  double _otherVol = 1.0;

  final Map<String, bool> _muteState = {
    'vocals': false,
    'bass': false,
    'drums': false,
    'piano': false,
    'guitar': false,
    'other': false,
  };

  double _playbackSpeed = 1.0;
  static const List<double> _speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const List<String> _speedLabels = ['0.5×', '0.75×', '1×', '1.25×', '1.5×', '2×'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPlayerListeners();
    });
  }

  void _initPlayerListeners() {
    final controller = Provider.of<ProjectController>(context, listen: false);
    final player = controller.playerService.player;

    player.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          if (_totalDuration.inMilliseconds > 0) {
            _playbackProgress = pos.inMilliseconds / _totalDuration.inMilliseconds;
          }
        });
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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

    final isStemsReady = project.stemStatus == AnalysisStatus.ready;
    final settingsController = Provider.of<StudioSettingsController>(context);
    final bool isModelAvailable = settingsController.modelsAvailability?.stemSeparationAvailable ?? true;

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
            child: Column(
              children: [
                // Top header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
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
                      icon: const Icon(Icons.ios_share_rounded, color: Colors.white70, size: 20),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Chord highlighting ribbons
                const ChordStrip(),
                const SizedBox(height: 20),

                // Mixer card console
                Expanded(
                  child: Stack(
                    children: [
                      LiquidGlassContainer(
                        borderRadius: 24,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                          child: Opacity(
                            opacity: isStemsReady ? 1.0 : 0.25,
                            child: Builder(
                              builder: (context) {
                                final stemFiles = project.stemFiles;
                                final showVocals = stemFiles?.vocals != null;
                                final showBass = stemFiles?.bass != null;
                                final showDrums = stemFiles?.drums != null;
                                final showPiano = stemFiles?.piano != null;
                                final showGuitar = stemFiles?.guitar != null;
                                final showOther = stemFiles?.other != null;

                                final List<Widget> sliders = [];

                                if (showVocals) {
                                  sliders.add(
                                    StemVerticalSlider(
                                      label: 'Vokal',
                                      icon: Icons.mic_none_rounded,
                                      volume: _vocalsVol,
                                      isMuted: _muteState['vocals']!,
                                      onMuteToggle: isStemsReady ? () {
                                        final muted = !_muteState['vocals']!;
                                        setState(() => _muteState['vocals'] = muted);
                                        controller.playerService.muteStem('vocals', muted);
                                      } : null,
                                      onChanged: isStemsReady ? (val) {
                                        setState(() => _vocalsVol = val);
                                        controller.playerService.setStemVolume('vocals', val);
                                      } : (val) {},
                                    ),
                                  );
                                }

                                if (showBass) {
                                  sliders.add(
                                    StemVerticalSlider(
                                      label: 'Bass',
                                      icon: Icons.graphic_eq_rounded,
                                      volume: _bassVol,
                                      isMuted: _muteState['bass']!,
                                      onMuteToggle: isStemsReady ? () {
                                        final muted = !_muteState['bass']!;
                                        setState(() => _muteState['bass'] = muted);
                                        controller.playerService.muteStem('bass', muted);
                                      } : null,
                                      onChanged: isStemsReady ? (val) {
                                        setState(() => _bassVol = val);
                                        controller.playerService.setStemVolume('bass', val);
                                      } : (val) {},
                                    ),
                                  );
                                }

                                if (showDrums) {
                                  sliders.add(
                                    StemVerticalSlider(
                                      label: 'Drum',
                                      icon: Icons.album_rounded,
                                      volume: _drumsVol,
                                      isMuted: _muteState['drums']!,
                                      onMuteToggle: isStemsReady ? () {
                                        final muted = !_muteState['drums']!;
                                        setState(() => _muteState['drums'] = muted);
                                        controller.playerService.muteStem('drums', muted);
                                      } : null,
                                      onChanged: isStemsReady ? (val) {
                                        setState(() => _drumsVol = val);
                                        controller.playerService.setStemVolume('drums', val);
                                      } : (val) {},
                                    ),
                                  );
                                }

                                if (showPiano) {
                                  sliders.add(
                                    StemVerticalSlider(
                                      label: 'Piano',
                                      icon: Icons.piano_rounded,
                                      volume: _pianoVol,
                                      isMuted: _muteState['piano']!,
                                      onMuteToggle: isStemsReady ? () {
                                        final muted = !_muteState['piano']!;
                                        setState(() => _muteState['piano'] = muted);
                                        controller.playerService.muteStem('piano', muted);
                                      } : null,
                                      onChanged: isStemsReady ? (val) {
                                        setState(() => _pianoVol = val);
                                        controller.playerService.setStemVolume('piano', val);
                                      } : (val) {},
                                    ),
                                  );
                                }

                                if (showGuitar) {
                                  sliders.add(
                                    StemVerticalSlider(
                                      label: 'Gitar',
                                      icon: Icons.music_note_rounded,
                                      volume: _guitarVol,
                                      isMuted: _muteState['guitar']!,
                                      onMuteToggle: isStemsReady ? () {
                                        final muted = !_muteState['guitar']!;
                                        setState(() => _muteState['guitar'] = muted);
                                        controller.playerService.muteStem('guitar', muted);
                                      } : null,
                                      onChanged: isStemsReady ? (val) {
                                        setState(() => _guitarVol = val);
                                        controller.playerService.setStemVolume('guitar', val);
                                      } : (val) {},
                                    ),
                                  );
                                }

                                if (showOther) {
                                  sliders.add(
                                    StemVerticalSlider(
                                      label: 'Lain',
                                      icon: Icons.blur_on_rounded,
                                      volume: _otherVol,
                                      isMuted: _muteState['other']!,
                                      onMuteToggle: isStemsReady ? () {
                                        final muted = !_muteState['other']!;
                                        setState(() => _muteState['other'] = muted);
                                        controller.playerService.muteStem('other', muted);
                                      } : null,
                                      onChanged: isStemsReady ? (val) {
                                        setState(() => _otherVol = val);
                                        controller.playerService.setStemVolume('other', val);
                                      } : (val) {},
                                    ),
                                  );
                                }

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: sliders.isEmpty
                                      ? [
                                          const Center(
                                            child: Text(
                                              'Tidak ada instrumen yang dipilih',
                                              style: TextStyle(color: Colors.white38, fontSize: 13),
                                            ),
                                          )
                                        ]
                                      : sliders,
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // Processing screen overlay
                      if (!isStemsReady)
                        Center(
                          child: LiquidGlassContainer(
                            borderRadius: 24,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isModelAvailable ? Icons.auto_awesome_rounded : Icons.lock_outline_rounded,
                                  color: primaryColor,
                                  size: 40,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  isModelAvailable ? 'Separation Belum Diproses' : 'Fitur Stem Tidak Aktif',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isModelAvailable
                                      ? 'Mulai pemisahan instrumen lagu menggunakan AI internal untuk mengaktifkan console mixer 6-track.'
                                      : 'Pemisahan stem offline memerlukan file model. Silakan unduh model di tab Pengaturan.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  onPressed: project.stemStatus == AnalysisStatus.processing
                                      ? null
                                      : () async {
                                          if (isModelAvailable) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Memulai Pemisahan Stem...')),
                                            );
                                            await controller.runStemSeparation(
                                              processingMode: settingsController.settings.processingMode,
                                            );
                                          } else {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => const StudioSettingsScreen()),
                                            );
                                          }
                                        },
                                  child: Text(
                                    project.stemStatus == AnalysisStatus.processing
                                        ? 'Memproses...'
                                        : (isModelAvailable ? 'Proses Sekarang' : 'Buka Pengaturan'),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Audio waveform track
                WaveformPlaceholder(
                  height: 56,
                  progress: _playbackProgress,
                  isPlaying: _isPlaying,
                  seedString: project.title,
                ),
                const SizedBox(height: 6),

                // Duration timeline
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_currentPosition), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    Text('-${_formatDuration(_totalDuration - _currentPosition)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 16),

                // Speed buttons
                LiquidGlassContainer(
                  borderRadius: 16,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_speedPresets.length, (i) {
                        final isSelected = _playbackSpeed == _speedPresets[i];
                        return GestureDetector(
                          onTap: () async {
                            setState(() => _playbackSpeed = _speedPresets[i]);
                            await controller.playerService.setPlaybackSpeed(_speedPresets[i]);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor.withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? primaryColor : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              _speedLabels[i],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sub-tabs switcher (Akor, Lirik, Info)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSubTabButton(0, 'Akor', primaryColor),
                    _buildSubTabButton(1, 'Lirik', primaryColor),
                    _buildSubTabButton(2, 'Info', primaryColor),
                  ],
                ),
                const SizedBox(height: 8),

                // Inline tab content
                SizedBox(
                  height: 56,
                  child: _buildTabContent(project, primaryColor),
                ),
                const SizedBox(height: 12),

                // Transport player controls
                TransportControls(
                  isPlaying: _isPlaying,
                  onPlayPause: () async {
                    try {
                      if (_isPlaying) {
                        await controller.playerService.pause();
                      } else {
                        await controller.playerService.play();
                      }
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: 16),

                // Details key/bpm footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      project.bpm != null ? '${project.bpm!.toInt()} BPM' : 'BPM: -',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      project.keySignature != null ? 'KUNCI: ${project.keySignature}' : 'KUNCI: -',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(AudioProject project, Color primaryColor) {
    switch (_activeTab) {
      case 0: // Akor — show active chord
        final controller = Provider.of<ProjectController>(context);
        final activeChord = controller.activeChordSegment;
        final chords = project.chordSegments;

        if (chords.isEmpty) {
          return Center(
            child: Text(
              'Belum ada data akor',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
            ),
          );
        }

        // Find next chord
        final currentMs = _currentPosition.inMilliseconds;
        ChordSegment? nextChord;
        for (final c in chords) {
          if (c.startTimeMs > currentMs) {
            nextChord = c;
            break;
          }
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Active chord
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activeChord?.chordName ?? '—',
                    style: TextStyle(
                      color: activeChord != null ? Colors.white : Colors.white38,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text('AKTIF', style: TextStyle(color: primaryColor, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            ),
            if (nextChord != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward_rounded, color: Colors.white24, size: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(nextChord.chordName, style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('BERIKUT', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              ),
            ],
            const Spacer(),
            // Quick link to full chord viewer
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChordViewerScreen())),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.open_in_new_rounded, color: Colors.white38, size: 16),
              ),
            ),
          ],
        );

      case 1: // Lirik — show synced lyrics
        final lyrics = project.lyricLines;
        if (lyrics.isEmpty) {
          return Center(
            child: Text(
              'Belum ada data lirik',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
            ),
          );
        }

        // Find current lyric line
        final currentMs = _currentPosition.inMilliseconds;
        LyricLine? activeLine;
        LyricLine? nextLine;
        for (int i = 0; i < lyrics.length; i++) {
          final line = lyrics[i];
          final nextTimeMs = (i + 1 < lyrics.length) ? lyrics[i + 1].timeMs : line.timeMs + 10000;
          if (currentMs >= line.timeMs && currentMs < nextTimeMs) {
            activeLine = line;
            if (i + 1 < lyrics.length) nextLine = lyrics[i + 1];
            break;
          }
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              activeLine?.text ?? lyrics.first.text,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (nextLine != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  nextLine.text,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        );

      case 2: // Info — project metadata
      default:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _infoChip(Icons.music_note_rounded, project.keySignature ?? '—', 'Kunci'),
            _infoChip(Icons.speed_rounded, project.bpm != null ? '${project.bpm!.toInt()}' : '—', 'BPM'),
            _infoChip(Icons.grid_4x4_rounded, project.timeSignature ?? '4/4', 'Birama'),
            _infoChip(
              Icons.layers_rounded,
              project.stemStatus == AnalysisStatus.ready ? 'Siap' : 'Belum',
              'Stem',
            ),
          ],
        );
    }
  }

  Widget _infoChip(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9)),
      ],
    );
  }

  Widget _buildSubTabButton(int index, String label, Color primaryColor) {
    final isSelected = _activeTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? primaryColor : Colors.transparent,
              width: 2.0,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white38,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

