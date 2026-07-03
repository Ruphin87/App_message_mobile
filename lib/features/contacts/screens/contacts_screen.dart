import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/call_model.dart';
import '../../../models/friend_model.dart';
import '../../calls/controllers/call_controller.dart';
import '../controllers/contacts_controller.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Contacts',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.people_outline, color: AppColors.textPrimary),
                if (contactsState.pendingRequests.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${contactsState.pendingRequests.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.push(AppRoutes.friendRequests),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textPrimary),
            onPressed: () => context.push(AppRoutes.searchUser),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(contactsProvider.notifier).loadAll(),
        child: _buildBody(context, ref, contactsState),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ContactsState state) {
    if (state.isLoading && state.friends.isEmpty) {
      return const LoadingWidget(message: 'Chargement des contacts...');
    }

    if (state.friends.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.people_outline, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Aucun contact pour le moment',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.push(AppRoutes.searchUser),
              child: const Text('Rechercher des utilisateurs'),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.friends.length,
      itemBuilder: (context, index) {
        final friend = state.friends[index];
        return _buildContactTile(context, ref, friend);
      },
    );
  }

  Future<void> _startCall(
    BuildContext context,
    WidgetRef ref, {
    required FriendModel friend,
    required CallMediaType mediaType,
  }) async {
    final profile = friend.friendProfile;
    if (profile == null) return;

    try {
      final call = await ref.read(callRepositoryProvider).createCall(
            receiverId: profile.id,
            mediaType: mediaType,
          );
      if (!context.mounted) return;
      context.push(
        '${AppRoutes.call}/${call.id}',
        extra: CallRouteArgs(
          otherUserId: profile.id,
          otherUserName: profile.nom,
          otherUserPhoto: profile.photo,
          mediaType: mediaType,
          isCaller: true,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lancer l’appel.')),
      );
    }
  }

  Widget _buildContactTile(BuildContext context, WidgetRef ref, FriendModel friend) {
    final profile = friend.friendProfile;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: profile != null
            ? UserAvatar(
                userId: profile.id,
                photoUrl: profile.photo,
                radius: 24,
                showOnlineBadge: true,
              )
            : const CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.surfaceDark,
                child: Icon(Icons.person, color: AppColors.textSecondary),
              ),
        title: Text(
          profile?.nom ?? 'Utilisateur',
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          profile?.email ?? '',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Appel audio',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _startCall(context, ref, friend: friend, mediaType: CallMediaType.audio),
              icon: const Icon(Icons.call_outlined, color: AppColors.primary),
            ),
            IconButton(
              tooltip: 'Appel vidéo',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _startCall(context, ref, friend: friend, mediaType: CallMediaType.video),
              icon: const Icon(Icons.videocam_outlined, color: AppColors.primary),
            ),
          ],
        ),
        onTap: () {
          if (profile != null) {
            context.push('${AppRoutes.chat}/${profile.id}', extra: profile);
          }
        },
      ),
    );
  }
}
