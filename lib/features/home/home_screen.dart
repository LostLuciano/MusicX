import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../core/theme/app_ui_theme.dart';
import '../../state/project_controller.dart';
import '../../state/profile_controller.dart';
import '../../state/studio_settings_controller.dart';
import '../../services/audio_import_service.dart';
import '../../models/audio_project.dart';
import '../stem_mixer/stem_mixer_screen.dart';
import '../chord_viewer/chord_viewer_screen.dart';
import '../beat_tempo/beat_tempo_screen.dart';
import '../project_library/project_library_screen.dart';
import '../record_setup/record_setup_screen.dart';
import '../project_detail/project_detail_screen.dart';
import '../profile/profile_sub_screens.dart';
import '../profile/edit_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  Future<void> _handleImportAudio(BuildContext context) async {
    final controller = Provider.of<ProjectController>(context, listen: false);
    final PickedMedia? file = await AudioImportService().pickAudioFile();
    if (!context.mounted) return;
    if (file == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await controller.importAudioAsProject(file);
      if (!context.mounted) return;
      Navigator.pop(context);
      if (controller.activeProject != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(title: controller.activeProject!.title),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal import: $e')));
    }
  }

  Future<void> _handleImportVideo(BuildContext context) async {
    final controller = Provider.of<ProjectController>(context, listen: false);
    final PickedMedia? file = await AudioImportService().pickVideoFile();
    if (!context.mounted) return;
    if (file == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await controller.importVideoAsProject(file);
      if (!context.mounted) return;
      Navigator.pop(context);
      if (controller.activeProject != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProjectDetailScreen(title: controller.activeProject!.title)),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
    }
  }

  void _handleQuickNewProject(BuildContext context) async {
    final controller = Provider.of<ProjectController>(context, listen: false);
    final now = DateTime.now();
    final proj = AudioProject(
      id: '${now.millisecondsSinceEpoch}',
      title: 'Sesi ${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}',
      createdAt: now,
      updatedAt: now,
      status: ProjectStatus.draft,
      stemStatus: AnalysisStatus.unavailable,
      chordStatus: AnalysisStatus.unavailable,
      beatStatus: AnalysisStatus.unavailable,
      recordings: const [],
    );
    await controller.updateProjectStatus(ProjectStatus.draft);
    controller.openProject(proj);
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordSetupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<StudioSettingsController>(context).settings;
    final primaryColor = Color(settings.themeColorValue);
    final ui = AppUITheme(style: settings.uiStyle, primary: primaryColor);

    return Scaffold(
      backgroundColor: ui.bgBase,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: ui.backgroundGradient),
            child: IndexedStack(
              index: _currentIndex == 2
                  ? 0
                  : (_currentIndex == 1 ? 1 : (_currentIndex == 3 ? 2 : (_currentIndex == 4 ? 3 : 0))),
              children: [
                _buildDashboard(ui),
                const ProjectLibraryScreen(),
                const RecordSetupScreen(),
                _buildProfile(ui),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AppBottomNav(
              currentIndex: _currentIndex,
              uiStyle: settings.uiStyle,
              onTap: (i) {
                if (i == 2) {
                  _showQuickActions(context, ui);
                } else {
                  setState(() => _currentIndex = i);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────── DASHBOARD ──────────────────────────
  Widget _buildDashboard(AppUITheme ui) {
    final controller = Provider.of<ProjectController>(context);
    final project = controller.activeProject;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDashboardHeader(ui),
            const SizedBox(height: 28),
            _buildActiveProjectBanner(ui, project),
            const SizedBox(height: 32),
            _buildSectionTitle(ui, 'Tools'),
            const SizedBox(height: 14),
            _buildFeatureGrid(ui, project),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardHeader(AppUITheme ui) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Studio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ui.titleSize,
                  fontWeight: ui.titleWeight,
                  letterSpacing: ui.isSpotify ? -1.5 : -0.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'AI Audio • Stem • Chord',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        _buildNotifButton(ui),
      ],
    );
  }

  Widget _buildNotifButton(AppUITheme ui) {
    return GestureDetector(
      child: _cardContainer(
        ui,
        padding: const EdgeInsets.all(10),
        child: const Icon(Icons.notifications_outlined, color: Colors.white70, size: 20),
      ),
    );
  }

  Widget _buildActiveProjectBanner(AppUITheme ui, AudioProject? project) {
    if (project == null) {
      return _cardContainer(
        ui,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle_outline_rounded, color: ui.accent, size: 16),
                const SizedBox(width: 8),
                Text(
                  'MULAI PROYEK BARU',
                  style: TextStyle(color: ui.accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Impor audio atau rekam sesi baru',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _actionChip(ui, Icons.audio_file_rounded, 'Impor Audio', () => _handleImportAudio(context)),
                const SizedBox(width: 10),
                _actionChip(ui, Icons.videocam_rounded, 'Impor Video', () => _handleImportVideo(context), secondary: true),
              ],
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProjectDetailScreen(title: project.title)),
      ),
      child: _cardContainer(
        ui,
        tint: ui.accent.withValues(alpha: 0.05),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ui.isSpotify ? 6 : 14),
                gradient: LinearGradient(colors: [ui.accent, ui.accent.withValues(alpha: 0.6)]),
              ),
              child: const Icon(Icons.music_video_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PROYEK AKTIF',
                    style: TextStyle(color: ui.accent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.3),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    project.title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${project.recordings.length} rekaman',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(AppUITheme ui, String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: ui.isSpotify ? 20 : 18,
        fontWeight: FontWeight.w800,
        letterSpacing: ui.isSpotify ? -0.5 : 0,
      ),
    );
  }

  Widget _buildFeatureGrid(AppUITheme ui, AudioProject? project) {
    final features = [
      _FeatureItem('Stem Mixer', 'Isolasi 6 instrumen AI', Icons.tune_rounded, ui.accent, () {
        if (project == null) { _noProjectSnack(); return; }
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StemMixerScreen()));
      }),
      _FeatureItem('Chord Viewer', 'Deteksi & visualisasi akor', Icons.music_note_rounded, const Color(0xFFFF8C37), () {
        if (project == null) { _noProjectSnack(); return; }
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ChordViewerScreen()));
      }),
      _FeatureItem('Tempo & Beat', 'BPM detection & metronom', Icons.speed_rounded, const Color(0xFF9D4EDD), () {
        if (project == null) { _noProjectSnack(); return; }
        Navigator.push(context, MaterialPageRoute(builder: (_) => const BeatTempoScreen()));
      }),
      _FeatureItem('Rekam Audio', 'Studio recording session', Icons.mic_rounded, const Color(0xFF00C7FF), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordSetupScreen()));
      }),
      _FeatureItem('Rekam Video', 'Performa live + visual', Icons.videocam_rounded, const Color(0xFFFF3B30), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordSetupScreen()));
      }),
      _FeatureItem('Library', 'Semua proyek audio', Icons.folder_open_rounded, const Color(0xFF00FF94), () {
        setState(() => _currentIndex = 1);
      }),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ui.isSpotify ? 2 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: ui.isSpotify ? 1.6 : 1.1,
      ),
      itemCount: features.length,
      itemBuilder: (_, i) => _buildFeatureCard(ui, features[i]),
    );
  }

  Widget _buildFeatureCard(AppUITheme ui, _FeatureItem item) {
    if (ui.isSpotify) {
      // Spotify: horizontal compact rows with album-art style left icon
      return GestureDetector(
        onTap: item.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: ui.bgSurface,
            borderRadius: BorderRadius.circular(ui.cardRadius),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(ui.cardRadius),
                    bottomLeft: Radius.circular(ui.cardRadius),
                  ),
                ),
                child: Icon(item.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      );
    }

    // Apple Music: glass card
    return GestureDetector(
      onTap: item.onTap,
      child: _cardContainer(
        ui,
        tint: item.color.withValues(alpha: 0.04),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(item.description, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _noProjectSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pilih atau impor proyek terlebih dahulu.')),
    );
  }

  // ─────────────────────────────────────── PROFILE ────────────────────────────
  Widget _buildProfile(AppUITheme ui) {
    final controller = Provider.of<ProjectController>(context);
    final profileController = Provider.of<ProfileController>(context);
    final count = controller.projects.length;
    final profile = profileController.profile;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        child: Column(
          children: [
            // Avatar
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              child: Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ui.accent, width: 2.5),
                      image: profile?.avatarPath != null
                          ? DecorationImage(
                              image: () {
                                final p = profile!;
                                final path = p.avatarPath!;
                                return (kIsWeb || path.startsWith('data:') || path.startsWith('http'))
                                    ? NetworkImage(path) as ImageProvider
                                    : FileImage(File(path));
                              }(),
                              fit: BoxFit.cover)
                          : null,
                      gradient: profile?.avatarPath == null
                          ? LinearGradient(colors: [ui.accent, ui.accent.withValues(alpha: 0.5)])
                          : null,
                    ),
                    child: profile?.avatarPath == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: ui.accent, shape: BoxShape.circle, border: Border.all(color: ui.bgBase, width: 2)),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(profile?.name ?? 'Musisi', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '${profile?.membershipTier ?? 'Free'} • Level ${profile?.level ?? 1}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
            ),
            const SizedBox(height: 32),
            _profileTile(ui, Icons.analytics_rounded, 'Analisis Proyek', '$count proyek', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectAnalysisScreen()))),
            _profileTile(ui, Icons.mic_none_rounded, 'Rekaman Tersimpan', '${controller.projects.expand((p) => p.recordings).length} file', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedRecordingsScreen()))),
            _profileTile(ui, Icons.settings_outlined, 'Pengaturan Studio', 'Tema, audio, hardware', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudioSettingsScreen()))),
            _profileTile(ui, Icons.info_outline_rounded, 'Tentang Aplikasi', 'v1.0.0 Stable', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutAppScreen()))),
          ],
        ),
      ),
    );
  }

  Widget _profileTile(AppUITheme ui, IconData icon, String title, String sub, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: _cardContainer(
          ui,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: ui.accent, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.25), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────── SHARED WIDGETS ─────────────────────

  Widget _cardContainer(AppUITheme ui, {required Widget child, Color? tint, EdgeInsets? padding}) {
    if (ui.isAppleMusic) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(ui.cardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: ui.blurAmount, sigmaY: ui.blurAmount),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ui.cardRadius),
              color: tint ?? Colors.white.withValues(alpha: 0.055),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: child,
          ),
        ),
      );
    }
    // Spotify: solid dark surface, no blur
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? ui.bgCard,
        borderRadius: BorderRadius.circular(ui.cardRadius),
      ),
      child: child,
    );
  }

  Widget _actionChip(AppUITheme ui, IconData icon, String label, VoidCallback onTap, {bool secondary = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: secondary ? Colors.white.withValues(alpha: 0.06) : ui.accent,
            borderRadius: BorderRadius.circular(ui.isSpotify ? 6 : 14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: secondary ? Colors.white60 : Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: secondary ? Colors.white60 : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickActions(BuildContext context, AppUITheme ui) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ui.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(ui.isSpotify ? 8 : 28))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tindakan Cepat', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.upload_file_rounded, color: ui.accent),
              title: const Text('Impor File Audio', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _handleImportAudio(context); },
            ),
            ListTile(
              leading: const Icon(Icons.mic_rounded, color: Color(0xFFFF8C37)),
              title: const Text('Rekam Sesi Baru', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _handleQuickNewProject(context); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _FeatureItem(this.title, this.description, this.icon, this.color, this.onTap);
}
