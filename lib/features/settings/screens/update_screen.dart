import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/update_service.dart';
import '../controllers/settings_controller.dart';

/// Écran "Mise à jour" des Paramètres.
///
/// Affiche le statut de mise à jour (à jour / mise à jour disponible /
/// erreur réseau) obtenu depuis le site web (apk-download-site), via
/// l'API GitHub Releases. Si une mise à jour est disponible, un bouton
/// redirige l'utilisateur vers le site pour qu'il télécharge lui-même le
/// nouvel APK — l'application ne télécharge ni n'installe jamais rien
/// elle-même.
class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key});

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen> {
  @override
  void initState() {
    super.initState();
    // Vérifie automatiquement dès l'ouverture de l'écran, comme on
    // s'y attend pour un écran "Mise à jour".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(updateCheckProvider.notifier).check();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateCheckProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mise à jour',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(updateCheckProvider.notifier).check(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(context, state),
            const SizedBox(height: 20),
            if (!state.isChecking)
              OutlinedButton.icon(
                onPressed: () => ref.read(updateCheckProvider.notifier).check(),
                icon: const Icon(Icons.refresh),
                label: const Text('Vérifier maintenant'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWebsite(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref.read(updateCheckProvider.notifier).openDownloadWebsite();
    if (!mounted) return;

    if (!opened) {
      // Aucune application n'a pu ouvrir le lien (rare, mais possible sur
      // certains appareils) : on prévient l'utilisateur et on lui propose
      // de copier l'adresse pour l'ouvrir lui-même dans son navigateur,
      // plutôt que de le laisser croire que le bouton ne fait rien.
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Impossible d\'ouvrir le site automatiquement.'),
          action: SnackBarAction(
            label: 'Copier le lien',
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: UpdateService.downloadWebsiteUrl));
              messenger.showSnackBar(
                const SnackBar(content: Text('Lien copié dans le presse-papiers.')),
              );
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Widget _buildStatusCard(BuildContext context, UpdateCheckState state) {
    if (state.isChecking && !state.hasCheckedOnce) {
      return _buildCard(
        icon: Icons.system_update_outlined,
        iconColor: AppColors.primary,
        iconBackground: AppColors.primary.withValues(alpha: 0.1),
        title: 'Vérification en cours...',
        subtitle: 'Recherche de mises à jour disponibles.',
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (state.error != null) {
      return _buildCard(
        icon: Icons.wifi_off_outlined,
        iconColor: AppColors.error,
        iconBackground: AppColors.errorLight,
        title: 'Vérification impossible',
        subtitle: state.error!,
      );
    }

    final info = state.info;
    if (info == null) {
      return _buildCard(
        icon: Icons.system_update_outlined,
        iconColor: AppColors.textSecondary,
        iconBackground: AppColors.surfaceDark,
        title: 'Statut inconnu',
        subtitle: 'Lancez une vérification pour voir si une mise à jour est disponible.',
      );
    }

    if (info.updateAvailable) {
      return Column(
        children: [
          _buildCard(
            icon: Icons.new_releases_outlined,
            iconColor: AppColors.warning,
            iconBackground: AppColors.warningLight,
            title: 'Mise à jour disponible',
            subtitle: 'Version ${info.latestVersion} (actuelle : ${info.currentVersion})',
          ),
          if (info.releaseNotes != null && info.releaseNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildReleaseNotesCard(info.releaseNotes!),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openWebsite(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Télécharger la mise à jour'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vous serez redirigé vers le site web de l\'application pour télécharger le fichier.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textHint, fontSize: 12),
          ),
        ],
      );
    }

    return _buildCard(
      icon: Icons.check_circle_outline,
      iconColor: AppColors.success,
      iconBackground: AppColors.successLight,
      title: 'Vous utilisez la dernière version',
      subtitle: 'Version actuelle : ${info.currentVersion}',
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _buildReleaseNotesCard(String notes) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NOUVEAUTÉS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(notes, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
