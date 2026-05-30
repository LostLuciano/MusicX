import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';

class ProfileController with ChangeNotifier {
  final UserProfileService _profileService = UserProfileService();
  
  UserProfile? _profile;
  bool _isLoading = false;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    
    _profile = await _profileService.loadProfile();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateName(String newName) async {
    if (_profile == null) return;
    
    final updatedProfile = _profile!.copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    );
    
    await _profileService.saveProfile(updatedProfile);
    _profile = updatedProfile;
    notifyListeners();
  }

  Future<void> updateAvatar(File imageFile) async {
    if (_profile == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    // Delete old avatar if exists
    if (_profile!.avatarPath != null) {
      await _profileService.deleteAvatarImage(_profile!.avatarPath);
    }
    
    // Save new avatar
    final String? newAvatarPath = await _profileService.saveAvatarImage(imageFile);
    
    if (newAvatarPath != null) {
      final updatedProfile = _profile!.copyWith(
        avatarPath: newAvatarPath,
        updatedAt: DateTime.now(),
      );
      
      await _profileService.saveProfile(updatedProfile);
      _profile = updatedProfile;
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> removeAvatar() async {
    if (_profile == null) return;
    
    // Delete avatar file
    if (_profile!.avatarPath != null) {
      await _profileService.deleteAvatarImage(_profile!.avatarPath);
    }
    
    final updatedProfile = _profile!.copyWith(
      avatarPath: null,
      updatedAt: DateTime.now(),
    );
    
    await _profileService.saveProfile(updatedProfile);
    _profile = updatedProfile;
    notifyListeners();
  }

  Future<void> updateMembershipTier(String tier) async {
    if (_profile == null) return;
    
    final updatedProfile = _profile!.copyWith(
      membershipTier: tier,
      updatedAt: DateTime.now(),
    );
    
    await _profileService.saveProfile(updatedProfile);
    _profile = updatedProfile;
    notifyListeners();
  }

  Future<void> updateLevel(int level) async {
    if (_profile == null) return;
    
    final updatedProfile = _profile!.copyWith(
      level: level,
      updatedAt: DateTime.now(),
    );
    
    await _profileService.saveProfile(updatedProfile);
    _profile = updatedProfile;
    notifyListeners();
  }
}
