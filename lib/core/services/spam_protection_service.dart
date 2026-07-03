import 'package:shared_preferences/shared_preferences.dart';

/// Service de protection contre le spam
class SpamProtectionService {
  SpamProtectionService._();

  // Nombre maximum de messages par minute
  static const int _maxMessagesPerMinute = 10;

  // Nombre maximum d'appels par minute
  static const int _maxCallsPerMinute = 5;

  // Temps de blocage en minutes après dépassement du quota
  static const int _blockTimeMinutes = 15;

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Vérifie si l'utilisateur n'est pas en train de spammer les messages
  static Future<bool> canSendMessage(String userId) async {
    return _checkRateLimit(userId, 'messages', _maxMessagesPerMinute);
  }

  /// Vérifie si l'utilisateur n'est pas en train de spammer les appels
  static Future<bool> canMakeCall(String userId) async {
    return _checkRateLimit(userId, 'calls', _maxCallsPerMinute);
  }

  /// Enregistre un envoi de message
  static Future<void> recordMessageSent(String userId) async {
    await _recordAction(userId, 'messages');
  }

  /// Enregistre un appel
  static Future<void> recordCallMade(String userId) async {
    await _recordAction(userId, 'calls');
  }

  /// Vérifie le rate limit
  static Future<bool> _checkRateLimit(String userId, String actionType, int maxActions) async {
    final key = 'spam_${actionType}_$userId';
    final blockedKey = 'spam_blocked_${actionType}_$userId';
    final blockTimeKey = 'spam_block_time_${actionType}_$userId';

    // Vérifier si l'utilisateur est bloqué
    final isBlocked = _prefs.getBool(blockedKey) ?? false;
    if (isBlocked) {
      final blockTime = _prefs.getInt(blockTimeKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final blockDurationMs = _blockTimeMinutes * 60 * 1000;

      if (now - blockTime < blockDurationMs) {
        return false;
      } else {
        // Le temps de blocage est écoulé, débloquer
        await _prefs.remove(blockedKey);
        await _prefs.remove(blockTimeKey);
      }
    }

    // Récupérer les actions enregistrées
    final dataStr = _prefs.getString(key) ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;

    List<int> timestamps = [];
    if (dataStr.isNotEmpty) {
      timestamps = dataStr.split(',').map(int.parse).toList();
    }

    // Supprimer les timestamps plus vieux que 1 minute
    timestamps.removeWhere((timestamp) => now - timestamp > 60000);

    // Vérifier si la limite est atteinte
    if (timestamps.length >= maxActions) {
      // Bloquer l'utilisateur
      await _prefs.setBool(blockedKey, true);
      await _prefs.setInt(blockTimeKey, now);
      return false;
    }

    return true;
  }

  /// Enregistre une action
  static Future<void> _recordAction(String userId, String actionType) async {
    final key = 'spam_${actionType}_$userId';
    final dataStr = _prefs.getString(key) ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;

    List<int> timestamps = [];
    if (dataStr.isNotEmpty) {
      timestamps = dataStr.split(',').map(int.parse).toList();
    }

    // Ajouter le nouveau timestamp
    timestamps.add(now);

    // Supprimer les timestamps plus vieux que 1 minute
    timestamps.removeWhere((timestamp) => now - timestamp > 60000);

    // Sauvegarder
    await _prefs.setString(key, timestamps.join(','));
  }

  /// Obtient le nombre d'actions enregistrées
  static int getActionCount(String userId, String actionType) {
    final key = 'spam_${actionType}_$userId';
    final dataStr = _prefs.getString(key) ?? '';
    if (dataStr.isEmpty) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final timestamps = dataStr.split(',').map(int.parse).toList();
    timestamps.removeWhere((timestamp) => now - timestamp > 60000);

    return timestamps.length;
  }

  /// Obtient le temps avant déblocage
  static int? getBlockTimeRemaining(String userId, String actionType) {
    final blockedKey = 'spam_blocked_${actionType}_$userId';
    final blockTimeKey = 'spam_block_time_${actionType}_$userId';

    final isBlocked = _prefs.getBool(blockedKey) ?? false;
    if (!isBlocked) return null;

    final blockTime = _prefs.getInt(blockTimeKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final blockDurationMs = _blockTimeMinutes * 60 * 1000;
    final remaining = blockDurationMs - (now - blockTime);

    return remaining > 0 ? (remaining ~/ 1000) : 0;
  }

  /// Nettoie les données de spam pour un utilisateur
  static Future<void> clearUserSpamData(String userId) async {
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.contains(userId) && key.startsWith('spam_')) {
        await _prefs.remove(key);
      }
    }
  }
}
