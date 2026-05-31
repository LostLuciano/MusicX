import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';
import '../models/audio_project.dart';
import '../services/project_repository.dart';
import '../services/audio_import_service.dart';
import '../services/audio_player_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/camera_recording_service.dart';
import '../services/native_ios_audio_service.dart';
import '../services/lyrics_service.dart';

class ProjectController with ChangeNotifier {
  final ProjectRepository _repository = ProjectRepository();
  final AudioImportService _importService = AudioImportService();
  final AudioPlayerService _playerService = AudioPlayerService();
  final AudioRecorderService _recorderService = AudioRecorderService();
  final CameraRecordingService _cameraService = CameraRecordingService();
  final LyricsService _lyricsService = LyricsService();
  final Uuid _uuid = const Uuid();

  List<AudioProject> _projects = [];
  AudioProject? _activeProject;
  bool _isLoading = false;
  bool _isRecording = false;
  bool _isSearchingLyrics = false;
  String? _recordingPath;

  ChordSegment? _activeChordSegment;

  List<AudioProject> get projects => _projects;
  AudioProject? get activeProject => _activeProject;
  bool get isLoading => _isLoading;
  bool get isRecording => _isRecording;
  bool get isSearchingLyrics => _isSearchingLyrics;
  String? get recordingPath => _recordingPath;
  ChordSegment? get activeChordSegment => _activeChordSegment;

  AudioPlayerService get playerService => _playerService;
  AudioRecorderService get recorderService => _recorderService;
  CameraRecordingService get cameraService => _cameraService;
  LyricsService get lyricsService => _lyricsService;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    _projects = await _repository.loadProjects();
    
    if (_projects.isEmpty) {
      await _loadDemoProjects();
    }
    
