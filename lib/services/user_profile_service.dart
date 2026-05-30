import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';

class UserProfileService {
  static const String _profileKey = 'user_profile';
  final Uuid _uuid = const Uuid();

  Future<UserProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? profileJson = prefs.getString(_profileKey);

    if (profileJson != null) {
      final Map<String, dynamic> data = jsonDecode(profileJson);
      return UserProfile.fromJson(data);
    }

    // Create default profile
    final now = DateTime.now();
    final defaultProfile = UserProfile(
      id: _uuid.v4(),
      name: 'Musisi Baru',
      membershipTier: 'Free',
      level: 1,
      createdAt: now,
      updatedAt: now,
    );

    await saveProfile(defaultProfile);
    return defaultProfile;
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final String profileJson = jsonEncode(profile.toJson());
    await prefs.setString(_profileKey, profileJson);
  }

  Future<String?> saveAvatarImage(File imageFile) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String avatarDir = '${appDir.path}/avatars';
      await Directory(avatarDir).create(recursive: true);

      final String fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String targetPath = '$avatarDir/$fileName';

      await imageFile.copy(targetPath);
      return targetPath;
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteAvatarImage(String? avatarPath) async {
    if (avatarPath == null) return;
    try {
      final File file = File(avatarPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore deletion errors
    }
  }
}
