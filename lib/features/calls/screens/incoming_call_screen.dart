import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/call_model.dart';
import '../../../models/user_model.dart';
import '../controllers/call_controller.dart';

/// Écran plein écran d'appel entrant, façon WhatsApp : photo et nom de
/// l'appelant en grand, type d'appel (audio/vidéo), et deux gros boutons
/// "Refuser" / "Répondre". Reste affiché tant que l'appel est en attente ;
/// se ferme tout seul si l'appelant raccroche avant que l'on ait répondu.
class IncomingCallScreen extends ConsumerWidget {
  const IncomingCallScreen({
    super.key,
    required this.call,
    required this.caller,
  });

  final CallModel call;
  final UserModel caller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Si l'appel disparaît (annulé par l'appelant, expiré, décroché sur un
    // autre appareil...), on referme automatiquement cet écran.
    ref.listen(incomingCallProvider, (previous, next) {
      if (next.call?.id != call.id) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      }
    });

    final isVideo = call.mediaType == CallMediaType.video;

    return PopScope(
      // On empêche le simple retour arrière : il faut explicitement
      // répondre ou refuser, comme un vrai écran d'appel entrant.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isVideo ? 'Appel vidéo entrant' : 'Appel audio entrant',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const Spacer(flex: 2),
              UserAvatar(
                userId: caller.id,
                photoUrl: caller.photo,
                radius: 70,
              ),
              const SizedBox(height: 24),
              Text(
                caller.nom,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'vous appelle...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 15),
              ),
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CallActionButton(
                      icon: Icons.call_end,
                      label: 'Refuser',
                      color: AppColors.error,
                      onPressed: () => _decline(context, ref),
                    ),
                    _CallActionButton(
                      icon: Icons.call,
                      label: 'Répondre',
                      color: AppColors.success,
                      onPressed: () => _accept(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    await ref.read(incomingCallProvider.notifier).declineCurrentCall();
    if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    await ref.read(incomingCallProvider.notifier).acceptCurrentCall();
    ref.read(incomingCallProvider.notifier).clear();
    if (!context.mounted) return;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    context.push(
      '${AppRoutes.call}/${call.id}',
      extra: CallRouteArgs(
        otherUserId: caller.id,
        otherUserName: caller.nom,
        otherUserPhoto: caller.photo,
        mediaType: call.mediaType,
        isCaller: false,
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 68,
          height: 68,
          child: IconButton(
            onPressed: onPressed,
            style: IconButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            icon: Icon(icon, size: 30),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}