    _isLoading = false;
    notifyListeners();
    _setupPositionListener();
  }

  Future<void> _loadDemoProjects() async {
    final demos = [
      {'key': 'classical', 'title': 'Classical Demo (Chopin)', 'file': 'classical.caf'},
      {'key': 'trap', 'title': 'Trap Demo (Hip-hop)', 'file': 'trap.caf'},
      {'key': 'edm', 'title': 'EDM Demo (Electronic)', 'file': 'edm.caf'},
    ];

    for (final demo in demos) {
      final key = demo['key']!;
      final title = demo['title']!;
      final filename = demo['file']!;
      final id = 'demo_$key';
      
      try {
        final String jsonContent = await rootBundle.loadString('assets/samples/$key-analysis-data.json');
        final Map<String, dynamic> data = json.decode(jsonContent);

        final List<dynamic> rawChords = data['chords'] as List<dynamic>? ?? [];
        final List<ChordSegment> chordSegments = rawChords.map((c) {
          final double startTime = (c['startTime'] as num).toDouble();
          final double endTime = (c['endTime'] as num).toDouble();
          return ChordSegment(
            id: _uuid.v4(),
            chordName: c['name'] as String,
            startTimeMs: (startTime * 1000).toInt(),
            endTimeMs: (endTime * 1000).toInt(),
          );
        }).toList();

        final double bpm = (data['tempo'] as num?)?.toDouble() ?? 120.0;

        String keySig = 'C';
        if (data.containsKey('key')) {
          keySig = _mapPitchClassToKey(data['key'] as int);
        } else if (chordSegments.isNotEmpty) {
          keySig = chordSegments.first.chordName.split(':').first;
        }

        String? plainLyrics;
        String? syncedLyrics;
        List<LyricLine> lyricLines = [];
        try {
          final String lyricsContent = await rootBundle.loadString('assets/samples/$key-lyrics.json');
          final Map<String, dynamic> lyricsData = json.decode(lyricsContent);
          final List<dynamic> rawTranscript = lyricsData['transcript'] as List<dynamic>? ?? [];
          
          final List<String> plainLines = [];
          final List<String> lrcLines = [];
          for (final line in rawTranscript) {
            final double startTime = (line['start'] as num).toDouble();
            final String text = line['text'] as String? ?? '';
            plainLines.add(text);
            
            // Format time tag [mm:ss.xx]
            final minutes = (startTime / 60).floor();
            final seconds = (startTime % 60).toStringAsFixed(2).padLeft(5, '0');
            final timeTag = '[${minutes.toString().padLeft(2, '0')}:$seconds]';
            lrcLines.add('$timeTag$text');

            lyricLines.add(LyricLine(
              id: _uuid.v4(),
              timeMs: (startTime * 1000).toInt(),
              text: text,
            ));
          }
          plainLyrics = plainLines.join('\n');
          syncedLyrics = lrcLines.join('\n');
        } catch (_) {}

        final AudioProject project = AudioProject(
          id: id,
          title: title,
          originalAudioPath: 'assets/samples/$filename',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ProjectStatus.ready,
          stemStatus: AnalysisStatus.ready,
          chordStatus: AnalysisStatus.ready,
          beatStatus: AnalysisStatus.ready,
          bpm: bpm,
          keySignature: keySig,
          timeSignature: '4/4',
          stemFiles: const StemFiles(
            vocals: 'assets/samples/Vocals.m4a',
            drums: 'assets/samples/Drums.m4a',
            guitar: 'assets/samples/Guitar.m4a',
            bass: 'assets/samples/Others.m4a',
            piano: 'assets/samples/Others.m4a',
            other: 'assets/samples/Others.m4a',
          ),
          chordSegments: chordSegments,
          plainLyrics: plainLyrics,
          syncedLyrics: syncedLyrics,
          lyricLines: lyricLines,
        );

        await _repository.addProject(project);
        _projects.add(project);
      } catch (e) {
        debugPrint('Error loading demo project $key: $e');
      }
    }
  }

  void _setupPositionListener() {
    _playerService.player.positionStream.listen((pos) {
      if (_activeProject != null && _activeProject!.chordSegments.isNotEmpty) {
        final currentChord = getActiveChord(pos, _activeProject!.chordSegments);
        if (_activeChordSegment?.id != currentChord?.id) {
          _activeChordSegment = currentChord;
          notifyListeners();
        }
      }
    });
  }

  ChordSegment? getActiveChord(Duration position, List<ChordSegment> chords) {
    final int currentMs = position.inMilliseconds;
    for (final chord in chords) {
      if (currentMs >= chord.startTimeMs && currentMs < chord.endTimeMs) {
        return chord;
      }
    }
    return null;
  }

  void openProject(AudioProject project) {
    _activeProject = project;
    _activeChordSegment = null;
    _playerService.loadProjectAudio(project);
    notifyListeners();
  }

  Future<void> importAudioAsProject(PickedMedia file) async {
    _isLoading = true;
    notifyListeners();

    final AudioProject? newProj = await _importService.createProjectFromAudio(file);
    if (newProj != null) {
      await _repository.addProject(newProj);
      _projects.add(newProj);
      _activeProject = newProj;
      await _playerService.loadProjectAudio(newProj);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> importVideoAsProject(PickedMedia file) async {
    _isLoading = true;
    notifyListeners();

    final AudioProject? newProj = await _importService.createProjectFromVideo(file);
    if (newProj != null) {
      await _repository.addProject(newProj);
      _projects.add(newProj);
      _activeProject = newProj;
      await _playerService.loadProjectAudio(newProj);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createMashup(AudioProject projectA, AudioProject projectB) async {
    if (projectA.originalAudioPath == null || projectB.originalAudioPath == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final String id = _uuid.v4();
      final String dirPath = File(projectA.originalAudioPath!).parent.path;
      final String targetPath = '$dirPath/project_${id}_mashup.m4a';
      
      final nativeService = NativeIosAudioService();
      final String? resultPath = await nativeService.mixAudioFiles(
        projectA.originalAudioPath!,
        projectB.originalAudioPath!,
        targetPath,
      );
      
      if (resultPath != null) {
        final now = DateTime.now();
        final AudioProject mashupProj = AudioProject(
          id: id,
          title: 'Mashup: ${projectA.title} & ${projectB.title}',
          originalAudioPath: resultPath,
          createdAt: now,
          updatedAt: now,
          status: ProjectStatus.imported,
          stemStatus: AnalysisStatus.unavailable,
          chordStatus: AnalysisStatus.unavailable,
          beatStatus: AnalysisStatus.unavailable,
          stemFiles: const StemFiles(),
          recordings: const [],
        );
        
        await _repository.addProject(mashupProj);
        _projects.add(mashupProj);
        _activeProject = mashupProj;
        await _playerService.loadProjectAudio(mashupProj);
      }
    } catch (e) {
      debugPrint('Error creating mashup: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteProject(String id) async {
    await _repository.deleteProject(id);
    _projects.removeWhere((p) => p.id == id);
    if (_activeProject?.id == id) {
      _activeProject = null;
      _activeChordSegment = null;
      await _playerService.stop();
    }
    notifyListeners();
  }

  Future<bool> startRecording() async {
    final bool hasPermission = await _recorderService.requestPermission();
    if (!hasPermission) return false;

    final String? path = await _recorderService.startGuitarRecording();
    if (path != null) {
      _recordingPath = path;
      _isRecording = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<String?> stopRecording(RecordingType type, RecordingMode mode) async {
    if (!_isRecording) return null;

    final String? path = await _recorderService.stopGuitarRecording();
    _isRecording = false;
    _recordingPath = null;
    notifyListeners();

    if (path != null && _activeProject != null) {
      await addRecordingTake(path, type, mode);
    }
    return path;
  }

  Future<void> addRecordingTake(String filePath, RecordingType type, RecordingMode mode) async {
    if (_activeProject == null) return;

    final String takeId = _uuid.v4();
    final String extension = filePath.split('.').last;
    final String takeTitle = 'Take_${_activeProject!.recordings.length + 1}_$extension';

    final RecordingTake take = RecordingTake(
      id: takeId,
      projectId: _activeProject!.id,
      title: takeTitle,
      filePath: filePath,
      type: type,
      mode: mode,
      createdAt: DateTime.now(),
    );

    final List<RecordingTake> updatedRecordings = List.from(_activeProject!.recordings)..add(take);
    final AudioProject updatedProject = _activeProject!.copyWith(
      recordings: updatedRecordings,
      updatedAt: DateTime.now(),
    );

    _activeProject = updatedProject;
    final int index = _projects.indexWhere((p) => p.id == updatedProject.id);
    if (index != -1) {
      _projects[index] = updatedProject;
    }

    await _repository.updateProject(updatedProject);
    notifyListeners();
  }

  Future<void> addChordSegment(String chordName, int startTimeMs, int endTimeMs) async {
    if (_activeProject == null) return;

    final String chordId = _uuid.v4();
    final ChordSegment segment = ChordSegment(
      id: chordId,
      chordName: chordName,
      startTimeMs: startTimeMs,
      endTimeMs: endTimeMs,
    );

    final List<ChordSegment> updatedSegments = List.from(_activeProject!.chordSegments)..add(segment);
    // Sort segments chronologically by startTimeMs
    updatedSegments.sort((a, b) => a.startTimeMs.compareTo(b.startTimeMs));

    final AudioProject updatedProject = _activeProject!.copyWith(
      chordSegments: updatedSegments,
      chordStatus: AnalysisStatus.ready, // Set to ready since we have valid chord segments
      updatedAt: DateTime.now(),
    );

    _activeProject = updatedProject;
    final int index = _projects.indexWhere((p) => p.id == updatedProject.id);
    if (index != -1) {
      _projects[index] = updatedProject;
    }

    await _repository.updateProject(updatedProject);
    notifyListeners();
  }

  Future<void> deleteChordSegment(String chordId) async {
    if (_activeProject == null) return;

    final List<ChordSegment> updatedSegments = List.from(_activeProject!.chordSegments)
      ..removeWhere((c) => c.id == chordId);

    final AudioProject updatedProject = _activeProject!.copyWith(
      chordSegments: updatedSegments,
      chordStatus: updatedSegments.isEmpty ? AnalysisStatus.unavailable : AnalysisStatus.ready,
      updatedAt: DateTime.now(),
    );

    _activeProject = updatedProject;
    final int index = _projects.indexWhere((p) => p.id == updatedProject.id);
    if (index != -1) {
      _projects[index] = updatedProject;
    }

    await _repository.updateProject(updatedProject);
    notifyListeners();
  }

  Future<void> updateProjectStatus(ProjectStatus status) async {
    if (_activeProject == null) return;

    final AudioProject updatedProject = _activeProject!.copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );

    _activeProject = updatedProject;
    final int index = _projects.indexWhere((p) => p.id == updatedProject.id);
    if (index != -1) {
      _projects[index] = updatedProject;
    }

    await _repository.updateProject(updatedProject);
    notifyListeners();
  }

  Future<void> runProjectAnalysis({Map<String, bool>? enabledStems}) async {
    await runStemSeparation(enabledStems: enabledStems);
  }

  Future<void> runStemSeparation({Map<String, bool>? enabledStems, String? processingMode, String? modelQuality}) async {
    final project = _activeProject;
    if (project == null || project.originalAudioPath == null) return;

    _activeProject = project.copyWith(
      stemStatus: AnalysisStatus.processing,
      beatStatus: AnalysisStatus.processing,
      // Chord detection is kept separate/unavailable initially
      chordStatus: project.chordSegments.isNotEmpty ? AnalysisStatus.ready : AnalysisStatus.unavailable,
    );
    notifyListeners();

    try {
      final nativeService = NativeIosAudioService();
      
      Map<String, String> stemPaths = {};
      double tempo = 120.0;
      String keySig = 'C';

      final bool isNativeIOSSupported = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

      if (isNativeIOSSupported) {
        // 1. Separate stems with selected acceleration unit and model quality
        final rawStems = await nativeService.separateStems(
          project.originalAudioPath!,
          processingMode: processingMode,
          modelQuality: modelQuality,
        );
        stemPaths = Map<String, String>.from(rawStems);
        if (enabledStems != null) {
          stemPaths.removeWhere((key, value) => !(enabledStems[key] ?? false));
        }

        // 2. Analyze beats and tempo
        final beatTempoData = await nativeService.analyzeBeatsAndTempo(project.originalAudioPath!);
        tempo = (beatTempoData['tempo'] as num).toDouble();
        
        if (beatTempoData.containsKey('key')) {
          keySig = _mapPitchClassToKey(beatTempoData['key'] as int);
        }
      } else {
        // Use demo assets as mock stems, filtered by selection
        final mockPaths = {
          'vocals': 'assets/samples/Vocals.m4a',
          'drums': 'assets/samples/Drums.m4a',
          'guitar': 'assets/samples/Guitar.m4a',
          'bass': 'assets/samples/Others.m4a',
          'piano': 'assets/samples/Others.m4a',
          'other': 'assets/samples/Others.m4a',
        };
        stemPaths = {};
        mockPaths.forEach((key, path) {
          if (enabledStems == null || (enabledStems[key] ?? false)) {
            stemPaths[key] = path;
          }
        });
        tempo = 120.0;
        keySig = 'C';
      }

      final stemFiles = StemFiles(
        vocals: stemPaths['vocals'],
        bass: stemPaths['bass'],
        drums: stemPaths['drums'],
        piano: stemPaths['piano'],
        guitar: stemPaths['guitar'],
        other: stemPaths['other'],
      );

      // 3. Auto-fetch lyrics from LRCLIB
      String? plainLyrics = project.plainLyrics;
      String? syncedLyrics = project.syncedLyrics;
      List<LyricLine> lyricLines = List.from(project.lyricLines);

      if (lyricLines.isEmpty) {
        try {
          final query = project.title;
          final list = await _lyricsService.searchLyrics(query);
          if (list.isNotEmpty) {
            final matched = list.firstWhere(
              (item) => item['syncedLyrics'] != null && (item['syncedLyrics'] as String).isNotEmpty,
              orElse: () => list.first,
            );
            plainLyrics = matched['plainLyrics'] as String?;
            syncedLyrics = matched['syncedLyrics'] as String?;
            
            if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
              lyricLines = _lyricsService.parseLrc(syncedLyrics);
            } else if (plainLyrics != null && plainLyrics.isNotEmpty) {
              final splitLines = plainLyrics.split('\n');
              for (int i = 0; i < splitLines.length; i++) {
                lyricLines.add(LyricLine(
                  id: _uuid.v4(),
                  timeMs: 0,
                  text: splitLines[i].trim(),
                ));
              }
            }
          }
        } catch (le) {
          debugPrint('Auto lyric fetch failed: $le');
        }
      }

      // If lyrics are still empty and we are simulating (not native), populate mock lyrics
      if (lyricLines.isEmpty && !isNativeIOSSupported) {
        final durationMs = _playerService.player.duration?.inMilliseconds ?? 180000;
        final List<String> lyricTexts = [
          "Intro: Welcome to the studio",
          "Verse 1: Sing your heart out",
          "Pre-Chorus: Ready for the rise",
          "Chorus: This is a beautiful mix",
          "Verse 2: Instrument isolated stems",
          "Bridge: Feel the beat and tempo",
          "Outro: Fading away into silence"
        ];
        
        lyricLines = [];
        int currentMs = 0;
        int lyricIdx = 0;
        final List<String> plainLines = [];
        final List<String> syncedLines = [];
        
        while (currentMs < durationMs) {
          final text = lyricTexts[lyricIdx % lyricTexts.length];
          lyricLines.add(
            LyricLine(id: _uuid.v4(), timeMs: currentMs, text: text),
          );
          plainLines.add(text);
          
          final minutes = (currentMs ~/ 60000).toString().padLeft(2, '0');
          final seconds = ((currentMs % 60000) ~/ 1000).toString().padLeft(2, '0');
          final msPart = ((currentMs % 1000) ~/ 10).toString().padLeft(2, '0');
          syncedLines.add("[$minutes:$seconds.$msPart]$text");
          
          currentMs += 8000;
          lyricIdx++;
        }
        plainLyrics = plainLines.join('\n');
        syncedLyrics = syncedLines.join('\n');
      }

      _activeProject = _activeProject!.copyWith(
        stemStatus: AnalysisStatus.ready,
        beatStatus: AnalysisStatus.ready,
        stemFiles: stemFiles,
        bpm: tempo,
        keySignature: keySig,
        timeSignature: '4/4',
        status: ProjectStatus.ready,
        plainLyrics: plainLyrics,
        syncedLyrics: syncedLyrics,
        lyricLines: lyricLines,
        updatedAt: DateTime.now(),
      );

      // Update project in repository and refresh player loaded project
      await _repository.updateProject(_activeProject!);
      final index = _projects.indexWhere((p) => p.id == _activeProject!.id);
      if (index != -1) {
        _projects[index] = _activeProject!;
      }
      
      // Reload audio project configuration in player service to reflect stems are ready
      await _playerService.loadProjectAudio(_activeProject!);
      notifyListeners();
    } catch (e) {
      debugPrint('Stem separation and beat track failed: $e');
      _activeProject = project.copyWith(
        stemStatus: AnalysisStatus.error,
        beatStatus: AnalysisStatus.error,
      );
      notifyListeners();
    }
  }

  Future<void> runChordDetection() async {
    final project = _activeProject;
    if (project == null || project.originalAudioPath == null) return;

    _activeProject = project.copyWith(
      chordStatus: AnalysisStatus.processing,
    );
    notifyListeners();

    try {
      final nativeService = NativeIosAudioService();
      List<ChordSegment> chordSegments = [];

      final bool isNativeIOSSupported = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

      if (isNativeIOSSupported) {
        final chordData = await nativeService.analyzeChords(project.originalAudioPath!);
        chordSegments = chordData.map((c) {
          return ChordSegment(
            id: _uuid.v4(),
            chordName: c['name'] as String,
            startTimeMs: ((c['startTime'] as double) * 1000).toInt(),
            endTimeMs: ((c['endTime'] as double) * 1000).toInt(),
          );
        }).toList();
      } else {
        // Populate sample chords to the end of the song
        final durationMs = _playerService.player.duration?.inMilliseconds ?? 180000;
        final chordList = ['C:maj', 'G:maj', 'A:min', 'F:maj', 'D:min', 'E:min', 'A:maj', 'D:maj'];
        chordSegments = [];
        int currentMs = 0;
        int chordIdx = 0;
        const segmentDurationMs = 4000;
        
        while (currentMs < durationMs) {
          final endMs = (currentMs + segmentDurationMs).clamp(0, durationMs);
          chordSegments.add(
            ChordSegment(
              id: _uuid.v4(),
              chordName: chordList[chordIdx % chordList.length],
              startTimeMs: currentMs,
              endTimeMs: endMs,
            ),
          );
          currentMs = endMs;
          chordIdx++;
        }
      }

      _activeProject = _activeProject!.copyWith(
        chordStatus: AnalysisStatus.ready,
        chordSegments: chordSegments,
        updatedAt: DateTime.now(),
      );

      // Update project in repository and active state
      await _repository.updateProject(_activeProject!);
      final index = _projects.indexWhere((p) => p.id == _activeProject!.id);
      if (index != -1) {
        _projects[index] = _activeProject!;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Chord detection failed: $e');
      _activeProject = project.copyWith(
        chordStatus: AnalysisStatus.error,
      );
      notifyListeners();
    }
  }

  String _mapPitchClassToKey(int keyIndex) {
    const keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    if (keyIndex >= 0 && keyIndex < keys.length) {
      return keys[keyIndex];
    }
    return 'C';
  }

  Future<List<Map<String, dynamic>>> searchLyrics(String query) async {
    _isSearchingLyrics = true;
    notifyListeners();
    try {
      final results = await _lyricsService.searchLyrics(query);
      _isSearchingLyrics = false;
      notifyListeners();
      return results;
    } catch (_) {
      _isSearchingLyrics = false;
      notifyListeners();
      return [];
    }
  }

  Future<void> applyLyricsToProject(String projectId, Map<String, dynamic> lyricData) async {
    final projectIndex = _projects.indexWhere((p) => p.id == projectId);
    if (projectIndex == -1) return;

    final project = _projects[projectIndex];
    final String? plain = lyricData['plainLyrics'] as String?;
    final String? synced = lyricData['syncedLyrics'] as String?;
    
    List<LyricLine> lines = [];
    if (synced != null && synced.isNotEmpty) {
      lines = _lyricsService.parseLrc(synced);
    } else if (plain != null && plain.isNotEmpty) {
      final splitLines = plain.split('\n');
      for (int i = 0; i < splitLines.length; i++) {
        lines.add(LyricLine(
          id: _uuid.v4(),
          timeMs: 0,
          text: splitLines[i].trim(),
        ));
      }
    }

    final updated = project.copyWith(
      plainLyrics: plain,
      syncedLyrics: synced,
      lyricLines: lines,
    );

    _projects[projectIndex] = updated;
    if (_activeProject?.id == projectId) {
      _activeProject = updated;
    }
    await _repository.updateProject(updated);
    notifyListeners();
  }

  @override
  void dispose() {
    _playerService.dispose();
    _recorderService.dispose();
    _cameraService.dispose();
    super.dispose();
  }
}
