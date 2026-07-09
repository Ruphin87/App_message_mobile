import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../models/call_model.dart';
import '../../../models/user_model.dart';

class CallRepository {
  CallRepository();

  final SupabaseClient _client = SupabaseService.client;

  String? get _currentUserId => SupabaseService.currentUserId;
  String? get currentUserId => _currentUserId;

  Future<CallModel> createCall({
    required String receiverId,
    required CallMediaType mediaType,
  }) async {
    final callerId = _currentUserId;
    if (callerId == null) throw Exception('Utilisateur non connecté');

    final response = await _client
        .from('calls')
        .insert({
          'caller_id': callerId,
          'receiver_id': receiverId,
          'media_type': mediaType.value,
          'status': CallStatus.ringing.name,
        })
        .select()
        .single();

    return CallModel.fromJson(response);
  }

  Future<CallModel> getCall(String callId) async {
    final response = await _client.from('calls').select().eq('id', callId).single();
    return CallModel.fromJson(response);
  }

  Future<UserModel> getUser(String userId) async {
    final response = await _client.from('users').select().eq('id', userId).single();
    return UserModel.fromJson(response);
  }

  Future<void> acceptCall(String callId) async {
    await _client
        .from('calls')
        .update({
          'status': CallStatus.accepted.name,
          'answered_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', callId);
  }

  Future<void> declineCall(String callId) async {
    await _client
        .from('calls')
        .update({
          'status': CallStatus.declined.name,
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', callId);
  }

  Future<void> endCall(String callId) async {
    await _client
        .from('calls')
        .update({
          'status': CallStatus.ended.name,
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', callId);
  }

  /// Marque un appel comme échoué (réseau, timeout, etc.)
  Future<void> failCall(String callId, String reason) async {
    await _client
        .from('calls')
        .update({
          'status': CallStatus.failed.name,
          'ended_at': DateTime.now().toUtc().toIso8601String(),
          'failure_reason': reason,
        })
        .eq('id', callId);
  }

  /// Marque un appel comme sans réponse (pas d'acceptation)
  Future<void> missedCall(String callId) async {
    await _client
        .from('calls')
        .update({
          'status': CallStatus.missed.name,
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', callId);
  }

  Future<void> sendCallEvent({
    required String callId,
    required String eventType,
    required Map<String, dynamic> payload,
  }) async {
    final senderId = _currentUserId;
    if (senderId == null) throw Exception('Utilisateur non connecté');

    await _client.from('call_events').insert({
      'call_id': callId,
      'sender_id': senderId,
      'event_type': eventType,
      'payload': payload,
    });
  }

  Stream<List<CallModel>> watchIncomingCalls() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return const Stream.empty();

    return _client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', currentUserId)
        .order('created_at')
        .map(
          (rows) => rows
              .map((row) => CallModel.fromJson(row))
              .where((call) => call.status == CallStatus.ringing)
              .toList(),
        );
  }

  Stream<CallModel?> watchCall(String callId) {
    return _client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .map((rows) => rows.isEmpty ? null : CallModel.fromJson(rows.first));
  }

  Stream<List<CallEventModel>> watchCallEvents(String callId) {
    return _client
        .from('call_events')
        .stream(primaryKey: ['id'])
        .eq('call_id', callId)
        .order('created_at')
        .map((rows) => rows.map((row) => CallEventModel.fromJson(row)).toList());
  }

  /// Récupère des identifiants STUN/TURN frais pour un appel, via l'Edge
  /// Function `get-turn-credentials`. La clé API Metered reste toujours
  /// côté serveur — jamais embarquée dans l'app. Retourne `null` en cas
  /// d'échec (réseau, quota Metered dépassé, etc.) : l'appelant doit alors
  /// se rabattre sur une configuration ICE de secours.
  Future<List<Map<String, dynamic>>?> getTurnCredentials() async {
    try {
      final response = await _client.functions.invoke('get-turn-credentials');
      final data = response.data;
      if (data is Map && data['ok'] == true && data['iceServers'] is List) {
        return (data['iceServers'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {
      // Best-effort — l'appelant utilise sa configuration de secours.
    }
    return null;
  }
}