import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_project.dart';
import 'native_ios_audio_service.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final Map<String, AudioPlayer> _stemPlayers = {};
  final Map<String, double> _stemVolumes = {};
  final Map<String, bool> _stemMutes = {};
  AudioProject? _loadedProject;

  AudioPlayer get player => _player;

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
            _stemVolumes[stemName] = 1.0;
            _stemMutes[stemName] = false;
            
            await _setSource(p, path);
          }
        }
      }
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

  bool get _hasRealStems {
    if (_loadedProject == null || _loadedProject!.stemStatus != AnalysisStatus.ready) {
      return false;
    }
    final stems = _loadedProject!.stemFiles;
    if (stems == null) return false;
    final vocals = stems.vocals;
    if (vocals == null || vocals.isEmpty || vocals.startsWith('assets/')) {
      return false;
    }
    return true;
  }

  Future<void> play() async {
    if (_hasRealStems) {
      // Mute mixture, play stems
      await _player.setVolume(0.0);
      await _player.play();

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final stems = {
          'vocals': _loadedProject!.stemFiles?.vocals ?? '',
          'drums': _loadedProject!.stemFiles?.drums ?? '',
          'bass': _loadedProject!.stemFiles?.bass ?? '',
          'guitar': _loadedProject!.stemFiles?.guitar ?? '',
          'piano': _loadedProject!.stemFiles?.piano ?? '',
          'other': _loadedProject!.stemFiles?.other ?? '',
        };
        await NativeIosAudioService().playStemMix(stems);
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
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
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
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
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
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // Native seeking is handled by native audio engine syncing
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
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await NativeIosAudioService().setPlaybackSpeed(speed);
      } else {
        for (final p in _stemPlayers.values) {
          await p.setSpeed(speed);
        }
      }
    }
  }

  Future<void> setStemVolume(String stemName, double volume) async {
    _stemVolumes[stemName] = volume;
    if (_hasRealStems) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await NativeIosAudioService().setStemVolume(stemName, volume);
      } else {
        final p = _stemPlayers[stemName];
        if (p != null) {
          final isMuted = _stemMutes[stemName] ?? false;
          await p.setVolume(isMuted ? 0.0 : volume);
        }
      }
    }
  }

  Future<void> muteStem(String stemName, bool muted) async {
    _stemMutes[stemName] = muted;
    if (_hasRealStems) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await NativeIosAudioService().muteStem(stemName, muted);
      } else {
        final p = _stemPlayers[stemName];
        if (p != null) {
          final vol = _stemVolumes[stemName] ?? 1.0;
          await p.setVolume(muted ? 0.0 : vol);
        }
      }
    }
  }

  Future<void> soloStem(String stemName) async {
    if (_hasRealStems) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await NativeIosAudioService().soloStem(stemName);
      } else {
        for (final name in _stemPlayers.keys) {
          final p = _stemPlayers[name];
          if (p != null) {
            if (name == stemName) {
              final vol = _stemVolumes[name] ?? 1.0;
              final isMuted = _stemMutes[name] ?? false;
              await p.setVolume(isMuted ? 0.0 : vol);
            } else {
              await p.setVolume(0.0);
            }
          }
        }
      }
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
    for (final p in _stemPlayers.values) {
      await p.dispose();
    }
  }
}
