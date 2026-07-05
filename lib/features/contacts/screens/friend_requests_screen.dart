import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/friend_model.dart';
import '../controllers/contacts_controller.dart';

class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Demandes d\'amis',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: contactsState.isLoading && contactsState.pendingRequests.isEmpty
          ? const LoadingWidget()
          : contactsState.pendingRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_email_read_outlined,
                          size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune demande en attente',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: contactsState.pendingRequests.length,
                  itemBuilder: (context, index) {
                    final request = contactsState.pendingRequests[index];
                    return _buildRequestTile(context, ref, request);
                  },
                ),
    );
  }

  Widget _buildRequestTile(BuildContext context, WidgetRef ref, FriendModel request) {
    final profile = request.friendProfile;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
      child: Row(
        children: [
          profile != null
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.nom ?? 'Utilisateur',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(
                  profile?.email ?? '',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: AppColors.success),
            onPressed: () => ref.read(contactsProvider.notifier).acceptRequest(request.id),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: AppColors.error),
            onPressed: () => ref.read(contactsProvider.notifier).rejectRequest(request.id),
          ),
        ],
      ),
    );
  }
}
