import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/user_model.dart';
import '../controllers/contacts_controller.dart';

class SearchUserScreen extends ConsumerStatefulWidget {
  const SearchUserScreen({super.key});

  @override
  ConsumerState<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends ConsumerState<SearchUserScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleAddFriend(UserModel user) async {
    final success =
        await ref.read(contactsProvider.notifier).sendFriendRequest(user.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Demande envoyée à ${user.nom}'
              : 'Erreur lors de l\'envoi de la demande',
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Rechercher',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) {
                ref.read(searchProvider.notifier).search(value);
              },
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou email...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchProvider.notifier).clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody(searchState)),
        ],
      ),
    );
  }

  Widget _buildBody(SearchState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Text(state.error!, style: const TextStyle(color: AppColors.error)),
      );
    }

    if (state.query.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search,
        message: 'Recherchez un utilisateur\npar son nom ou son email',
      );
    }

    if (state.results.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_off_outlined,
        message: 'Aucun utilisateur trouvé',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final user = state.results[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(UserModel user) {
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
        leading: UserAvatar(
          userId: user.id,
          photoUrl: user.photo,
          radius: 24,
          showOnlineBadge: true,
        ),
        title: Text(
          user.nom,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        subtitle: Text(user.email, style: const TextStyle(color: AppColors.textSecondary)),
        trailing: IconButton(
          icon: const Icon(Icons.person_add_outlined, color: AppColors.primary),
          onPressed: () => _handleAddFriend(user),
        ),
      ),
    );
  }
}
