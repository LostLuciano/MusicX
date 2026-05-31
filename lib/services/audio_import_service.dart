import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/audio_project.dart';
import 'native_ios_audio_service.dart';
import 'import_helper.dart';

class PickedMedia {
  final String path;
  final String name;
  final Uint8List? bytes;

  PickedMedia({required this.path, required this.name, this.bytes});
}

class AudioImportService {
  final Uuid _uuid = const Uuid();

  Future<PickedMedia?> pickAudioFile() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'caf', 'aiff', 'opus'],
        withData: kIsWeb, // Request bytes on web
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (kIsWeb) {
          return PickedMedia(
            path: '',
            name: file.name,
            bytes: file.bytes,
          );
        } else if (file.path != null) {
          return PickedMedia(
            path: file.path!,
            name: file.name,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<PickedMedia?> pickVideoFile() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.video,
        withData: kIsWeb, // Request bytes on web
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (kIsWeb) {
          return PickedMedia(
            path: '',
            name: file.name,
            bytes: file.bytes,
          );
        } else if (file.path != null) {
          return PickedMedia(
            path: file.path!,
            name: file.name,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> copyAudioToAppDirectory(String filePath, String id) async {
    if (kIsWeb) return null;
    try {
      final Directory docDir = await getApplicationDocumentsDirectory();
      final String extension = filePath.split('.').last;
      final String newPath = '${docDir.path}/project_${id}_mixture.$extension';
      final File file = File(filePath);
      final File copiedFile = await file.copy(newPath);
      return copiedFile.path;
    } catch (_) {
      return null;
    }
  }

  Future<AudioProject?> createProjectFromAudio(PickedMedia file) async {
    try {
      final String id = _uuid.v4();
      final String title = file.name.split('.').first;
      String? localAudioPath;

      if (kIsWeb) {
        if (file.bytes != null) {
          localAudioPath = createBlobUrl(file.bytes!);
        } else {
          localAudioPath = '';
        }
      } else {
        localAudioPath = await copyAudioToAppDirectory(file.path, id);
      }

      if (localAudioPath == null || (localAudioPath.isEmpty && !kIsWeb)) return null;

      final now = DateTime.now();
      return AudioProject(
        id: id,
        title: title,
        originalAudioPath: localAudioPath,
        createdAt: now,
        updatedAt: now,
        status: ProjectStatus.imported,
        stemStatus: AnalysisStatus.unavailable, // Unprocessed by default
        chordStatus: AnalysisStatus.unavailable,
        beatStatus: AnalysisStatus.unavailable,
        stemFiles: const StemFiles(),
        recordings: const [],
      );
    } catch (_) {
      return null;
    }
  }

  Future<AudioProject?> createProjectFromVideo(PickedMedia videoFile) async {
    try {
      final String id = _uuid.v4();
      final String title = videoFile.name.split('.').first;
      
      String? extractedPath;
      
      if (kIsWeb) {
        // Extracting audio from video locally on web isn't trivial.
        // We'll mock it by using the video file's blob URL as the audio source
        if (videoFile.bytes != null) {
          extractedPath = createBlobUrl(videoFile.bytes!);
        } else {
          extractedPath = '';
        }
      } else {
        final Directory docDir = await getApplicationDocumentsDirectory();
        final String targetAudioPath = '${docDir.path}/project_${id}_mixture.m4a';
        
        final nativeService = NativeIosAudioService();
        extractedPath = await nativeService.extractAudioFromVideo(
          videoFile.path,
          targetAudioPath,
        );
      }
      
      if (extractedPath == null || (extractedPath.isEmpty && !kIsWeb)) return null;
      
      final now = DateTime.now();
      return AudioProject(
        id: id,
        title: '$title (Video Extracted)',
        originalAudioPath: extractedPath,
        createdAt: now,
        updatedAt: now,
        status: ProjectStatus.imported,
        stemStatus: AnalysisStatus.unavailable,
        chordStatus: AnalysisStatus.unavailable,
        beatStatus: AnalysisStatus.unavailable,
        stemFiles: const StemFiles(),
        recordings: const [],
      );
    } catch (_) {
      return null;
    }
  }
}
