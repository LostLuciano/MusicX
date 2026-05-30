import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/project_controller.dart';
import '../../state/studio_settings_controller.dart';
import '../../models/audio_project.dart';
import '../../services/native_ios_audio_service.dart';
import '../../widgets/video_player_screen.dart';

// ── 1. PROJECT ANALYSIS SCREEN ───────────────────────────────────────────────
class ProjectAnalysisScreen extends StatelessWidget {
  const ProjectAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ProjectController>(context);
    final projects = controller.projects;
    final totalProjects = projects.length;
    final readyProjects = projects.where((p) => p.stemStatus == AnalysisStatus.ready).length;
    final totalRecordings = projects.expand((p) => p.recordings).length;

    // Calculate average BPM
    double avgBpm = 0;
    final bpmProjects = projects.where((p) => p.bpm != null).toList();
    if (bpmProjects.isNotEmpty) {
      avgBpm = bpmProjects.map((p) => p.bpm!).reduce((a, b) => a + b) / bpmProjects.length;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Analisis Proyek'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'METRIK STUDIO',
                style: TextStyle(
                  color: Color(0xFFFF2E93),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Grid of stats
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  _buildStatCard('Total Proyek', '$totalProjects', Icons.folder_open_rounded, const Color(0xFFFF2E93)),
                  _buildStatCard('Teranalisis', '$readyProjects', Icons.auto_awesome_rounded, const Color(0xFFFF8C37)),
                  _buildStatCard('Hasil Rekam', '$totalRecordings', Icons.mic_rounded, const Color(0xFF00C6FF)),
                  _buildStatCard('Rata-rata BPM', avgBpm > 0 ? '${avgBpm.toInt()}' : '—', Icons.speed_rounded, const Color(0xFFBB86FC)),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'DISTRIBUSI KUNCI NADA',
                style: TextStyle(
                  color: Color(0xFFFF8C37),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              if (projects.isEmpty)
                _buildEmptyState('Belum ada proyek untuk dianalisis.')
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131022),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
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
                                color: const Color(0xFFFF2E93).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                p.keySignature ?? 'C',
                                style: const TextStyle(color: Color(0xFFFF2E93), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131022),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
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
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF131022),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 13)),
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
    final controller = Provider.of<ProjectController>(context);
    
    // Flatten all recordings across all projects
    final List<({AudioProject project, RecordingTake take})> allTakes = [];
    for (final p in controller.projects) {
      for (final t in p.recordings) {
        allTakes.add((project: p, take: t));
      }
    }

    // Sort chronologically (newest first)
    allTakes.sort((a, b) => b.take.createdAt.compareTo(a.take.createdAt));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Rekaman Tersimpan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: allTakes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131022),
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
              padding: const EdgeInsets.all(24),
              itemCount: allTakes.length,
              itemBuilder: (context, index) {
                final item = allTakes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131022),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.take.type == RecordingType.video
                                ? Icons.videocam_rounded
                                : Icons.mic_rounded,
                            color: const Color(0xFFFF2E93),
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
                );
              },
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
    final settingsController = Provider.of<StudioSettingsController>(context);
    final settings = settingsController.settings;

    if (settingsController.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0C1B),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF2E93))),
      );
    }

    // Buffer size options
    final List<int> bufferSizes = [64, 128, 256, 512];
    final int bufferSizeIndex = bufferSizes.indexOf(settings.bufferSize);

    // Sample rate options
    final List<String> sampleRates = ['44.1 kHz', '48.0 kHz'];
    final int sampleRateIndex = sampleRates.indexOf(settings.sampleRate);

    // Processing mode options
    final List<String> processingModes = ['CPU Only', 'GPU Accel', 'Neural Engine'];
    final int processingModeIndex = processingModes.indexOf(settings.processingMode);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Pengaturan Studio'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
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
                      child: const Text('Reset', style: TextStyle(color: Color(0xFFFF2E93))),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AUDIO HARDWARE & BUFFERS',
                style: TextStyle(color: Color(0xFFFF2E93), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF131022),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    _buildSegmentedSetting(
                      'Buffer Size',
                      'Mengurangi latency vs load CPU',
                      bufferSizes.map((e) => '$e').toList(),
                      bufferSizeIndex,
                      (val) => settingsController.updateBufferSize(bufferSizes[val]),
                    ),
                    const Divider(color: Colors.white10, height: 28),
                    _buildSegmentedSetting(
                      'Sample Rate',
                      'Kualitas output PCM audio',
                      sampleRates,
                      sampleRateIndex,
                      (val) => settingsController.updateSampleRate(sampleRates[val]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'AKSELERASI AI & DSP',
                style: TextStyle(color: Color(0xFFFF8C37), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF131022),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    _buildSegmentedSetting(
                      'Mode CoreML',
                      'Unit komputasi akselerator',
                      processingModes,
                      processingModeIndex,
                      (val) => settingsController.updateProcessingMode(processingModes[val]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'FITUR STUDIO LAINNYA',
                style: TextStyle(color: Color(0xFF00C6FF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF131022),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeThumbColor: const Color(0xFFFF2E93),
                      activeTrackColor: const Color(0xFFFF2E93).withValues(alpha: 0.3),
                      title: const Text('Boost Latensi Rendah', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Mode eksklusif prioritas audio', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      value: settings.latencyBoost,
                      onChanged: (val) => settingsController.updateLatencyBoost(val),
                    ),
                    const Divider(color: Colors.white10, height: 16),
                    SwitchListTile(
                      activeThumbColor: const Color(0xFFFF2E93),
                      activeTrackColor: const Color(0xFFFF2E93).withValues(alpha: 0.3),
                      title: const Text('Monitoring Langsung (Direct)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Kirim input gitar langsung ke headphone', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      value: settings.hardwareMonitoring,
                      onChanged: (val) => settingsController.updateHardwareMonitoring(val),
                    ),
                    const Divider(color: Colors.white10, height: 16),
                    SwitchListTile(
                      activeThumbColor: const Color(0xFFFF2E93),
                      activeTrackColor: const Color(0xFFFF2E93).withValues(alpha: 0.3),
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
                                Text('${settings.autoSaveInterval} menit', style: const TextStyle(color: Color(0xFFFF2E93), fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              value: settings.autoSaveInterval.toDouble(),
                              min: 1,
                              max: 30,
                              divisions: 29,
                              activeColor: const Color(0xFFFF2E93),
                              inactiveColor: Colors.white10,
                              onChanged: (val) => settingsController.updateAutoSaveInterval(val.toInt()),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(color: Colors.white10, height: 16),
                    SwitchListTile(
                      activeThumbColor: const Color(0xFFFF2E93),
                      activeTrackColor: const Color(0xFFFF2E93).withValues(alpha: 0.3),
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
                                Text('${(settings.defaultMetronomeVolume * 100).toInt()}%', style: const TextStyle(color: Color(0xFFFF2E93), fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              value: settings.defaultMetronomeVolume,
                              min: 0.0,
                              max: 1.0,
                              divisions: 20,
                              activeColor: const Color(0xFFFF2E93),
                              inactiveColor: Colors.white10,
                              onChanged: (val) => settingsController.updateDefaultMetronomeVolume(val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'STATUS MODEL AI',
                style: TextStyle(color: Color(0xFF9D4EDD), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF131022),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    if (settingsController.isCheckingModels)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: Color(0xFFFF2E93)),
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
                              backgroundColor: const Color(0xFFFF2E93),
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
                            icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFFF2E93)),
                            label: const Text(
                              'Cek Ulang',
                              style: TextStyle(color: Color(0xFFFF2E93), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'INFORMASI SISTEM',
                style: TextStyle(color: Color(0xFF9D4EDD), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF131022),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Platform', 'iOS / iPadOS'),
                    const Divider(color: Colors.white10, height: 20),
                    _buildInfoRow('Audio Engine', 'AVAudioEngine'),
                    const Divider(color: Colors.white10, height: 20),
                    _buildInfoRow('ML Framework', 'CoreML + ANE'),
                    const Divider(color: Colors.white10, height: 20),
                    _buildInfoRow('DSP Pipeline', 'STFT / iSTFT'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedSetting(
    String title,
    String desc,
    List<String> options,
    int selectedIndex,
    Function(int) onSelected,
  ) {
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFFFF2E93) : Colors.transparent,
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Tentang Aplikasi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),
            Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2E93), Color(0xFFFF8C37)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2E93).withValues(alpha: 0.3),
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF131022),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: const Text(
                'Music Stem Studio adalah aplikasi studio latihan musisi terintegrasi dengan akselerasi hardware Apple Neural Engine (CoreML). Memungkinkan isolasi 6 instrumen, visualisasi akor dinamis berjalan, dan multitrack recording berkualitas studio.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
              ),
            ),
            const Spacer(),
            const Text(
              'Dikembangkan dengan ❤️ untuk Musisi Seluruh Dunia',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
