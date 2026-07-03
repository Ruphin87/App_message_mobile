import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

/// Canal de notification Android utilisé par défaut pour les messages —
/// le nom DOIT correspondre exactement à `channel_id` envoyé par l'Edge
/// Function (`high_importance_channel`), sinon Android refuse d'afficher
/// la notification système quand l'app est en arrière-plan/fermée.
const _highImportanceChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Messages importants',
  description: 'Notifications de nouveaux messages reçus',
  importance: Importance.max,
);

/// Handler de message en arrière-plan. DOIT être une fonction top-level
/// (pas une méthode de classe) avec l'annotation @pragma('vm:entry-point'),
/// car FCM l'invoque depuis un isolate séparé, indépendant de l'UI — c'est
/// une exigence technique de firebase_messaging, pas une option de style.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Rien à faire ici : quand l'app est en arrière-plan ou fermée, Android
  // affiche déjà automatiquement la notification système à partir du
  // payload "notification" envoyé par l'Edge Function. Ce handler n'a
  // besoin d'exister que pour les messages de type "data-only" (sans le
  // champ "notification"), ce qui n'est pas notre cas ici.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Callback optionnel appelé quand l'utilisateur tape sur une notification
  /// (premier plan, arrière-plan ou app terminée) — branché par l'écran
  /// racine de l'app pour naviguer vers la conversation concernée.
  void Function(Map<String, dynamic> data)? onNotificationTap;

  /// Initialise tout le système de notifications. À appeler une seule fois,
  /// après la connexion réussie de l'utilisateur (pour pouvoir associer
  /// immédiatement le token FCM à son compte).
  Future<void> initialize() async {
    await _requestPermission();
    await _setupLocalNotifications();
    await _registerDeviceToken();
    _listenForTokenRefresh();
    _listenForForegroundMessages();
    _listenForNotificationTaps();
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          onNotificationTap?.call({'conversation_id': response.payload});
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_highImportanceChannel);
  }

  /// Récupère le token FCM de cet appareil et l'enregistre dans Supabase,
  /// associé à l'utilisateur courant — c'est ce qui permet à l'Edge
  /// Function de savoir où envoyer la notification push.
  Future<void> _registerDeviceToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToSupabase(token);
    }
  }

  void _listenForTokenRefresh() {
    _messaging.onTokenRefresh.listen(_saveTokenToSupabase);
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    await SupabaseService.client.from('device_tokens').upsert(
      {
        'user_id': userId,
        'fcm_token': token,
        'platform': 'android',
      },
      onConflict: 'fcm_token',
    );
  }

  /// Supprime le token FCM de cet appareil de Supabase — à appeler à la
  /// déconnexion, pour qu'un compte qui se déconnecte ne reçoive plus de
  /// notifications destinées à un autre compte se connectant après lui sur
  /// le même appareil.
  Future<void> unregisterDeviceToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await SupabaseService.client.from('device_tokens').delete().eq('fcm_token', token);
    }
  }

  /// Quand l'app est au premier plan, Android/iOS n'affichent PAS
  /// automatiquement la notification FCM (comportement voulu par Firebase,
  /// pour laisser l'app gérer l'UI elle-même) — on doit donc afficher
  /// nous-mêmes une notification locale équivalente via
  /// flutter_local_notifications.
  void _listenForForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _highImportanceChannel.id,
            _highImportanceChannel.name,
            channelDescription: _highImportanceChannel.description,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: message.data['conversation_id'] as String?,
      );
    });
  }

  /// Gère le tap sur une notification quand l'app était en arrière-plan
  /// (onMessageOpenedApp) ou complètement fermée (getInitialMessage).
  void _listenForNotificationTaps() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onNotificationTap?.call(message.data);
    });

    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        onNotificationTap?.call(message.data);
      }
    });
  }
}
