import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Résultat d'une vérification de mise à jour.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    this.releaseNotes,
    this.publishedAt,
  });

  final String currentVersion;
  final String latestVersion;
  final bool updateAvailable;
  final String? releaseNotes;
  final DateTime? publishedAt;
}

/// Vérifie si une nouvelle version de l'application est disponible, en
/// interrogeant la même source que le site web de téléchargement
/// (apk-download-site/script.js) : la dernière "release" GitHub du dépôt.
///
/// L'app ne télécharge JAMAIS l'APK elle-même : quand une mise à jour est
/// disponible, l'utilisateur est simplement redirigé vers le site web, où
/// il peut télécharger la nouvelle version — exactement comme demandé
/// (l'app affiche juste le statut + un bouton qui ouvre le site).
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  // ⚠️ À CHANGER si le dépôt GitHub change — doit rester identique aux
  // constantes GITHUB_USERNAME / GITHUB_REPO du fichier script.js du site
  // de téléchargement (apk-download-site), qui interroge la même API.
  static const String _githubUser = 'Ruphin87';
  static const String _githubRepo = 'App_message_mobile';
  static const String _apiLatestRelease =
      'https://api.github.com/repos/$_githubUser/$_githubRepo/releases/latest';

  /// ⚠️ À CHANGER avec l'URL réelle une fois le site (apk-download-site)
  /// déployé (ex: sur Vercel) — c'est vers cette page que le bouton "Voir
  /// la mise à jour" redirige l'utilisateur pour télécharger l'APK.
  static const String downloadWebsiteUrl = 'https://updateapk.vercel.app';

  /// Interroge l'API GitHub et compare la dernière version publiée à la
  /// version actuellement installée (lue via `package_info_plus`, donc
  /// toujours exacte, y compris sur un appareil qui n'a pas encore la
  /// toute dernière build).
  Future<AppUpdateInfo> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      final response = await http
          .get(Uri.parse(_apiLatestRelease), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Réponse GitHub inattendue (${response.statusCode})');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rawTag = (json['tag_name'] as String? ?? '').trim();
      final latestVersion = rawTag.startsWith('v') ? rawTag.substring(1) : rawTag;

      final publishedAtRaw = json['published_at'] as String?;

      return AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion.isEmpty ? currentVersion : latestVersion,
        updateAvailable: latestVersion.isNotEmpty && _isNewer(latestVersion, currentVersion),
        releaseNotes: json['body'] as String?,
        publishedAt: publishedAtRaw != null ? DateTime.tryParse(publishedAtRaw)?.toLocal() : null,
      );
    } catch (_) {
      // Pas de connexion, dépôt non configuré, etc. — l'app doit rester
      // utilisable normalement, on remonte juste "pas de mise à jour
      // détectée" plutôt que de planter l'écran Paramètres.
      throw UpdateCheckException(currentVersion);
    }
  }

  /// Compare deux numéros de version "X.Y.Z" (les parties manquantes ou
  /// non numériques comptent comme 0). Renvoie `true` si [remote] est
  /// strictement plus récent que [local].
  bool _isNewer(String remote, String local) {
    List<int> parse(String v) => v
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();

    final r = parse(remote);
    final l = parse(local);
    final length = r.length > l.length ? r.length : l.length;

    for (var i = 0; i < length; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv > lv;
    }
    return false;
  }

  /// Ouvre le site de téléchargement dans le navigateur — c'est là que
  /// l'utilisateur télécharge réellement la mise à jour.
  ///
  /// On tente `launchUrl` directement plutôt que de se fier à
  /// `canLaunchUrl` : sur beaucoup d'appareils Android, `canLaunchUrl`
  /// renvoie `false` par excès de prudence (restrictions de visibilité des
  /// paquets) alors que `launchUrl` fonctionne très bien — s'appuyer sur
  /// `canLaunchUrl` est justement ce qui empêchait le bouton de faire quoi
  /// que ce soit. On indique le succès/échec à l'appelant pour pouvoir
  /// prévenir l'utilisateur si l'ouverture échoue vraiment (aucun
  /// navigateur disponible, URL invalide, etc.).
  Future<bool> openDownloadWebsite() async {
    final uri = Uri.parse(downloadWebsiteUrl);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

/// Erreur levée quand la vérification en ligne échoue (pas de réseau, API
/// GitHub indisponible, dépôt non configuré...), tout en gardant la
/// version locale connue pour l'affichage.
class UpdateCheckException implements Exception {
  UpdateCheckException(this.currentVersion);
  final String currentVersion;
}
