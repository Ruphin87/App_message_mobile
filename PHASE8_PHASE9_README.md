# Phase 8 & 9 - Sécurité et Administration

## Vue d'ensemble

Cette implémentation ajoute deux phases majeures à l'application Message_KO :

### Phase 8: Sécurité
- **Chiffrement des données**: Utilise AES pour le chiffrement des messages sensibles
- **JWT**: Tokens JWT pour l'authentification sécurisée
- **HTTPS**: Supabase gère automatiquement HTTPS pour toutes les connexions
- **Règles RLS (Row Level Security)**: Restrictions d'accès aux données dans Supabase
- **Protection contre le spam**: Limitation du taux d'envoi (10 messages/min, 5 appels/min)

### Phase 9: Administration
- **Authentification Admin**: Mot de passe: `twins@2026RP!`
- **Tableau de bord**: Vue d'ensemble avec statistiques
  - Nombre d'utilisateurs
  - Nombre de messages
  - Utilisateurs bloqués
  - Signalements
- **Gestion des messages**: Supprimer les messages > 30 jours
- **Gestion des utilisateurs**: Bloquer/débloquer les utilisateurs
- **Gestion des signalements**: Résoudre et supprimer les signalements
- **Alertes**: Notifications pour les messages expirant

## Fichiers créés/modifiés

### Services
- `lib/core/services/security_service.dart` - Chiffrement et JWT
- `lib/core/services/spam_protection_service.dart` - Protection contre le spam
- `lib/core/services/admin_service.dart` - Logique administrative
- `lib/models/call_model.dart` - Modèle d'appel avec statuts

### Features Admin
- `lib/features/admin/screens/admin_auth_screen.dart` - Authentification
- `lib/features/admin/screens/admin_dashboard_screen.dart` - Dashboard
- `lib/features/admin/controllers/admin_controller.dart` - Contrôleur Riverpod
- `lib/features/admin/widgets/` - Composants d'interface

### Chat
- `lib/features/chat/widgets/call_event_bubble.dart` - Affichage des appels
- `lib/features/chat/repositories/chat_with_calls_repository.dart` - Fusion messages/appels

### Base de données
- `supabase/migrations/20260703_phase8_phase9.sql` - Migrations SQL

## Configuration requise

### 1. Mise à jour de pubspec.yaml
Les packages suivants ont été ajoutés:
```yaml
crypto: ^3.0.3
encrypt: ^4.0.1
```

Lancez: `flutter pub get`

### 2. Migrations Supabase

Exécutez le script SQL dans l'interface Supabase:
```sql
-- Fichier: supabase/migrations/20260703_phase8_phase9.sql
```

Cela créera:
- Colonnes pour les utilisateurs bloqués
- Table `reports` pour les signalements
- Table `admin_logs` pour l'audit
- Fonctions d'administration

### 3. Initialisation des services

Dans `main.dart`, initialisez le service de protection contre le spam:
```dart
await SpamProtectionService.init();
```

## Utilisation

### 1. Authentification Admin

```dart
// Vérifier le mot de passe admin
bool isValid = AdminService.verifyAdminPassword('twins@2026RP!');

// Accéder au dashboard admin
context.push('/admin/auth');  // Écran de connexion
context.push('/admin/dashboard');  // Tableau de bord (après connexion)
```

### 2. Protection contre le spam

```dart
// Avant d'envoyer un message
final canSend = await SpamProtectionService.canSendMessage(userId);
if (!canSend) {
    // Montrer une alerte: utilisateur est en spam
}

// Enregistrer l'envoi
await SpamProtectionService.recordMessageSent(userId);
```

### 3. Chiffrement des données

```dart
// Chiffrer
String encrypted = SecurityService.encryptText('Texte secret');

// Déchiffrer
String decrypted = SecurityService.decryptText(encrypted);

// Hash du mot de passe
String hashed = SecurityService.hashPassword('password123');

// Vérifier le mot de passe
bool isCorrect = SecurityService.verifyPassword('password123', hashed);
```

### 4. JWT (Supabase gère automatiquement)

```dart
// Obtenir le token JWT de l'utilisateur actuel
String? token = SupabaseService.currentSession?.accessToken;

// Le token est automatiquement ajouté à toutes les requêtes
```

### 5. Gestion des appels

```dart
// Marquer un appel comme échoué
await callRepository.failCall(callId, 'Réseau indisponible');

// Marquer comme sans réponse
await callRepository.missedCall(callId);
```

### 6. Affichage des appels dans le chat

Les appels apparaissent maintenant dans le chat avec:
- Statut: Réussi, Échoué, Manqué, Décliné
- Icônes visuelles
- Raison d'erreur si applicable

### 7. Intégration dans les routes

