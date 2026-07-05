import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/user_model.dart';
import '../repositories/profile_repository.dart';
import '../../auth/controllers/auth_controller.dart';

class ProfileState {
  const ProfileState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isUploadingPhoto = false,
  });

  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isUploadingPhoto;

  ProfileState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isUploadingPhoto,
  }) {
    return ProfileState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier(this._repository, this._authState) : super(const ProfileState()) {
    _init();
  }

  final ProfileRepository _repository;
  final AuthState _authState;

  void _init() {
    if (_authState.user != null) {
      state = state.copyWith(user: _authState.user);
    }
  }

  Future<void> loadProfile(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _repository.getProfile(userId);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur lors du chargement');
    }
  }

  Future<bool> updateProfile({
    required String userId,
    String? nom,
    String? bio,                    // ← Ajout
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _repository.updateProfile(
        userId: userId,
        nom: nom,
        bio: bio,                       // ← Ajout
      );
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur lors de la mise à jour');
      return false;
    }
  }

  Future<String?> pickAndUploadPhoto(ImageSource source) async {
    state = state.copyWith(isUploadingPhoto: true, error: null);

    try {
      final XFile? image;

      if (source == ImageSource.gallery) {
        image = await _repository.pickFromGallery();
      } else {
        image = await _repository.pickFromCamera();
      }

      if (image == null) {
        state = state.copyWith(isUploadingPhoto: false);
        return null;
      }

      final photoUrl = await _repository.uploadPhoto(image);

      if (photoUrl != null && state.user != null) {
        state = state.copyWith(
          user: state.user!.copyWith(photo: photoUrl),
          isUploadingPhoto: false,
        );
      }

      return photoUrl;
    } catch (e) {
      state = state.copyWith(isUploadingPhoto: false, error: 'Erreur lors de l\'upload');
      return null;
    }
  }

  Future<bool> deletePhoto() async {
    state = state.copyWith(isUploadingPhoto: true, error: null);

    try {
      await _repository.deletePhoto();

      if (state.user != null) {
        state = state.copyWith(
          user: state.user!.copyWith(photo: null),
          isUploadingPhoto: false,
        );
      }

      return true;
    } catch (e) {
      state = state.copyWith(isUploadingPhoto: false, error: 'Erreur lors de la suppression');
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(
    ref.watch(profileRepositoryProvider),
    ref.watch(authProvider),
  );
});
