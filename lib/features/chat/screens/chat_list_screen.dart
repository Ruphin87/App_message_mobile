import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../models/conversation_model.dart';
import '../controllers/chat_controller.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatListState = ref.watch(chatListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textPrimary),
            onPressed: () => context.push(AppRoutes.searchUser),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(chatListProvider.notifier).loadConversations(),
        child: _buildBody(context, ref, chatListState),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ChatListState state) {
    if (state.isLoading && state.conversations.isEmpty) {
      return const LoadingWidget(message: 'Chargement des conversations...');
    }

    if (state.conversations.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Aucune conversation pour le moment',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.push(AppRoutes.contacts),
              child: const Text('Voir mes contacts'),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.conversations.length,
      itemBuilder: (context, index) {
        final conversation = state.conversations[index];
        return _buildConversationTile(context, conversation);
      },
    );
  }

  Widget _buildConversationTile(BuildContext context, ConversationModel conversation) {
    final other = conversation.otherUser;
    final hasUnread = conversation.unreadCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
        leading: other != null
            ? UserAvatar(
                userId: other.id,
                photoUrl: other.photo,
                radius: 24,
                showOnlineBadge: true,
              )
            : const CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.surfaceDark,
                child: Icon(Icons.person, color: AppColors.textSecondary),
              ),
        title: Text(
          other?.nom ?? 'Utilisateur',
          style: TextStyle(
            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          conversation.lastMessage ?? 'Démarrer la conversation',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormatters.conversationPreviewTime(conversation.lastMessageAt),
              style: TextStyle(
                fontSize: 12,
                color: hasUnread ? AppColors.primary : AppColors.textHint,
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          if (other != null) {
            context.push('${AppRoutes.chat}/${other.id}', extra: other);
          }
        },
      ),
    );
  }
}
