import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/call_controller.dart';
import '../screens/incoming_call_screen.dart';

/// Écoute les appels entrants pour l'utilisateur connecté et affiche, dès
/// qu'un appel arrive, un écran plein écran façon WhatsApp (photo, nom,
/// boutons Répondre/Refuser) — visible depuis n'importe quel écran de
/// l'app puisque ce widget englobe toute la coquille de navigation.
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
      Navigator.of(context, rootNavigator: true)
          .push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => IncomingCallScreen(call: call, caller: caller),
            ),
          )
          .then((_) => _shownCallId = null);
    });

    return widget.child;
  }
}
