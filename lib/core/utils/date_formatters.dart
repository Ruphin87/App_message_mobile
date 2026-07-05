/// Formatage de dates/heures en français, façon WhatsApp.
/// N'utilise pas DateFormat avec locale pour éviter toute dépendance à
/// `initializeDateFormatting()` (qui doit être appelée avant le premier
/// `runApp` sinon elle lève une exception) — un simple mapping manuel
/// est plus robuste pour ce besoin précis.
class DateFormatters {
  DateFormatters._();

  static const _jours = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  static const _mois = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// Heure au format HH:mm (24h), en heure locale (le DateTime passé doit
  /// déjà avoir été converti en .toLocal() au niveau du modèle).
  static String time(DateTime dateTime) {
    return '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
  }

  static String _weekday(DateTime dateTime) => _jours[dateTime.weekday - 1];

  static String _fullDate(DateTime dateTime) {
    return '${dateTime.day} ${_mois[dateTime.month - 1]} ${dateTime.year}';
  }

  /// Libellé pour l'en-tête de groupe de messages ("Aujourd'hui", "Hier",
  /// ou la date complète), comme les séparateurs de date dans WhatsApp.
  static String dateSeparator(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(date).inDays;

    if (difference == 0) return 'Aujourd\'hui';
    if (difference == 1) return 'Hier';
    if (difference < 7 && difference > 0) return _weekday(dateTime);
    return _fullDate(dateTime);
  }

  /// Libellé compact pour la liste des conversations (heure si aujourd'hui,
  /// "Hier" si hier, jour de semaine si cette semaine, date sinon).
  static String conversationPreviewTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(date).inDays;

    if (difference == 0) return time(dateTime);
    if (difference == 1) return 'Hier';
    if (difference < 7 && difference > 0) return _weekday(dateTime);
    return '${_twoDigits(dateTime.day)}/${_twoDigits(dateTime.month)}/${dateTime.year}';
  }

  /// true si [a] et [b] ne sont pas le même jour calendaire.
  static bool isDifferentDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }
}
