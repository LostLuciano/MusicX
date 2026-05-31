import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/project_controller.dart';
import '../../state/studio_settings_controller.dart';
import '../../models/audio_project.dart';
import '../../services/native_ios_audio_service.dart';
import '../../widgets/video_player_screen.dart';
import '../../widgets/liquid_glass_container.dart';

// ── 1. PROJECT ANALYSIS SCREEN ───────────────────────────────────────────────
class ProjectAnalysisScreen extends StatelessWidget {
  const ProjectAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final controller = Provider.of<ProjectController>(context);
    final projects = controller.projects;
    final totalProjects = projects.length;
    final readyProjects = projects.where((p) => p.stemStatus == AnalysisStatus.ready).length;
    final totalRecordings = projects.expand((p) => p.recordings).length;

    double avgBpm = 0;
    final bpmProjects = projects.where((p) => p.bpm != null).toList();
    if (bpmProjects.isNotEmpty) {
      avgBpm = bpmProjects.map((p) => p.bpm!).reduce((a, b) => a + b) / bpmProjects.length;
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
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
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Analisis Proyek',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'METRIK STUDIO',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _buildStatCard(context, 'Total Proyek', '$totalProjects', Icons.folder_open_rounded, primaryColor),
                      _buildStatCard(context, 'Teranalisis', '$readyProjects', Icons.auto_awesome_rounded, const Color(0xFFFF8C37)),
                      _buildStatCard(context, 'Hasil Rekam', '$totalRecordings', Icons.mic_rounded, const Color(0xFF00C6FF)),
                      _buildStatCard(context, 'Rata-rata BPM', avgBpm > 0 ? '${avgBpm.toInt()}' : '—', Icons.speed_rounded, const Color(0xFFBB86FC)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'DISTRIBUSI KUNCI NADA',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (projects.isEmpty)
                    _buildEmptyState('Belum ada proyek untuk dianalisis.')
                  else
                    LiquidGlassContainer(
                      borderRadius: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: projects.map((p) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.title,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      p.keySignature ?? 'C',
                                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return LiquidGlassContainer(
      borderRadius: 20,
      tintColor: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return LiquidGlassContainer(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      ),
    );
  }
}

// ── 2. SAVED RECORDINGS SCREEN ──────────────────────────────────────────────
class SavedRecordingsScreen extends StatefulWidget {
  const SavedRecordingsScreen({super.key});

  @override
  State<SavedRecordingsScreen> createState() => _SavedRecordingsScreenState();
}

class _SavedRecordingsScreenState extends State<SavedRecordingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final controller = Provider.of<ProjectController>(context);
    
    final List<({AudioProject project, RecordingTake take})> allTakes = [];
    for (final p in controller.projects) {
      for (final t in p.recordings) {
        allTakes.add((project: p, take: t));
      }
    }

    allTakes.sort((a, b) => b.take.createdAt.compareTo(a.take.createdAt));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0C1B), Color(0xFF151026)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Rekaman Tersimpan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: allTakes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.mic_off_rounded, size: 48, color: Colors.white24),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum Ada Hasil Rekaman',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Rekam performa Anda di menu studio.',
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: allTakes.length,
                        itemBuilder: (context, index) {
                          final item = allTakes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: LiquidGlassContainer(
                              borderRadius: 18,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        item.take.type == RecordingType.video
                                            ? Icons.videocam_rounded
                                            : Icons.mic_rounded,
                                        color: primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.take.title,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Proyek: ${item.project.title}',
                                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Tanggal: ${item.take.createdAt.day}/${item.take.createdAt.month}/${item.take.createdAt.year}',
                                            style: const TextStyle(color: Colors.white24, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.ios_share_rounded, color: Colors.white70, size: 20),
                                      onPressed: () async {
                                        try {
                                          await NativeIosAudioService().shareFile(item.take.filePath);
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Gagal share file: $e')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 24),
                                      onPressed: () async {
                                        if (item.take.type == RecordingType.video) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => VideoPlayerScreen(
                                                filePath: item.take.filePath,
                                                title: item.take.title,
                                              ),
                                            ),
                                          );
                                        } else {
                                          try {
                                            await controller.playerService.loadFile(item.take.filePath);
                                            await controller.playerService.play();
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Gagal memutar audio: $e')),
                                              );
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 3. STUDIO SETTINGS SCREEN ───────────────────────────────────────────────
class StudioSettingsScreen extends StatefulWidget {
  const StudioSettingsScreen({super.key});

  @override
  State<StudioSettingsScreen> createState() => _StudioSettingsScreenState();
}

class _StudioSettingsScreenState extends State<StudioSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final settingsController = Provider.of<StudioSettingsController>(context);
    final settings = settingsController.settings;

    if (settingsController.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0C1B),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF2E93))),
      );
    }

    final List<int> bufferSizes = [64, 128, 256, 512];
    final int bufferSizeIndex = bufferSizes.indexOf(settings.bufferSize);

    final List<String> sampleRates = ['44.1 kHz', '48.0 kHz'];
    final int sampleRateIndex = sampleRates.indexOf(settings.sampleRate);

    final List<String> processingModes = ['CPU Only', 'GPU Accel', 'Neural Engine'];
    final int processingModeIndex = processingModes.indexOf(settings.processingMode);

    final List<String> modelQualities = ['Model Ringan', 'Model Standar'];
    final int modelQualityIndex = modelQualities.indexOf(settings.modelQuality);

    final isAppleMusic = settings.uiStyle == 1;

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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Pengaturan Studio',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.restore_rounded, color: Colors.white70),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF131022),
                            title: const Text('Reset Pengaturan', style: TextStyle(color: Colors.white)),
                            content: const Text(
                              'Kembalikan semua pengaturan ke default?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Batal', style: TextStyle(color: Colors.white54)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('Reset', style: TextStyle(color: primaryColor)),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true && mounted) {
                          await settingsController.resetToDefaults();
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Pengaturan direset ke default')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── UI STYLE SELECTOR ──────────────────────────────
                      const Text(
                        'GAYA TAMPILAN',
                        style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        borderRadius: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tema UI Aplikasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              const Text('Pilih gaya visual untuk seluruh antarmuka.', style: TextStyle(color: Colors.white38, fontSize: 11)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _uiStyleOption(context, settingsController, 0, Icons.queue_music_rounded, 'Spotify', 'Gelap & Compact', const Color(0xFF1DB954)),
                                  const SizedBox(width: 10),
                                  _uiStyleOption(context, settingsController, 1, Icons.blur_on_rounded, 'Apple Music', 'Kaca & Elegan', primaryColor),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── GLASSY BOI SETTINGS ─────────────────────────────
                      const Text(
                        'GLASS EFFECTS',
                        style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        borderRadius: 20,
                        useGlobalSettings: false,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Refraction Mode
                              const Text('Refraction Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('Controls the refraction calculation method', style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 11)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _refractionModeChip(context, settingsController, 0, 'Standard', primaryColor),
                                  const SizedBox(width: 8),
                                  _refractionModeChip(context, settingsController, 1, 'Polar', primaryColor),
                                  const SizedBox(width: 8),
                                  _refractionModeChip(context, settingsController, 2, 'Prominent', primaryColor),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Divider(color: Colors.white10, height: 1),
                              const SizedBox(height: 20),

                              // Displacement Scale
                              _glassSlider(
                                context: context,
                                ctrl: settingsController,
                                label: 'Displacement Scale',
                                desc: 'Controls the intensity of edge distortion',
                                value: settings.glassDisplacement,
                                min: 0, max: 200,
                                displayValue: '${settings.glassDisplacement.toInt()}',
                                primaryColor: primaryColor,
                                onChanged: settingsController.updateGlassDisplacement,
                              ),

                              // Blur Amount
                              _glassSlider(
                                context: context,
                                ctrl: settingsController,
                                label: 'Blur Amount',
                                desc: 'Controls backdrop blur intensity',
                                value: settings.glassBlur,
                                min: 0, max: 5,
                                displayValue: settings.glassBlur.toStringAsFixed(1),
                                primaryColor: primaryColor,
                                onChanged: settingsController.updateGlassBlur,
                              ),

                              // Saturation
                              _glassSlider(
                                context: context,
                                ctrl: settingsController,
                                label: 'Saturation',
                                desc: 'Controls color saturation of the backdrop',
                                value: settings.glassSaturation,
                                min: 100, max: 200,
                                displayValue: '${settings.glassSaturation.toInt()}%',
                                primaryColor: primaryColor,
                                onChanged: settingsController.updateGlassSaturation,
                              ),

                              // Chromatic Aberration
                              _glassSlider(
                                context: context,
                                ctrl: settingsController,
                                label: 'Chromatic Aberration',
                                desc: 'Controls RGB channel separation intensity',
                                value: settings.glassChromaticAb,
                                min: 0, max: 10,
                                displayValue: settings.glassChromaticAb.toStringAsFixed(1),
                                primaryColor: primaryColor,
                                onChanged: settingsController.updateGlassChromaticAb,
                              ),

                              // Elasticity
                              _glassSlider(
                                context: context,
                                ctrl: settingsController,
                                label: 'Elasticity',
                                desc: 'Controls how much the glass reaches toward the cursor',
                                value: settings.glassElasticity,
                                min: 0, max: 1,
                                displayValue: settings.glassElasticity.toStringAsFixed(2),
                                primaryColor: primaryColor,
                                onChanged: settingsController.updateGlassElasticity,
                              ),

                              // Corner Radius
                              _glassSlider(
                                context: context,
                                ctrl: settingsController,
                                label: 'Corner Radius',
                                desc: 'Controls the roundness of the glass corners',
                                value: settings.glassCornerRadius,
                                min: 4, max: 64,
                                displayValue: '${settings.glassCornerRadius.toInt()}px',
                                primaryColor: primaryColor,
                                onChanged: settingsController.updateGlassCornerRadius,
                              ),

                              const Divider(color: Colors.white10, height: 20),

                              // Over Light Toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Over Light', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text('Tint glass dark for bright backgrounds', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: settings.glassOverLight,
                                    activeThumbColor: primaryColor,
                                    activeTrackColor: primaryColor.withValues(alpha: 0.3),
                                    onChanged: settingsController.updateGlassOverLight,
                                  ),
                                ],
                              ),

                              // Live Preview Card
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(settings.glassCornerRadius),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: settings.glassBlur * 40,
                                    sigmaY: settings.glassBlur * 40,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(settings.glassCornerRadius),
                                      gradient: LinearGradient(
                                        colors: settings.glassOverLight
                                            ? [Colors.black.withValues(alpha: 0.2), Colors.black.withValues(alpha: 0.1)]
                                            : [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.03)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.visibility_rounded, color: primaryColor, size: 18),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Live Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                            Text('Blur ${(settings.glassBlur * 40).toInt()}px  •  CA ${settings.glassChromaticAb.toStringAsFixed(1)}  •  R${settings.glassCornerRadius.toInt()}px', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // COLOR SELECTOR SCREEN
                      const Text(
                        'PILIHAN TEMA UTAMA',
                        style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        borderRadius: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Warna Primer Aplikasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              const Text('Pilih skema warna utama antarmuka studio Anda.', style: TextStyle(color: Colors.white38, fontSize: 11)),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _colorOption(context, settingsController, const Color(0xFFFF2E93)),
                                  _colorOption(context, settingsController, const Color(0xFFFF8C37)),
                                  _colorOption(context, settingsController, const Color(0xFF00FF66)),
                                  _colorOption(context, settingsController, const Color(0xFF00C6FF)),
                                  _colorOption(context, settingsController, const Color(0xFFBB86FC)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'AUDIO HARDWARE & BUFFERS',
                        style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        borderRadius: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildSegmentedSetting(
                                context,
                                'Buffer Size',
                                'Mengurangi latency vs load CPU',
                                bufferSizes.map((e) => '$e').toList(),
                                bufferSizeIndex,
                                (val) => settingsController.updateBufferSize(bufferSizes[val]),
                              ),
                              const Divider(color: Colors.white10, height: 28),
                              _buildSegmentedSetting(
                                context,
                                'Sample Rate',
                                'Kualitas output PCM audio',
                                sampleRates,
                                sampleRateIndex,
                                (val) => settingsController.updateSampleRate(sampleRates[val]),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'AKSELERASI AI & DSP',
                        style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        borderRadius: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSegmentedSetting(
                                context,
                                'Mode CoreML',
                                'Unit komputasi akselerator',
                                processingModes,
                                processingModeIndex,
                                (val) => settingsController.updateProcessingMode(processingModes[val]),
                              ),
                              const Divider(color: Colors.white10, height: 28),
                              _buildSegmentedSetting(
                                context,
                                'Model Pemisahan',
                                'Ukuran & presisi neural network',
                                modelQualities,
                                modelQualityIndex,
                                (val) => settingsController.updateModelQuality(modelQualities[val]),
                              ),
                              const Divider(color: Colors.white10, height: 28),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.bolt_rounded, color: primaryColor, size: 16),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Panduan Akselerasi & Kinerja:',
                                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 11, height: 1.4),
                                      children: [
                                        const TextSpan(
                                          text: '• CPU Only: ',
                                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                        ),
                                        const TextSpan(
                                          text: 'Lambat. Aman untuk seluruh tipe iPhone, namun memakan waktu lebih lama karena beban komputasi AI yang berat.\n',
                                          style: TextStyle(color: Colors.white38),
                                        ),
                                        const TextSpan(
                                          text: '• GPU Accel: ',
                                          style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                                        ),
                                        const TextSpan(
                                          text: 'Cepat. Menggunakan akselerasi grafis Metal GPU untuk rendering paralel yang lebih responsif.\n',
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                        TextSpan(
                                          text: '• Neural Engine: ',
                                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                                        ),
                                        const TextSpan(
                                          text: 'Paling Cepat (Direkomendasikan). Menggunakan Apple Neural Engine (ANE) khusus chip Apple Silicon untuk performa 3x - 5x lebih cepat dan hemat baterai.\n\n',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        const TextSpan(
                                          text: '• Model Ringan: ',
                                          style: TextStyle(color: Color(0xFF00FF66), fontWeight: FontWeight.bold),
                                        ),
                                        const TextSpan(
                                          text: 'Inference 15-30 detik. FP16 (Half Precision) terkompresi dengan performa stabil dan memori rendah. Sangat direkomendasikan untuk menghindari crash pada iPhone.\n',
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                        const TextSpan(
                                          text: '• Model Standar: ',
                                          style: TextStyle(color: Color(0xFF00C6FF), fontWeight: FontWeight.bold),
                                        ),
                                        const TextSpan(
                                          text: 'Inference 2-3 menit. FP32 (Full Precision) dengan kualitas isolasi vokal/instrumen maksimal, namun membutuhkan RAM besar dan prosesor cepat.',
                                          style: TextStyle(color: Colors.white60),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'FITUR STUDIO LAINNYA',
                        style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        borderRadius: 20,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              SwitchListTile.adaptive(
                                activeThumbColor: primaryColor,
                                activeTrackColor: primaryColor.withValues(alpha: 0.35),
                                title: const Text('Boost Latensi Rendah', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                subtitle: const Text('Mode eksklusif prioritas audio', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                value: settings.latencyBoost,
                                onChanged: (val) => settingsController.updateLatencyBoost(val),
                              ),
                              const Divider(color: Colors.white10, height: 16),
                              SwitchListTile.adaptive(
                                activeThumbColor: primaryColor,
                                activeTrackColor: primaryColor.withValues(alpha: 0.35),
                                title: const Text('Monitoring Langsung (Direct)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                subtitle: const Text('Kirim input gitar langsung ke headphone', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                value: settings.hardwareMonitoring,
                                onChanged: (val) => settingsController.updateHardwareMonitoring(val),
                              ),
                              const Divider(color: Colors.white10, height: 16),
                              SwitchListTile.adaptive(
                                activeThumbColor: primaryColor,
                                activeTrackColor: primaryColor.withValues(alpha: 0.35),
                                title: const Text('Auto-Save Proyek', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                subtitle: Text('Simpan otomatis setiap ${settings.autoSaveInterval} menit', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                value: settings.autoSave,
                                onChanged: (val) => settingsController.updateAutoSave(val),
                              ),
                              if (settings.autoSave) ...[
                                const Divider(color: Colors.white10, height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Interval Auto-Save', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                          Text('${settings.autoSaveInterval} menit', style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: primaryColor,
                                          inactiveTrackColor: Colors.white10,
                                          thumbColor: Colors.white,
                                          trackHeight: 3,
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                        ),
                                        child: Slider(
                                          value: settings.autoSaveInterval.toDouble(),
                                          min: 1,
                                          max: 30,
                                          divisions: 29,
                                          onChanged: (val) => settingsController.updateAutoSaveInterval(val.toInt()),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Divider(color: Colors.white10, height: 16),
                              SwitchListTile.adaptive(
                                activeThumbColor: primaryColor,
                                activeTrackColor: primaryColor.withValues(alpha: 0.35),
                                title: const Text('Metronome Saat Rekam', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                subtitle: const Text('Aktifkan metronome otomatis saat mulai rekam', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                value: settings.enableMetronomeOnRecord,
                                onChanged: (val) => settingsController.updateEnableMetronomeOnRecord(val),
                              ),
                              if (settings.enableMetronomeOnRecord) ...[
                                const Divider(color: Colors.white10, height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Volume Metronome', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                          Text('${(settings.defaultMetronomeVolume * 100).toInt()}%', style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: primaryColor,
                                          inactiveTrackColor: Colors.white10,
                                          thumbColor: Colors.white,
                                          trackHeight: 3,
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                        ),
                                        child: Slider(
                                          value: settings.defaultMetronomeVolume,
                                          min: 0.0,
                                          max: 1.0,
                                          divisions: 20,
                                          onChanged: (val) => settingsController.updateDefaultMetronomeVolume(val),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'STATUS MODEL AI',
                        style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        borderRadius: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (settingsController.isCheckingModels)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: CircularProgressIndicator(color: primaryColor),
                                  ),
                                )
                              else if (settingsController.modelsAvailability == null)
                                Column(
                                  children: [
                                    const Icon(Icons.cloud_download_rounded, size: 48, color: Colors.white24),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Cek Ketersediaan Model',
                                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Periksa apakah model CoreML tersedia',
                                      style: TextStyle(color: Colors.white38, fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: () => settingsController.checkModelsAvailability(),
                                      icon: const Icon(Icons.search_rounded, size: 18),
                                      label: const Text('Cek Model', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Model Tersedia',
                                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: settingsController.modelsAvailability!.allModelsAvailable
                                                ? const Color(0xFF00FF66).withValues(alpha: 0.15)
                                                : const Color(0xFFFF8C37).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${settingsController.modelsAvailability!.availableCount}/3',
                                            style: TextStyle(
                                              color: settingsController.modelsAvailability!.allModelsAvailable
                                                  ? const Color(0xFF00FF66)
                                                  : const Color(0xFFFF8C37),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    ...settingsController.modelsAvailability!.models.map((model) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: model.isAvailable
                                                    ? const Color(0xFF00FF66).withValues(alpha: 0.15)
                                                    : Colors.white.withValues(alpha: 0.05),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                model.isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                color: model.isAvailable ? const Color(0xFF00FF66) : Colors.white24,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    model.name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    model.description,
                                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (model.isAvailable && model.size != null)
                                              Text(
                                                model.size!,
                                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () => settingsController.checkModelsAvailability(),
                                      icon: Icon(Icons.refresh_rounded, size: 16, color: primaryColor),
                                      label: Text(
                                        'Cek Ulang',
                                        style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'INFORMASI SISTEM',
                        style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        borderRadius: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildInfoRow('Platform', kIsWeb ? 'Web Browser' : 'iOS / iPadOS'),
                              const Divider(color: Colors.white10, height: 20),
                              _buildInfoRow('Audio Engine', kIsWeb ? 'Web Audio API' : 'AVAudioEngine'),
                              const Divider(color: Colors.white10, height: 20),
                              _buildInfoRow('ML Framework', kIsWeb ? 'WebAssembly / ONNX' : 'CoreML + ANE'),
                              const Divider(color: Colors.white10, height: 20),
                              _buildInfoRow('DSP Pipeline', kIsWeb ? 'WebAudio ScriptProcessor' : 'STFT / iSTFT'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorOption(BuildContext context, StudioSettingsController controller, Color color) {
    final isSelected = controller.settings.themeColorValue == color.toARGB32();
    return GestureDetector(
      onTap: () => controller.updateThemeColor(color.toARGB32()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? color : Colors.transparent, width: 2.5),
          boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)] : [],
        ),
        child: Center(
          child: Container(
            width: 22, height: 22,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: isSelected ? const Icon(Icons.check_rounded, color: Colors.black, size: 13) : null,
          ),
        ),
      ),
    );
  }

  Widget _uiStyleOption(
    BuildContext context,
    StudioSettingsController controller,
    int styleIndex,
    IconData icon,
    String title,
    String subtitle,
    Color accent,
  ) {
    final sel = controller.settings.uiStyle == styleIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.updateUIStyle(styleIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: sel ? accent.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel ? accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.07), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: sel ? accent : Colors.white38, size: 24),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(color: sel ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
              if (sel) ...[
                const SizedBox(height: 6),
                Text('AKTIF', style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              ],
            ],
          ),
        ),
      ),
    );
  }


  Widget _refractionModeChip(
    BuildContext context,
    StudioSettingsController ctrl,
    int mode,
    String label,
    Color accent,
  ) {
    final sel = ctrl.settings.glassRefractionMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => ctrl.updateGlassRefractionMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: sel ? accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? accent.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.07)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: sel ? Colors.white : Colors.white38,
                fontSize: 11,
                fontWeight: sel ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassSlider({
    required BuildContext context,
    required StudioSettingsController ctrl,
    required String label,
    required String desc,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required Color primaryColor,
    required Future<void> Function(double) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(displayValue, style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: primaryColor,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: Colors.white,
              overlayColor: primaryColor.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: (v) => onChanged(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedSetting(

    BuildContext context,
    String title,
    String desc,
    List<String> options,
    int selectedIndex,
    Function(int) onSelected,
  ) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: List.generate(options.length, (index) {
              final isSel = selectedIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        options[index],
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ── 4. ABOUT APP SCREEN ──────────────────────────────────────────────────────
class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0C1B), Color(0xFF151026)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tentang Aplikasi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.music_video_rounded, size: 64, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Music Stem Studio',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Versi 1.0.0 Stable Build',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 32),
                LiquidGlassContainer(
                  borderRadius: 20,
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Music Stem Studio adalah aplikasi studio latihan musisi terintegrasi dengan akselerasi hardware Apple Neural Engine (CoreML). Memungkinkan isolasi 6 instrumen, visualisasi akor dinamis berjalan, dan multitrack recording berkualitas studio.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Dikembangkan untuk Komunitas Audio Profesional',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
