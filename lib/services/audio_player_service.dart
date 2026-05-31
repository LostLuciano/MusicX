import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_project.dart';
import 'native_ios_audio_service.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final Map<String, AudioPlayer> _stemPlayers = {};
  final Map<String, double> _stemVolumes = {};
  final Map<String, bool> _stemMutes = {};
  final Set<String> _soloedStems = {};
  AudioProject? _loadedProject;

  VoidCallback? onChanged;

  // A-B Looping states
  double? loopStartSeconds;
  double? loopEndSeconds;
  bool isLoopEnabled = false;

  // Count-in states
  bool countInEnabled = false;
  int countInBars = 1; // 1 or 2 bars
  bool _isCountingIn = false;
  bool get isCountingIn => _isCountingIn;

  // Pitch/Key shift states
  double _pitchShift = 0.0;
  double get pitchShift => _pitchShift;

  AudioPlayer get player => _player;

  AudioPlayerService() {
    _initLoopListener();
  }

  void _initLoopListener() {
    _player.positionStream.listen((pos) {
      if (isLoopEnabled && loopStartSeconds != null && loopEndSeconds != null) {
        final double posSec = pos.inMilliseconds / 1000.0;
        if (posSec >= loopEndSeconds!) {
          seek(Duration(milliseconds: (loopStartSeconds! * 1000).toInt()));
        }
      }
    });
  }

  Future<void> _setSource(AudioPlayer player, String path) async {
    try {
      if (path.startsWith('assets/')) {
        await player.setAsset(path);
      } else if (kIsWeb ||
          path.startsWith('blob:') ||
          path.startsWith('data:') ||
          path.startsWith('http:') ||
          path.startsWith('https:')) {
        await player.setUrl(path);
      } else {
        await player.setFilePath(path);
      }
    } catch (e) {
      debugPrint('Error setting source ($path): $e');
    }
  }

  Future<void> loadProjectAudio(AudioProject project) async {
    _loadedProject = project;
    try {
      if (project.originalAudioPath != null) {
        await _setSource(_player, project.originalAudioPath!);
      }

      // Dispose and clear old stem players
      for (final p in _stemPlayers.values) {
        await p.dispose();
      }
      _stemPlayers.clear();
      _stemVolumes.clear();
      _stemMutes.clear();
      _soloedStems.clear();

      if (project.stemStatus == AnalysisStatus.ready) {
        final stems = {
          'vocals': project.stemFiles?.vocals ?? '',
          'drums': project.stemFiles?.drums ?? '',
          'bass': project.stemFiles?.bass ?? '',
          'guitar': project.stemFiles?.guitar ?? '',
          'piano': project.stemFiles?.piano ?? '',
          'other': project.stemFiles?.other ?? '',
        };

        for (final entry in stems.entries) {
          final stemName = entry.key;
          final path = entry.value;
          if (path.isNotEmpty) {
            final p = AudioPlayer();
            _stemPlayers[stemName] = p;

            // Load saved volumes from the project if available, else default to 1.0
            final double savedVol = project.stemVolumes[stemName] ?? 1.0;
            _stemVolumes[stemName] = savedVol;
            _stemMutes[stemName] = false;

            await _setSource(p, path);
          }
        }
      }

      // Update volume routing initially
      await _updateAllEffectiveVolumes();
      onChanged?.call();
    } catch (e) {
      debugPrint('Error loading project audio file: $e');
    }
  }

  Future<void> loadFile(String path) async {
    _loadedProject = null;
    try {
      await _setSource(_player, path);
    } catch (e) {
      debugPrint('Error loading audio file: $e');
    }
  }

  double getStemVolume(String stemName) => _stemVolumes[stemName] ?? 1.0;
  bool isStemMuted(String stemName) => _stemMutes[stemName] ?? false;
  bool isStemSoloed(String stemName) => _soloedStems.contains(stemName);

  bool get _hasRealStems {
    if (_loadedProject == null || _loadedProject!.stemStatus != AnalysisStatus.ready) {
      return false;
    }
    final stems = _loadedProject!.stemFiles;
    if (stems == null) return false;
    final vocals = stems.vocals;
    if (vocals == null || vocals.isEmpty) {
      return false;
    }
    return true;
  }

  bool get _useNativeIosAudio {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    if (_loadedProject == null || _loadedProject!.stemFiles == null) {
      return false;
    }
    final vocals = _loadedProject!.stemFiles!.vocals;
    if (vocals == null || vocals.startsWith('assets/')) {
      return false;
    }
    return true;
  }

  double getEffectiveVolume(String stemName) {
    final double baseVolume = _stemVolumes[stemName] ?? 1.0;
    final bool isMuted = _stemMutes[stemName] ?? false;

    if (isMuted) return 0.0;

    if (_soloedStems.isNotEmpty) {
      if (!_soloedStems.contains(stemName)) {
        return 0.0;
      }
    }

    return baseVolume;
  }

  Future<void> _updateAllEffectiveVolumes() async {
    final stemsList = ['vocals', 'drums', 'bass', 'guitar', 'piano', 'other'];
    for (final stemName in stemsList) {
      final effVol = getEffectiveVolume(stemName);
      if (_hasRealStems) {
        if (_useNativeIosAudio) {
          await NativeIosAudioService().setStemVolume(stemName, effVol);
        } else {
          final p = _stemPlayers[stemName];
          if (p != null) {
            await p.setVolume(effVol);
          }
        }
      }
    }
  }

  Future<void> play() async {
    if (countInEnabled && _player.position == Duration.zero && _loadedProject != null && _loadedProject!.bpm != null) {
      _isCountingIn = true;
      onChanged?.call();

      final double bpm = _loadedProject!.bpm!;
      // Play native metronome for count-in
      if (_useNativeIosAudio) {
        int beatsPerBar = 4;
        final ts = _loadedProject!.timeSignature;
        if (ts != null && ts.contains('/')) {
          final parsed = int.tryParse(ts.split('/').first);
          if (parsed != null) {
            beatsPerBar = parsed;
          }
        }

        await NativeIosAudioService().setMetronomeVolume(1.0);
        await NativeIosAudioService().startMetronome(
          bpm: bpm,
          beatsPerBar: beatsPerBar,
        );
      }

      // Calculate delay based on time signature. Standard count-in is 1 bar (4 beats) or 2 bars (8 beats).
      final int beats = countInBars * 4;
      final double delayMs = (beats * 60.0 / bpm) * 1000.0;
      await Future.delayed(Duration(milliseconds: delayMs.toInt()));

      // Stop metronome after count-in
      if (_useNativeIosAudio) {
        await NativeIosAudioService().stopMetronome();
      }

      _isCountingIn = false;
      onChanged?.call();
    }

    if (_hasRealStems) {
      // Mute mixture, play stems
      await _player.setVolume(0.0);
      await _player.play();

      if (_useNativeIosAudio) {
        final stems = {
          'vocals': _loadedProject!.stemFiles?.vocals ?? '',
          'drums': _loadedProject!.stemFiles?.drums ?? '',
          'bass': _loadedProject!.stemFiles?.bass ?? '',
          'guitar': _loadedProject!.stemFiles?.guitar ?? '',
          'piano': _loadedProject!.stemFiles?.piano ?? '',
          'other': _loadedProject!.stemFiles?.other ?? '',
        };
        await NativeIosAudioService().playStemMix(
          stems,
          positionSeconds: _player.position.inMilliseconds / 1000.0,
        );
      } else {
        // Sync seek positions before playing
        final currentPos = _player.position;
        for (final p in _stemPlayers.values) {
          await p.seek(currentPos);
          await p.play();
        }
      }
    } else {
      await _player.setVolume(1.0);
      await _player.play();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    if (_hasRealStems) {
      if (_useNativeIosAudio) {
        await NativeIosAudioService().pauseStemMix();
      } else {
        for (final p in _stemPlayers.values) {
          await p.pause();
        }
      }
    }
  }

  Future<void> stop() async {
    await _player.stop();
    if (_hasRealStems) {
      if (_useNativeIosAudio) {
        await NativeIosAudioService().stopStemMix();
      } else {
        for (final p in _stemPlayers.values) {
          await p.stop();
        }
      }
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    if (_hasRealStems) {
      if (_useNativeIosAudio) {
        await NativeIosAudioService().seekStemMix(position.inMilliseconds / 1000.0);
      } else {
        for (final p in _stemPlayers.values) {
          await p.seek(position);
        }
      }
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _player.setSpeed(speed);
    if (_hasRealStems) {
      if (_useNativeIosAudio) {
        await NativeIosAudioService().setPlaybackSpeed(speed);
      } else {
        for (final p in _stemPlayers.values) {
          await p.setSpeed(speed);
        }
      }
    }
    onChanged?.call();
  }

  Future<void> setStemVolume(String stemName, double volume) async {
    _stemVolumes[stemName] = volume;
    await _updateAllEffectiveVolumes();
    onChanged?.call();
  }

  Future<void> muteStem(String stemName, bool muted) async {
    _stemMutes[stemName] = muted;
    await _updateAllEffectiveVolumes();
    onChanged?.call();
  }

  Future<void> toggleSoloStem(String stemName) async {
    if (_soloedStems.contains(stemName)) {
      _soloedStems.remove(stemName);
    } else {
      _soloedStems.add(stemName);
    }
    await _updateAllEffectiveVolumes();
    onChanged?.call();
  }

  Future<void> soloStem(String stemName) async {
    _soloedStems.clear();
    _soloedStems.add(stemName);
    await _updateAllEffectiveVolumes();
    onChanged?.call();
  }

  Future<void> resetMix() async {
    _stemVolumes.clear();
    _stemMutes.clear();
    _soloedStems.clear();
    final stemsList = ['vocals', 'drums', 'bass', 'guitar', 'piano', 'other'];
    for (final name in stemsList) {
      _stemVolumes[name] = 1.0;
      _stemMutes[name] = false;
    }
    await _updateAllEffectiveVolumes();
    onChanged?.call();
  }

  Future<void> applyPresetMix(Map<String, double> volumes) async {
    _soloedStems.clear();
    _stemMutes.clear();
    for (final entry in volumes.entries) {
      _stemVolumes[entry.key] = entry.value;
      _stemMutes[entry.key] = entry.value == 0.0;
    }
    await _updateAllEffectiveVolumes();
    onChanged?.call();
  }

  void setLoop(double start, double end, {bool enable = true}) {
    loopStartSeconds = start;
    loopEndSeconds = end;
    isLoopEnabled = enable;
    onChanged?.call();
  }

  void clearLoop() {
    loopStartSeconds = null;
    loopEndSeconds = null;
    isLoopEnabled = false;
    onChanged?.call();
  }

  Future<void> setPitchShift(double semitones) async {
    _pitchShift = semitones;
    if (_hasRealStems) {
      if (_useNativeIosAudio) {
        await NativeIosAudioService().setPitchShift(semitones);
      }
    }
    onChanged?.call();
  }

  Future<void> dispose() async {
    await _player.dispose();
    for (final p in _stemPlayers.values) {
      await p.dispose();
    }
  }
}
