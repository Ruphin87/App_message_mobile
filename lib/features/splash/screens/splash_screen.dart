import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';

/// Écran de démarrage affiché au lancement de l'app, avec une animation du
/// logo (zoom + fade-in + légère rotation), avant de rediriger vers
/// l'écran de connexion ou l'accueil selon l'état d'authentification.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Zoom : part d'un peu plus petit (0.6) vers la taille normale (1.0),
    // avec une courbe "easeOutBack" qui donne un léger rebond élégant à
    // l'arrivée plutôt qu'un arrêt sec.
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack)),
    );

    // Fade-in : apparaît pendant le premier tiers de l'animation.
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    // Légère rotation : un quart de tour partiel (pas un tour complet, pour
    // rester discret et élégant), qui se résout en même temps que le zoom.
    _rotationAnimation = Tween<double>(begin: -0.15, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)),
    );

    _controller.forward();
    _scheduleNavigation();
  }

  Future<void> _scheduleNavigation() async {
    // On attend à la fois :
    //  1. Un délai minimum pour laisser l'animation se jouer entièrement
    //     (sinon l'écran pourrait disparaître avant la fin du zoom/fade).
    //  2. Que l'état d'authentification soit réellement déterminé (pas
    //     `AuthStatus.initial`) — sinon, sur un appareil lent ou au tout
    //     premier lancement, on risquerait de rediriger vers /login même
    //     pour un utilisateur déjà connecté, simplement parce que la
    //     restauration de session Supabase n'a pas encore eu le temps de
    //     se terminer.
    final minDelay = Future.delayed(const Duration(milliseconds: 2200));
    final authReady = _waitForAuthReady();

    await Future.wait([minDelay, authReady]);
    if (!mounted) return;

    final authState = ref.read(authProvider);
    final isAuthenticated = authState.status == AuthStatus.authenticated;

    context.go(isAuthenticated ? AppRoutes.home : AppRoutes.login);
  }

  /// Attend que `authProvider` sorte de l'état `initial`, avec une limite
  /// de sécurité de 5 secondes pour ne jamais bloquer indéfiniment l'écran
  /// de démarrage si la restauration de session traîne anormalement.
  Future<void> _waitForAuthReady() async {
    if (ref.read(authProvider).status != AuthStatus.initial) return;

    final completer = Completer<void>();
    final subscription = ref.listenManual(authProvider, (previous, next) {
      if (next.status != AuthStatus.initial && !completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
    subscription.close();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: AppColors.primary,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Message_KO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
