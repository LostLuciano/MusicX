import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/input_level_meter.dart';
import '../../widgets/waveform_placeholder.dart';
import '../../state/project_controller.dart';
import '../../models/audio_project.dart';
import '../live_recording/live_recording_screen.dart';

class RecordSetupScreen extends StatefulWidget {
  const RecordSetupScreen({super.key});

  @override
  State<RecordSetupScreen> createState() => _RecordSetupScreenState();
}

class _RecordSetupScreenState extends State<RecordSetupScreen> {
  int _selectedMode = 0;
  bool _recordWithCamera = false;
  bool _useFrontCamera = false;
  int _monitoringMode = 1;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    setState(() => _hasPermission = status.isGranted);
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    setState(() => _hasPermission = status.isGranted);
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akses mikrofon ditolak. Aktifkan di Pengaturan.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final controller = Provider.of<ProjectController>(context);
    final activeProject = controller.activeProject;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.4,
            colors: [Color(0xFF1A1035), Color(0xFF0D0B1A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Sesi Rekaman',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Permission Card
                  _glassCard(
                    tint: _hasPermission
                        ? const Color(0xFF00FF66).withValues(alpha: 0.06)
                        : Colors.redAccent.withValues(alpha: 0.06),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _hasPermission
                                ? const Color(0xFF00FF66).withValues(alpha: 0.12)
                                : Colors.redAccent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.mic_rounded,
                            color: _hasPermission ? const Color(0xFF00FF66) : Colors.redAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _hasPermission ? 'Mikrofon Siap' : 'Akses Mikrofon Diperlukan',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _hasPermission
                                    ? 'Routing: Hardware Built-in'
                                    : 'Izin diperlukan untuk merekam audio.',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (!_hasPermission)
                          TextButton(
                            onPressed: _requestPermission,
                            child: Text('Izinkan', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                          )
                        else
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF66)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Target project
                  _glassCard(
                    tint: primaryColor.withValues(alpha: 0.06),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.album_rounded, color: primaryColor, size: 13),
                            const SizedBox(width: 6),
                            Text(
                              'TARGET PROYEK',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          activeProject?.title ?? 'Draft Sesi Rekam Baru',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeProject != null
                              ? 'Rekaman akan disimpan ke proyek ini.'
                              : 'Proyek baru akan dibuat secara otomatis.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mode Recording
                  _sectionLabel('MODE REKAMAN'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _modeOption(0, Icons.mic_rounded, 'Audio Saja', 'Rekam instrumen atau vokal langsung.', primaryColor),
                      const SizedBox(width: 12),
                      _modeOption(1, Icons.layers_rounded, 'Overdub Mix', 'Rekam bersamaan dengan backing track.', primaryColor),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Camera Toggle
                  _glassCard(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.videocam_rounded, color: primaryColor, size: 20),
                                const SizedBox(width: 12),
                                const Text(
                                  'Rekam Video Sesi',
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: _recordWithCamera,
                              activeThumbColor: primaryColor,
                              activeTrackColor: primaryColor.withValues(alpha: 0.35),
                              onChanged: (val) async {
                                if (val) {
                                  final status = await Permission.camera.request();
                                  if (!context.mounted) return;
                                  if (!status.isGranted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Akses kamera ditolak.')),
                                    );
                                    return;
                                  }
                                }
                                setState(() => _recordWithCamera = val);
                              },
                            ),
                          ],
                        ),
                        if (_recordWithCamera) ...[
                          const Divider(color: Colors.white10, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Pilihan Lensa', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                              Row(
                                children: [
                                  _cameraChip('Belakang', false, primaryColor),
                                  const SizedBox(width: 8),
                                  _cameraChip('Depan', true, primaryColor),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // VU Monitor
                  _sectionLabel('MONITOR INPUT'),
                  const SizedBox(height: 10),
                  _glassCard(
                    child: Column(
                      children: [
                        const InputLevelMeter(level: 0.05, dbValue: '-42 dB'),
                        const SizedBox(height: 12),
                        const WaveformPlaceholder(height: 44, isPlaying: false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Headphone Monitoring
                  _sectionLabel('HEADPHONE MONITORING'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _monitorBtn(0, 'Off', Icons.volume_mute_rounded, primaryColor),
                      const SizedBox(width: 8),
                      _monitorBtn(1, 'Input', Icons.headphones_rounded, primaryColor),
                      const SizedBox(width: 8),
                      _monitorBtn(2, 'Mix', Icons.dynamic_feed_rounded, primaryColor),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Record Button
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            if (!_hasPermission) {
                              await _requestPermission();
                              if (!_hasPermission) return;
                            }
                            if (!context.mounted) return;

                            if (controller.activeProject == null) {
                              final now = DateTime.now();
                              controller.openProject(AudioProject(
                                id: '${now.millisecondsSinceEpoch}',
                                title: 'Rekam ${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}',
                                createdAt: now,
                                updatedAt: now,
                                status: ProjectStatus.draft,
                                stemStatus: AnalysisStatus.unavailable,
                                chordStatus: AnalysisStatus.unavailable,
                                beatStatus: AnalysisStatus.unavailable,
                                recordings: const [],
                              ));
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LiveRecordingScreen(
                                  recordWithCamera: _recordWithCamera,
                                  useFrontCamera: _useFrontCamera,
                                  isGuitarOnly: _selectedMode == 0,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withValues(alpha: 0.5),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.fiber_manual_record, color: Colors.white, size: 38),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Mulai Sesi Rekaman',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child, Color? tint}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                (tint ?? Colors.white.withValues(alpha: 0.07)),
                Colors.white.withValues(alpha: 0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _modeOption(int idx, IconData icon, String title, String subtitle, Color primaryColor) {
    final sel = _selectedMode == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = idx),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: sel
                      ? [primaryColor.withValues(alpha: 0.2), primaryColor.withValues(alpha: 0.06)]
                      : [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.02)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: sel ? primaryColor.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.07),
                  width: 1.5,
                ),
                boxShadow: sel ? [BoxShadow(color: primaryColor.withValues(alpha: 0.2), blurRadius: 14)] : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: sel ? primaryColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: sel ? primaryColor : Colors.white38, size: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(title, style: TextStyle(color: sel ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10, height: 1.4)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cameraChip(String label, bool isFront, Color primaryColor) {
    final sel = _useFrontCamera == isFront;
    return GestureDetector(
      onTap: () => setState(() => _useFrontCamera = isFront),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? primaryColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? primaryColor.withValues(alpha: 0.3) : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _monitorBtn(int index, String label, IconData icon, Color primaryColor) {
    final sel = _monitoringMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _monitoringMode = index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: sel
                      ? [primaryColor.withValues(alpha: 0.2), primaryColor.withValues(alpha: 0.05)]
                      : [Colors.white.withValues(alpha: 0.04), Colors.transparent],
                ),
                border: Border.all(color: sel ? primaryColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: sel ? Colors.white : Colors.white38, size: 16),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(color: sel ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.35),
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}
