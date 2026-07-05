import 'package:audioplayers/audioplayers.dart';

/// Gère les sons d'appel, exactement comme sur WhatsApp :
/// - `ringback` : la tonalité "ça sonne" que L'APPELANT entend tant que la
///   personne appelée n'a pas décroché (ou refusé/manqué l'appel).
/// - `incomingRingtone` : la sonnerie que LE DESTINATAIRE entend pendant
///   qu'un appel entrant s'affiche à l'écran, tant qu'il n'a pas répondu ni
///   refusé.
///
/// Un seul lecteur à la fois est utilisé (un appel ne peut pas à la fois
/// sonner ET recevoir un appel), donc une seule instance suffit pour toute
/// l'application.
class CallSoundService {
  CallSoundService._();
  static final CallSoundService instance = CallSoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  Future<void> playRingback() => _playLoop('audio/ringback_tone.wav');

  Future<void> playIncomingRingtone() => _playLoop('audio/incoming_ringtone.wav');

  Future<void> _playLoop(String assetPath) async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(assetPath));
      _isPlaying = true;
    } catch (_) {
      // Le silence ne doit jamais empêcher l'appel de continuer si le
      // lecteur audio échoue pour une raison quelconque (device muet, etc.)
    }
  }

  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    try {
      await _player.stop();
    } catch (_) {
      // Rien à faire si le lecteur est déjà arrêté/disposé.
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
