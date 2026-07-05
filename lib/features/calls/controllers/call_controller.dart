import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/call_sound_service.dart';
import '../../../models/call_model.dart';
import '../../../models/user_model.dart';
import '../repositories/call_repository.dart';

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository();
});

class IncomingCallState {
  const IncomingCallState({
    this.call,
    this.caller,
    this.isLoading = false,
    this.error,
  });

  final CallModel? call;
  final UserModel? caller;
  final bool isLoading;
  final String? error;

  IncomingCallState copyWith({
    CallModel? call,
    UserModel? caller,
    bool clearCall = false,
    bool? isLoading,
    String? error,
  }) {
    return IncomingCallState(
      call: clearCall ? null : (call ?? this.call),
      caller: clearCall ? null : (caller ?? this.caller),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class IncomingCallNotifier extends StateNotifier<IncomingCallState> {
  IncomingCallNotifier(this._repository) : super(const IncomingCallState()) {
    _subscription = _repository.watchIncomingCalls().listen(_handleIncomingCalls);
  }

  final CallRepository _repository;
  StreamSubscription<List<CallModel>>? _subscription;

  Future<void> _handleIncomingCalls(List<CallModel> calls) async {
    if (calls.isEmpty) {
      // Plus aucun appel entrant en attente (refusé, décroché ailleurs,
      // annulé par l'appelant, ou expiré) : on coupe la sonnerie et on
      // referme l'écran d'appel entrant s'il était affiché.
      await CallSoundService.instance.stop();
      state = state.copyWith(clearCall: true, isLoading: false);
      return;
    }

    final latest = calls.last;
    if (state.call?.id == latest.id && state.caller != null) return;

    state = state.copyWith(call: latest, isLoading: true, error: null);
    // La sonnerie démarre dès qu'on sait qu'un appel entrant existe, sans
    // attendre le chargement du profil de l'appelant — exactement comme un
    // téléphone classique qui sonne immédiatement à réception de l'appel.
    unawaited(CallSoundService.instance.playIncomingRingtone());
    try {
      final caller = await _repository.getUser(latest.callerId);
      if (!mounted) return;
      state = state.copyWith(call: latest, caller: caller, isLoading: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: 'Appel entrant indisponible');
    }
  }

  Future<void> acceptCurrentCall() async {
    final call = state.call;
    if (call == null) return;
    await CallSoundService.instance.stop();
    await _repository.acceptCall(call.id);
  }

  Future<void> declineCurrentCall() async {
    final call = state.call;
    if (call == null) return;

    await CallSoundService.instance.stop();
    await _repository.declineCall(call.id);
    if (!mounted) return;
    state = state.copyWith(clearCall: true);
  }

  void clear() {
    CallSoundService.instance.stop();
    state = state.copyWith(clearCall: true);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    CallSoundService.instance.stop();
    super.dispose();
  }
}

final incomingCallProvider =
    StateNotifierProvider<IncomingCallNotifier, IncomingCallState>((ref) {
  return IncomingCallNotifier(ref.watch(callRepositoryProvider));
});
