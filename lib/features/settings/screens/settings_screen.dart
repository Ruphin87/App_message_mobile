import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go(AppRoutes.login);
    }
  }

  Future<void> _showThemePicker(BuildContext context, WidgetRef ref) async {
    final current = ref.read(themeModeProvider);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Thème de l\'application',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              _buildThemeOption(
                sheetContext,
                ref,
                mode: ThemeMode.light,
                icon: Icons.light_mode_outlined,
                label: 'Clair',
                current: current,
              ),
              _buildThemeOption(
                sheetContext,
                ref,
                mode: ThemeMode.dark,
                icon: Icons.dark_mode_outlined,
                label: 'Sombre',
                current: current,
              ),
              _buildThemeOption(
                sheetContext,
                ref,
                mode: ThemeMode.system,
                icon: Icons.brightness_auto_outlined,
                label: 'Système (automatique)',
                current: current,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref, {
    required ThemeMode mode,
    required IconData icon,
    required String label,
    required ThemeMode current,
  }) {
    final isSelected = mode == current;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppColors.primary : null,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _showLanguagePicker(BuildContext context, WidgetRef ref) async {
    final current = ref.read(languageSettingsProvider);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Langue de l\'application',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const Text('🇫🇷', style: TextStyle(fontSize: 20)),
                title: const Text('Français'),
                trailing: current == 'fr' ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  ref.read(languageSettingsProvider.notifier).setLanguage('fr');
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Text('🇬🇧', style: TextStyle(fontSize: 20)),
                title: const Text('English'),
                subtitle: const Text(
                  'Bientôt disponible',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
                trailing: current == 'en' ? const Icon(Icons.check, color: AppColors.primary) : null,
                enabled: false,
                onTap: null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notificationSettings = ref.watch(notificationSettingsProvider);
    final language = ref.watch(languageSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Paramètres',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _sectionLabel('Apparence'),
          _settingsCard([
            _SettingsTile(
              icon: Icons.palette_outlined,
              title: 'Thème',
              subtitle: _themeModeLabel(themeMode),
              onTap: () => _showThemePicker(context, ref),
            ),
          ]),
          const SizedBox(height: 20),
          _sectionLabel('Notifications'),
          _settingsCard([
            _SettingsSwitchTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Recevoir des notifications de nouveaux messages',
              value: notificationSettings.enabled,
              onChanged: (value) =>
                  ref.read(notificationSettingsProvider.notifier).setEnabled(value),
            ),
          ]),
          const SizedBox(height: 20),
          _sectionLabel('Préférences'),
          _settingsCard([
            _SettingsTile(
              icon: Icons.language_outlined,
              title: 'Langue',
              subtitle: language == 'fr' ? 'Français' : 'English',
              onTap: () => _showLanguagePicker(context, ref),
            ),
          ]),
          const SizedBox(height: 20),
          _sectionLabel('Informations'),
          _settingsCard([
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'À propos de l\'application',
              subtitle: 'Développeurs, contact, version',
              onTap: () => context.push(AppRoutes.about),
            ),
          ]),
          const SizedBox(height: 20),
          _sectionLabel('Administration'),
          _settingsCard([
            _SettingsTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Tableau de bord Admin',
              subtitle: 'Statistiques, utilisateurs bloqués, signalements',
              onTap: () => context.push(AppRoutes.admin),
            ),
          ]),
          const SizedBox(height: 32),
          _settingsCard([
            _SettingsTile(
              icon: Icons.logout,
              title: 'Déconnexion',
              titleColor: AppColors.error,
              iconColor: AppColors.error,
              onTap: () => _handleLogout(context, ref),
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Clair';
      case ThemeMode.dark:
        return 'Sombre';
      case ThemeMode.system:
        return 'Système (automatique)';
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, indent: 56, color: AppColors.divider),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.titleColor,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500, color: titleColor),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      activeColor: AppColors.primary,
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))
          : null,
      value: value,
      onChanged: onChanged,
    );
  }
}
