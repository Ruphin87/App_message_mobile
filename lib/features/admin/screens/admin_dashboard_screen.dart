import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/admin_service.dart';
import '../controllers/admin_controller.dart';
import '../widgets/admin_stats_card.dart';
import '../widgets/admin_messages_panel.dart';
import '../widgets/admin_users_panel.dart';
import '../widgets/admin_reports_panel.dart';

/// Tableau de bord administratif
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de Bord Admin'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              AdminService.lockAdminSession();
              context.pop();
            },
            tooltip: 'Quitter',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistiques
          SizedBox(
            height: 140,
            child: ref.watch(adminStatsProvider).when(
              data: (stats) {
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16),
                  children: [
                    AdminStatsCard(
                      title: 'Utilisateurs',
                      value: stats.totalUsers.toString(),
                      icon: Icons.people,
                      color: Colors.blue,
                    ),
                    AdminStatsCard(
                      title: 'Messages',
                      value: stats.totalMessages.toString(),
                      icon: Icons.message,
                      color: Colors.green,
                    ),
                    AdminStatsCard(
                      title: 'Bloqués',
                      value: stats.blockedUsers.toString(),
                      icon: Icons.block,
                      color: Colors.orange,
                    ),
                    AdminStatsCard(
                      title: 'Signalements',
                      value: stats.totalReports.toString(),
                      icon: Icons.report,
                      color: Colors.red,
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (err, stack) => Center(
                child: Text('Erreur: $err'),
              ),
            ),
          ),
          // Message de succès/erreur
          if (adminState.successMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      adminState.successMessage!,
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => ref.read(adminProvider.notifier).clearMessages(),
                  ),
                ],
              ),
            ),
          if (adminState.errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      adminState.errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => ref.read(adminProvider.notifier).clearMessages(),
                  ),
                ],
              ),
            ),
          // Tabs
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Messages', icon: Icon(Icons.message)),
              Tab(text: 'Utilisateurs', icon: Icon(Icons.people)),
              Tab(text: 'Signalements', icon: Icon(Icons.report)),
              Tab(text: 'Outils', icon: Icon(Icons.settings)),
            ],
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const AdminMessagesPanel(),
                const AdminUsersPanel(),
                const AdminReportsPanel(),
                _buildToolsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Outil pour supprimer les anciens messages
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.delete, color: Colors.red),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Supprimer les messages anciens',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Supprimez tous les messages datant de plus de 30 jours (fichiers, texte, audio, etc.)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => _showDeleteConfirmation(),
                      child: const Text(
                        'Supprimer les messages > 30 jours',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Outil pour afficher les alertes de messages
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Alertes de messages',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Consultez les messages qui approchent de 30 jours d\'ancienneté',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      onPressed: () => _showExpiringMessages(),
                      child: const Text(
                        'Voir les messages expirant',
                        style: TextStyle(color: Colors.white),
                      ),
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

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer tous les messages datant de plus de 30 jours ? '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              ref.read(adminProvider.notifier).deleteOldMessages(30);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showExpiringMessages() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Consumer(
          builder: (context, ref, child) {
            return FutureBuilder(
              future: ref.watch(messagesAboutToExpireProvider.future),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Erreur: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Fermer'),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Messages expirant bientôt',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${messages.length} message(s) plus anciens que 30 jours',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 300,
                          width: 400,
                          child: ListView.builder(
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              return ListTile(
                                leading: Icon(
                                  _getMessageIcon(msg.attachmentType),
                                  color: Colors.grey[600],
                                ),
                                title: Text(
                                  msg.content ?? 'Message sans contenu',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'Il y a ${DateTime.now().difference(msg.createdAt).inDays} jours',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    ref
                                        .read(adminProvider.notifier)
                                        .deleteMessage(msg.id);
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Fermer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  IconData _getMessageIcon(String? attachmentType) {
    switch (attachmentType) {
      case 'image':
        return Icons.image;
      case 'audio':
        return Icons.audio_file;
      case 'file':
        return Icons.file_present;
      case 'pdf':
        return Icons.picture_as_pdf;
      default:
        return Icons.message;
    }
  }
}
