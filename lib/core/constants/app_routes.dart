class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';

  // Phase 1
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String home = '/home';

  // Phase 2 - Contacts
  static const String contacts = '/contacts';
  static const String searchUser = '/contacts/search';
  static const String friendRequests = '/contacts/requests';
  static const String friendProfile = '/contacts/profile';

  // Phase 3 - Chat
  static const String chatList = '/chat';
  static const String chat = '/chat'; // utilisé avec suffixe '/:userId' -> voir app_router.dart

  // Phase 4 - Notifications
  static const String notifications = '/notifications';

  // Phase 6/7 - Appels WebRTC
  static const String call = '/call';

  // Paramètres / À propos
  static const String settings = '/profile/settings';
  static const String about = '/profile/about';
  static const String update = '/profile/settings/update';

  // Phase 9 - Administration
  static const String admin = '/admin';
  static const String adminDashboard = '/admin/dashboard';
}
