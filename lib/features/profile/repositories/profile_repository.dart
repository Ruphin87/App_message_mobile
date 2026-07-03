import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../models/user_model.dart';

class ProfileRepository {
  ProfileRepository();

  final _client = SupabaseService.client;
  final _imagePicker = ImagePicker();

  Future<UserModel> getProfile(String userId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    return UserModel.fromJson(response);
  }

  Future<UserModel> updateProfile({
    required String userId,
    String? nom,
    String? bio,                    // ← Ajout
    String? photo,
  }) async {
    final updates = <String, dynamic>{};

    if (nom != null) updates['nom'] = nom;
    if (bio != null) updates['bio'] = bio;           // ← Ajout
    if (photo != null) updates['photo'] = photo;

    if (updates.isEmpty) {
      return getProfile(userId);
    }

    final response = await _client
        .from('users')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return UserModel.fromJson(response);
  }

  Future<String?> uploadPhoto(XFile image) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    final fileName = 'profile_$userId.jpg';
    final path = 'avatars/$fileName';

    final bytes = await image.readAsBytes();

    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);

    await _client.from('users').update({'photo': publicUrl}).eq('id', userId);

    return publicUrl;
  }

  Future<void> deletePhoto() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final fileName = 'profile_$userId.jpg';
    final path = 'avatars/$fileName';

    try {
      await _client.storage.from('avatars').remove([path]);
    } catch (e) {
      // Ignore if file doesn't exist
    }

    await _client.from('users').update({'photo': null}).eq('id', userId);
  }

  Future<XFile?> pickFromGallery() async {
    return await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
  }

  Future<XFile?> pickFromCamera() async {
    return await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
  }
}