Ajoutez les routes admin à votre `router.dart`:
```dart
GoRoute(
  path: '/admin/auth',
  builder: (context, state) => const AdminAuthScreen(),
),
GoRoute(
  path: '/admin/dashboard',
  builder: (context, state) => const AdminDashboardScreen(),
),
```

## Fonctionnalités détaillées

### Dashboard Admin

Le dashboard affiche:
1. **Statistiques en direct**
   - Total d'utilisateurs
   - Total de messages
   - Utilisateurs bloqués
   - Signalements

2. **Gestion des messages**
   - Filtrer par ancienneté (1j, 1sem, 1mois, 3mois)
   - Supprimer les messages individuels
   - Batch delete (tous les messages > X jours)

3. **Gestion des utilisateurs**
   - Liste des utilisateurs bloqués
   - Débloquer les utilisateurs
   - Raison du blocage

4. **Gestion des signalements**
   - Liste des signalements en attente
   - Marquer comme résolu
   - Supprimer les signalements
   - Voir la raison du signalement

5. **Outils d'administration**
   - Supprimer les messages > 30 jours
   - Voir les messages qui expirent bientôt
   - Affichage des alertes

### Protection contre le spam

Limite configurable:
- 10 messages par minute par utilisateur
- 5 appels par minute par utilisateur
- Blocage 15 minutes après dépassement

### Sécurité des données

1. **Chiffrement AES-256** pour les données sensibles
2. **Hashing SHA-256** pour les mots de passe
3. **RLS (Row Level Security)** sur les appels et signalements
4. **JWT** pour l'authentification
5. **HTTPS** obligatoire sur Supabase

## Scripts SQL utiles

### Nettoyer les messages expirés (à exécuter régulièrement)

```sql
SELECT public.cleanup_expired_messages();
```

### Bloquer un utilisateur

```sql
UPDATE public.users SET is_blocked = true WHERE id = 'user-id';
INSERT INTO public.admin_logs (admin_id, action, resource_type, resource_id)
VALUES (auth.uid(), 'BLOCK_USER', 'user', 'user-id');
```

### Voir les admin logs

```sql
SELECT * FROM public.admin_logs ORDER BY created_at DESC LIMIT 50;
```

## Points clés d'intégration

### 1. Chat avec affichage des appels

Mettre à jour `chat_screen.dart` pour afficher les appels:
```dart
// Dans la liste des messages, déterminer si c'est un appel ou un message
if (item is ChatCallItem) {
    return CallEventBubble(
        call: item.call,
        isMine: isMine,
    );
} else {
    // Afficher le message normalement
}
```

### 2. Call Controller

Mettre à jour le contrôleur d'appels pour:
```dart
// En cas d'erreur de connexion
await ref.read(callRepositoryProvider).failCall(
    callId,
    'Erreur de connexion WebRTC'
);

// Si l'appelé ne répond pas (après timeout)
await ref.read(callRepositoryProvider).missedCall(callId);
```

### 3. Routes admin

Ajouter à votre router:
```dart
// Permettre l'accès au pannel admin via une entrée secrète
// Par exemple, appuyer 5 fois sur le logo de l'app
// Ou accès via menu développeur
```

## Déploiement

1. **Test local**
   ```bash
   flutter run
   ```
   - Tester l'authentification admin
   - Tester la gestion des messages
   - Tester la protection contre le spam

2. **Staging**
   - Déployer les migrations Supabase
   - Tester sur un groupe d'utilisateurs

3. **Production**
   - Backup de la base de données
   - Déployer les migrations
   - Déployer l'application
   - Monitorer les logs

## Sécurité - Checklist

- [x] Mots de passe hashés
- [x] JWT implémenté
- [x] RLS activé sur les tables sensibles
- [x] Chiffrement AES pour les données sensibles
- [x] Protection contre le spam
- [x] HTTPS forcé (Supabase)
- [x] Audit logs pour les actions admin
- [x] Messages expirés après 30 jours
- [ ] 2FA (À implémenter)
- [ ] Rate limiting côté serveur (À configurer)
- [ ] Sanitisation des inputs (À vérifier)

## Problèmes courants

### Le mot de passe admin ne fonctionne pas
- Assurez-vous que vous utilisez exactement: `twins@2026RP!`
- Le hashing doit correspondre exactement

### Les messages n'apparaissent pas dans le dashboard
- Vérifier que la migration Supabase a été exécutée
- Vérifier que RLS est activé sur la table `messages`
- Vérifier les permissions utilisateur

### Le spam protection ne fonctionne pas
- Assurez-vous que `SpamProtectionService.init()` a été appelé au démarrage
- Vérifier que `SharedPreferences` est initialisé

## Support

Pour toute question ou problème, consultez:
1. Les logs de la console
2. Les logs Supabase
3. La documentation Flutter Riverpod
4. La documentation Supabase
