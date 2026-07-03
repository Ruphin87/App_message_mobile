import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// Service de sécurité pour le chiffrement et la protection des données
class SecurityService {
  SecurityService._();

  // Clé maître pour le chiffrement (dans une vraie app, la stocker sécurisément)
  static final _masterKey = encrypt.Key.fromLength(32);

  // IV pour AES
  static final _iv = encrypt.IV.fromLength(16);

  /// Chiffre un texte
  static String encryptText(String plainText) {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_masterKey));
      final encrypted = encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      throw Exception('Erreur lors du chiffrement: $e');
    }
  }

  /// Déchiffre un texte
  static String decryptText(String encryptedText) {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_masterKey));
      final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e) {
      throw Exception('Erreur lors du déchiffrement: $e');
    }
  }

  /// Hash un mot de passe avec SHA-256 et salt
  static String hashPassword(String password) {
    // Ajouter un salt
    final salt = 'message_ko_secure_salt_2026';
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }

  /// Vérifie si un mot de passe correspond à son hash
  static bool verifyPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }

  /// Génère une clé JWT (simulée, Supabase gère réellement les JWT)
  static String generateJWTToken(String userId) {
    final header = base64Url.encode(
      utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
    );

    final payload = base64Url.encode(
      utf8.encode(jsonEncode({
        'sub': userId,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp': DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
      })),
    );

    final message = '$header.$payload';
    final secret = 'message_ko_jwt_secret_2026';
    final signature = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(message));
    final encodedSignature = base64Url.encode(signature.bytes);

    return '$message.$encodedSignature';
  }

  /// Valide un JWT (simulée, Supabase gère réellement les JWT)
  static bool validateJWTToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      // Vérifier la signature
      final message = '${parts[0]}.${parts[1]}';
      final secret = 'message_ko_jwt_secret_2026';
      final signature = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(message));
      final encodedSignature = base64Url.encode(signature.bytes).replaceAll('=', '');
      final tokenSignature = parts[2].replaceAll('=', '');

      if (signature.toString() != tokenSignature && encodedSignature != tokenSignature) {
        return false;
      }

      // Vérifier l'expiration
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(parts[1] + '=' * (4 - parts[1].length % 4))),
      );
      final exp = payload['exp'] as int;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 < exp;
    } catch (e) {
      return false;
    }
  }

  /// Hache une chaîne (pour les IDs ou tokens)
  static String hash(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }
}
