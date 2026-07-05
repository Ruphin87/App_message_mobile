import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/admin_controller.dart';

/// Panel pour la gestion des signalements
class AdminReportsPanel extends ConsumerWidget {
  const AdminReportsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(reportsProvider).when(
      data: (reports) {
        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.report, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Aucun signalement',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final isResolved = report.status == 'resolved';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isResolved ? Colors.grey[50] : null,
              child: ListTile(
                leading: Icon(
                  isResolved ? Icons.check_circle : Icons.warning,
                  color: isResolved ? Colors.green : Colors.orange,
                ),
                title: Text(
                  'Signalement #${report.id.substring(0, 8)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isResolved
                        ? Colors.grey[500]
                        : Colors.black,
                    decoration: isResolved ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Raison: ${report.reason}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Signalé il y a ${DateTime.now().difference(report.createdAt).inHours}h',
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (isResolved)
                      const Text(
                        'Résolu',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                trailing: isResolved
                    ? IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            ref.read(adminProvider.notifier).deleteReport(report.id),
                      )
                    : PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: const Row(
                              children: [
                                Icon(Icons.check, size: 20),
                                SizedBox(width: 8),
                                Text('Résoudre'),
                              ],
                            ),
                            onTap: () => ref
                                .read(adminProvider.notifier)
                                .resolveReport(report.id),
                          ),
                          PopupMenuItem(
                            child: const Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Supprimer', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                            onTap: () => ref
                                .read(adminProvider.notifier)
                                .deleteReport(report.id),
                          ),
                        ],
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
