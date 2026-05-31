import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../widgets/project_list_tile.dart';
import '../../widgets/mini_player_bar.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../state/project_controller.dart';
import '../../services/audio_import_service.dart';
import '../project_detail/project_detail_screen.dart';

class ProjectLibraryScreen extends StatefulWidget {
  const ProjectLibraryScreen({super.key});

  @override
  State<ProjectLibraryScreen> createState() => _ProjectLibraryScreenState();
}

class _ProjectLibraryScreenState extends State<ProjectLibraryScreen> {
  int _selectedTab = 0; // 0: All, 1: Songs, 2: Sessions, 3: Imports
  bool _isPlaying = false;
  String _currentPlayingTitle = '';
  String _currentPlayingDetail = '';

  Future<void> _handleImportAudio(BuildContext context) async {
    final controller = Provider.of<ProjectController>(context, listen: false);
    final PickedMedia? file = await AudioImportService().pickAudioFile();
    if (!context.mounted) return;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batal memilih file.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await controller.importAudioAsProject(file);
      if (!context.mounted) return;
      Navigator.pop(context);

      if (controller.activeProject != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailScreen(
              title: controller.activeProject!.title,
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengimpor file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final controller = Provider.of<ProjectController>(context);
    final projects = controller.projects;

    final filteredProjects = projects.where((proj) {
      if (_selectedTab == 0) return true;
      if (_selectedTab == 1 && proj.status.toString().contains('ready')) return true;
      if (_selectedTab == 2 && proj.status.toString().contains('draft')) return true;
      if (_selectedTab == 3 && proj.status.toString().contains('imported')) return true;
      return false;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.2,
            colors: [Color(0xFF1A1035), Color(0xFF0D0B1A)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Studio Library',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${projects.length} track tersedia',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _glassButton(
                          context,
                          icon: Icons.add_rounded,
                          label: 'Impor',
                          color: primaryColor,
                          onTap: () => _handleImportAudio(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildSegmentedTabs(primaryColor),
                  ),
                  const SizedBox(height: 16),
                  if (projects.isEmpty)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: LiquidGlassContainer(
                            borderRadius: 28,
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.library_music_rounded, size: 44, color: primaryColor),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Library Masih Kosong',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Impor file audio untuk memulai analisis stem dan deteksi akor.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: () => _handleImportAudio(context),
                                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                                  label: const Text('Impor File Audio'),
                                  style: FilledButton.styleFrom(backgroundColor: primaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (filteredProjects.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Tidak ada proyek di kategori ini.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredProjects.length,
                        itemBuilder: (context, index) {
                          final proj = filteredProjects[index];
                          final isAct = controller.activeProject?.id == proj.id;
                          final bpmText = proj.bpm != null ? '${proj.bpm!.toInt()} BPM' : 'Belum dianalisis';
                          final keyText = proj.keySignature ?? 'Kunci: -';

                          return ProjectListTile(
                            title: proj.title,
                            keyName: keyText,
                            bpm: proj.bpm?.toInt() ?? 0,
                            duration: 'Audio',
                            date: '${proj.createdAt.day}/${proj.createdAt.month}/${proj.createdAt.year}',
                            isPlaying: _isPlaying && isAct,
                            onTap: () {
                              controller.openProject(proj);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProjectDetailScreen(title: proj.title),
                                ),
                              );
                            },
                            onPlayTap: () async {
                              controller.openProject(proj);
                              try {
                                if (_isPlaying && isAct) {
                                  await controller.playerService.pause();
                                  setState(() => _isPlaying = false);
                                } else {
                                  await controller.playerService.loadProjectAudio(proj);
                                  await controller.playerService.play();
                                  setState(() {
                                    _isPlaying = true;
                                    _currentPlayingTitle = proj.title;
                                    _currentPlayingDetail = '$keyText • $bpmText';
                                  });
                                  controller.playerService.player.processingStateStream.listen((state) {
                                    if (state == ProcessingState.completed && mounted) {
                                      setState(() => _isPlaying = false);
                                    }
                                  });
                                }
                              } catch (_) {}
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),

              // Floating mini player
              if (_currentPlayingTitle.isNotEmpty)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: MiniPlayerBar(
                      title: _currentPlayingTitle,
                      subtitle: _currentPlayingDetail,
                      isPlaying: _isPlaying,
                      onPlayPause: () async {
                        try {
                          if (_isPlaying) {
                            await controller.playerService.pause();
                          } else {
                            await controller.playerService.play();
                          }
                          setState(() => _isPlaying = !_isPlaying);
                        } catch (_) {}
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedTabs(Color primaryColor) {
    const tabs = ['Semua', 'Lagu', 'Sesi', 'Impor'];
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final sel = _selectedTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? primaryColor.withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        tabs[i],
                        style: TextStyle(
                          color: sel ? Colors.white : Colors.white.withValues(alpha: 0.45),
                          fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _glassButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
