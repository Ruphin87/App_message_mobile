import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Résultat d'un téléchargement de pièce jointe.
class DownloadResult {
  const DownloadResult({required this.success, this.filePath, this.error});

  final bool success;
  final String? filePath;
  final String? error;
}

/// Permet de télécharger une pièce jointe (image, audio, document...) reçue
/// dans une conversation, pour la garder sur l'appareil — comme le bouton
/// "Télécharger" de WhatsApp sur une photo ou un message vocal.
///
/// Les fichiers sont enregistrés dans un dossier "Download" propre à
/// l'application (accessible via un gestionnaire de fichiers dans
/// Android/data/<app>/files/Download), ce qui ne nécessite aucune
/// permission de stockage supplémentaire sur les versions récentes
/// d'Android (stockage "scoped" par défaut depuis Android 10+).
class DownloadService {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  Future<DownloadResult> downloadAttachment({
    required String url,
    required String suggestedFileName,
  }) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        return DownloadResult(success: false, error: 'Erreur serveur (${response.statusCode})');
      }

      final downloadsDir = await _resolveDownloadsDirectory();
      final fileName = _uniqueFileName(downloadsDir, suggestedFileName);
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes, flush: true);

      return DownloadResult(success: true, filePath: file.path);
    } catch (e) {
      return const DownloadResult(success: false, error: 'Téléchargement impossible. Vérifiez votre connexion.');
    }
  }

  Future<Directory> _resolveDownloadsDirectory() async {
    Directory base;
    if (Platform.isAndroid) {
      base = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    } else {
      base = await getApplicationDocumentsDirectory();
    }
    final downloads = Directory('${base.path}/Download');
    if (!await downloads.exists()) {
      await downloads.create(recursive: true);
    }
    return downloads;
  }

  /// Évite d'écraser un fichier existant du même nom en ajoutant un
  /// suffixe numérique, comme le fait un navigateur classique.
  String _uniqueFileName(Directory dir, String suggestedFileName) {
    final safeName = suggestedFileName.trim().isEmpty ? 'fichier' : suggestedFileName.trim();
    final dotIndex = safeName.lastIndexOf('.');
    final base = dotIndex > 0 ? safeName.substring(0, dotIndex) : safeName;
    final ext = dotIndex > 0 ? safeName.substring(dotIndex) : '';

    var candidate = safeName;
    var counter = 1;
    while (File('${dir.path}/$candidate').existsSync()) {
      candidate = '$base ($counter)$ext';
      counter++;
    }
    return candidate;
  }
}
