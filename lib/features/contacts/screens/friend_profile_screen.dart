import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../features/calls/controllers/call_controller.dart';
import '../../../features/presence/controllers/presence_controller.dart';
import '../../../models/call_model.dart';
import '../../../models/user_model.dart';

/// Fiche profil d'un ami : sa photo en grand, son nom, son statut et sa bio
/// — ce qu'on voit en tapant sur la photo d'un contact, comme la fiche
/// "Infos du contact" de WhatsApp.
class FriendProfileScreen extends ConsumerWidget {
  const FriendProfileScreen({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isUserOnlineProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.primary,
            expandedHeight: 280,
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildPhotoHeader(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nom,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline ? AppColors.success : AppColors.textHint,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? 'En ligne' : 'Inactif',
                        style: TextStyle(
                          fontSize: 13,
                          color: isOnline ? AppColors.success : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildActionsRow(context, ref),
                  const SizedBox(height: 24),
                  _sectionLabel('À propos'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      (user.bio != null && user.bio!.trim().isNotEmpty)
                          ? user.bio!
                          : 'Cette personne n\'a pas encore ajouté de bio.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: (user.bio != null && user.bio!.trim().isNotEmpty)
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                        fontStyle: (user.bio != null && user.bio!.trim().isNotEmpty)
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Coordonnées'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.mail_outline, color: AppColors.textSecondary),
                      title: Text(user.email, style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Grande photo en tête d'écran ; si l'ami n'a pas de photo, un simple
  /// avatar générique agrandi à la place (jamais d'écran vide).
  Widget _buildPhotoHeader() {
    if (user.photo != null && user.photo!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: user.photo!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: AppColors.primaryDark),
        errorWidget: (context, url, error) => Container(
          color: AppColors.primaryDark,
          child: const Center(child: Icon(Icons.person, color: Colors.white, size: 96)),
        ),
      );
    }
    return Container(
      color: AppColors.primaryDark,
      child: Center(
        child: UserAvatar(userId: user.id, photoUrl: user.photo, radius: 70),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildActionsRow(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ProfileActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'Message',
            onPressed: () => context.push('${AppRoutes.chat}/${user.id}', extra: user),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ProfileActionButton(
            icon: Icons.call_outlined,
            label: 'Appel',
            onPressed: () => _startCall(context, ref, CallMediaType.audio),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ProfileActionButton(
            icon: Icons.videocam_outlined,
            label: 'Vidéo',
            onPressed: () => _startCall(context, ref, CallMediaType.video),
          ),
        ),
      ],
    );
  }

  Future<void> _startCall(BuildContext context, WidgetRef ref, CallMediaType mediaType) async {
    try {
      final call = await ref.read(callRepositoryProvider).createCall(
            receiverId: user.id,
            mediaType: mediaType,
          );
      if (!context.mounted) return;
      context.push(
        '${AppRoutes.call}/${call.id}',
        extra: CallRouteArgs(
          otherUserId: user.id,
          otherUserName: user.nom,
          otherUserPhoto: user.photo,
          mediaType: mediaType,
          isCaller: true,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lancer l\'appel.')),
      );
    }
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
