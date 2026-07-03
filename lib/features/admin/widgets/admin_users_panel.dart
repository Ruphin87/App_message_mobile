import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/admin_controller.dart';

/// Panel pour la gestion des utilisateurs
class AdminUsersPanel extends ConsumerWidget {
  const AdminUsersPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(blockedUsersProvider).when(
      data: (blockedUsers) {
        if (blockedUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Aucun utilisateur bloqué',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: blockedUsers.length,
          itemBuilder: (context, index) {
            final user = blockedUsers[index];
            final createdDaysAgo =
                DateTime.now().difference(user.createdAt).inDays;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?'),
                ),
                title: Text(user.nom),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.email),
                    Text(
                      'Bloqué depuis $createdDaysAgo jours',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () =>
                      ref.read(adminProvider.notifier).unblockUser(user.id),
                  child: const Text(
                    'Débloquer',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (err, stack) => Center(
        child: Text('Erreur: $err'),
      ),
    );
  }
}
