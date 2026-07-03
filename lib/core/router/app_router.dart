import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_routes.dart';
import '../constants/app_colors.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/contacts/screens/contacts_screen.dart';
import '../../features/contacts/screens/search_user_screen.dart';
import '../../features/contacts/screens/friend_requests_screen.dart';
import '../../features/calls/screens/call_screen.dart';
import '../../features/calls/widgets/incoming_call_listener.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/notifications/controllers/notification_controller.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/about/screens/about_screen.dart';
import '../../features/admin/screens/admin_auth_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../services/admin_service.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // L'écran de démarrage gère lui-même sa redirection (après son
      // animation) vers /login ou /home selon l'état d'authentification —
      // on ne doit donc jamais le rediriger automatiquement ici, sinon il
      // serait contourné avant même de pouvoir s'afficher.
      if (state.matchedLocation == AppRoutes.splash) {
        return null;
      }

      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.forgotPassword;
      final isRecoveryRoute = state.matchedLocation == AppRoutes.forgotPassword;

      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.login;
      }

      if (isAuthenticated && isAuthRoute && !isRecoveryRoute) {
        return AppRoutes.home;
      }

      if (state.matchedLocation == AppRoutes.adminDashboard &&
          !AdminService.isAdminSessionUnlocked) {
        return AppRoutes.admin;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      // Écrans accessibles en push depuis les onglets, sans bottom nav.
      GoRoute(
        path: AppRoutes.searchUser,
        builder: (context, state) => const SearchUserScreen(),
      ),
      GoRoute(
        path: AppRoutes.friendRequests,
        builder: (context, state) => const FriendRequestsScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.chat}/:userId',
        builder: (context, state) {
          final otherUser = state.extra as UserModel;
          return ChatScreen(otherUser: otherUser);
        },
      ),
      GoRoute(
        path: '${AppRoutes.call}/:callId',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! CallRouteArgs) {
            return const Scaffold(
              body: Center(child: Text('Appel indisponible')),
            );
          }
          return CallScreen(
            callId: state.pathParameters['callId']!,
            args: extra,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminAuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: AppRoutes.contacts,
            builder: (context, state) => const ContactsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.editProfile,
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Page non trouvee',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: Text('Retour a la connexion'),
            ),
          ],
        ),
      ),
    ),
  );
});

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  /// Affiche une boîte de dialogue "Voulez-vous quitter l'application ?",
  /// et ferme réellement l'app (SystemNavigator.pop) si l'utilisateur
  /// confirme.
  Future<bool> _confirmExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitter l\'application ?'),
        content: const Text('Voulez-vous vraiment fermer Message_KO ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final isOnHomeTab = currentPath == AppRoutes.home;

    return PopScope(
      // On intercepte systématiquement le bouton retour ici (canPop: false)
      // pour décider nous-mêmes du comportement : si on est déjà sur l'onglet
      // Messages (l'accueil), on demande confirmation avant de quitter
      // l'app ; sinon, on ramène simplement vers l'onglet Messages, comme
      // le fait WhatsApp/Messenger avec leur bottom navigation.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (!isOnHomeTab) {
          context.go(AppRoutes.home);
          return;
        }

        final shouldExit = await _confirmExit(context);
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IncomingCallListener(child: child),
        bottomNavigationBar: const BottomNavBar(),
      ),
    );
  }
}

class BottomNavBar extends ConsumerWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    int currentIndex = 0;
    if (currentPath == AppRoutes.home) {
      currentIndex = 0;
    } else if (currentPath == AppRoutes.contacts) {
      currentIndex = 1;
    } else if (currentPath == AppRoutes.notifications) {
      currentIndex = 2;
    } else if (currentPath.startsWith(AppRoutes.profile)) {
      currentIndex = 3;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildNavItem(
                context: context,
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'Messages',
                index: 0,
                currentIndex: currentIndex,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'Contacts',
                index: 1,
                currentIndex: currentIndex,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.notifications_none,
                activeIcon: Icons.notifications,
                label: 'Notifications',
                index: 2,
                currentIndex: currentIndex,
                badgeCount: unreadCount,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profil',
                index: 3,
                currentIndex: currentIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required int currentIndex,
    int badgeCount = 0,
  }) {
    final isSelected = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          switch (index) {
            case 0:
              context.go(AppRoutes.home);
            case 1:
              context.go(AppRoutes.contacts);
            case 2:
              context.go(AppRoutes.notifications);
            case 3:
              context.go(AppRoutes.profile);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    size: 24,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 16),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
