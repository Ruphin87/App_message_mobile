import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/call_model.dart';
import '../controllers/call_controller.dart';

class IncomingCallListener extends ConsumerStatefulWidget {
  const IncomingCallListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends ConsumerState<IncomingCallListener> {
  String? _shownCallId;

  @override
  Widget build(BuildContext context) {
    ref.listen(incomingCallProvider, (previous, next) {
      final call = next.call;
      final caller = next.caller;
      if (call == null || caller == null || _shownCallId == call.id) return;

      _shownCallId = call.id;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(call.mediaType == CallMediaType.video ? 'Appel vidéo' : 'Appel audio'),
            content: Row(
              children: [
                UserAvatar(
                  userId: caller.id,
                  photoUrl: caller.photo,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    caller.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  await ref.read(incomingCallProvider.notifier).declineCurrentCall();
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  _shownCallId = null;
                },
                icon: const Icon(Icons.call_end, color: AppColors.error),
                label: const Text('Refuser'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(callRepositoryProvider).acceptCall(call.id);
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ref.read(incomingCallProvider.notifier).clear();
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
                  _shownCallId = null;
                },
                icon: const Icon(Icons.call),
                label: const Text('Accepter'),
              ),
            ],
          );
        },
      ).then((_) {
        _shownCallId = null;
      });
    });

    return widget.child;
  }
}
