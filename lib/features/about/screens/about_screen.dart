import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _developers = [
    'RATAHINJANAHARY Ruphin Henri',
    'RANOMENJANAHARY Henri Parfait',
  ];

  static const _phones = [
    '+261 38 05 876 87',
    '+261 38 90 252 94',
  ];

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'À propos',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAppHeader(),
          const SizedBox(height: 24),
          _buildSectionTitle('Développeurs', Icons.code),
          const SizedBox(height: 12),
          _buildDevelopersCard(),
          const SizedBox(height: 24),
          _buildSectionTitle('Contact', Icons.phone_outlined),
          const SizedBox(height: 12),
          _buildContactCard(),
          const SizedBox(height: 24),
          _buildSectionTitle('Établissement', Icons.school_outlined),
          const SizedBox(height: 12),
          _buildSchoolCard(),
          const SizedBox(height: 32),
          _buildFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAppHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.chat_bubble_rounded, color: AppColors.primary, size: 44),
          ),
          const SizedBox(height: 16),
          const Text(
            'Message_KO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Application de messagerie',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDevelopersCard() {
    return Container(
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
        children: [
          for (var i = 0; i < _developers.length; i++) ...[
            ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  _initials(_developers[i]),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                _developers[i],
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Développeur',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            if (i < _developers.length - 1)
              const Divider(height: 1, indent: 72, color: AppColors.divider),
          ],
        ],
      ),
    );
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Widget _buildContactCard() {
    return Container(
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
        children: [
          for (var i = 0; i < _phones.length; i++) ...[
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone, color: AppColors.success, size: 20),
              ),
              title: Text(
                _phones[i],
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.call_outlined, color: AppColors.primary),
                onPressed: () => _callPhone(_phones[i]),
              ),
              onTap: () => _callPhone(_phones[i]),
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: _phones[i]));
              },
            ),
            if (i < _phones.length - 1)
              const Divider(height: 1, indent: 72, color: AppColors.divider),
          ],
        ],
      ),
    );
  }

  Widget _buildSchoolCard() {
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
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo_eni.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.school,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'École Nationale d\'Informatique',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'ENI — Fianarantsoa, Madagascar',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Text(
            '© ${DateTime.now().year} Message_KO',
            style: const TextStyle(color: AppColors.textHint, fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tous droits réservés',
            style: TextStyle(color: AppColors.textHint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
