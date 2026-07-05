import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../../features/presence/controllers/presence_controller.dart';

/// Avatar circulaire avec mise en cache de l'image (chargement instantané
/// après la première fois, contrairement à NetworkImage qui retélécharge),
/// et badge optionnel indiquant si l'utilisateur est en ligne.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.userId,
    this.photoUrl,
    this.radius = 24,
    this.showOnlineBadge = false,
  });

  final String userId;
  final String? photoUrl;
  final double radius;
  final bool showOnlineBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = showOnlineBadge ? ref.watch(isUserOnlineProvider(userId)) : false;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: photoUrl != null && photoUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photoUrl!,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 150),
                    placeholder: (context, url) => Container(
                      color: AppColors.surfaceDark,
                      child: Icon(Icons.person, color: AppColors.textSecondary, size: radius),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.surfaceDark,
                      child: Icon(Icons.person, color: AppColors.textSecondary, size: radius),
                    ),
                  )
                : Container(
                    color: AppColors.surfaceDark,
                    child: Icon(Icons.person, color: AppColors.textSecondary, size: radius),
                  ),
          ),
        ),
        if (showOnlineBadge && isOnline)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: radius * 0.45,
              height: radius * 0.45,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
