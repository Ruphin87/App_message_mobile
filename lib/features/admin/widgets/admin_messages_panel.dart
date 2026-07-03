import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/admin_controller.dart';

/// Panel pour la gestion des messages
class AdminMessagesPanel extends ConsumerStatefulWidget {
  const AdminMessagesPanel({super.key});

  @override
  ConsumerState<AdminMessagesPanel> createState() => _AdminMessagesPanelState();
}

class _AdminMessagesPanelState extends ConsumerState<AdminMessagesPanel> {
  int _selectedDays = 1;
  bool _expandedFilters = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtres
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtres',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: Icon(
                      _expandedFilters ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: () =>
                        setState(() => _expandedFilters = !_expandedFilters),
                  ),
                ],
              ),
              if (_expandedFilters) ...[
                const SizedBox(height: 12),
                const Text(
                  'Messages plus anciens que:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip(1, '1 jour'),
                    _buildFilterChip(7, '1 semaine'),
                    _buildFilterChip(30, '1 mois'),
                    _buildFilterChip(90, '3 mois'),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Liste des messages
        Expanded(
          child: ref.watch(oldMessagesProvider(_selectedDays)).when(
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun message trouvé',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final daysOld =
                      DateTime.now().difference(msg.createdAt).inDays;

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
                      'Il y a $daysOld jours - ${msg.attachmentType ?? 'Texte'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          ref.read(adminProvider.notifier).deleteMessage(msg.id),
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
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(int days, String label) {
    return FilterChip(
      label: Text(label),
      selected: _selectedDays == days,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedDays = days);
        }
      },
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
