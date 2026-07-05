import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        _nameController.text = user.nom;
        _bioController.text = user.bio ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.errorNameRequired;
    }
    if (value.length < 2) {
      return 'Le nom doit contenir au moins 2 caracteres';
    }
    return null;
  }

  

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    final success = await ref.read(profileProvider.notifier).updateProfile(
      userId: user.id,
      nom: _nameController.text.trim(),
      bio: _bioController.text.trim(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.profileUpdated),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  Future<void> _handleChangePhoto() async {
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildPhotoSourceSheet(),
    );

    if (result == null) return;

    final photoUrl = await ref.read(profileProvider.notifier).pickAndUploadPhoto(result);

    if (photoUrl != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo mise a jour'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleDeletePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la photo'),
        content: const Text('Etes-vous sur de vouloir supprimer votre photo de profil ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(profileProvider.notifier).deletePhoto();

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo supprimee'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);

    ref.listen<ProfileState>(profileProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(profileProvider.notifier).clearError();
      }
    });

    final user = authState.user;

    if (user == null) {
      return const Scaffold(body: LoadingWidget());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          AppStrings.editProfile,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: LoadingOverlay(
        isLoading: profileState.isUploadingPhoto,
        message: 'Chargement...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPhotoSection(user?.photo),
                const SizedBox(height: 40),
                CustomTextField(
                  label: AppStrings.name,
                  controller: _nameController,
                  hintText: 'Votre nom',
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.done,
                  validator: _validateName,
                ),
                CustomTextField(
                  label: 'Bio',
                  controller: _bioController,
                  hintText: 'Parlez un peu de vous...',
                  prefixIcon: Icons.description_outlined,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 40),
                CustomButton(
                  text: AppStrings.saveChanges,
                  onPressed: _handleSave,
                  isLoading: profileState.isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection(String? photoUrl) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 2),
                image: photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: AppColors.surfaceDark,
              ),
              child: photoUrl == null
                  ? const Icon(
                      Icons.person,
                      size: 60,
                      color: AppColors.textSecondary,
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _handleChangePhoto,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _handleChangePhoto,
          child: Text(
            AppStrings.changePhoto,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (photoUrl != null)
          TextButton(
            onPressed: _handleDeletePhoto,
            child: Text(
              AppStrings.removePhoto,
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoSourceSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Choisir une source',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSourceOption(
                icon: Icons.camera_alt,
                label: 'Appareil photo',
                source: ImageSource.camera,
              ),
              _buildSourceOption(
                icon: Icons.photo_library,
                label: 'Galerie',
                source: ImageSource.gallery,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, source),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
