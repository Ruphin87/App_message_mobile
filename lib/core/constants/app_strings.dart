class AppStrings {
  AppStrings._();

  static const String appName = 'Message_KO';

  // Auth
  static const String login = 'Connexion';
  static const String register = 'Inscription';
  static const String logout = 'Deconnexion';
  static const String email = 'Email';
  static const String password = 'Mot de passe';
  static const String confirmPassword = 'Confirmer le mot de passe';
  static const String name = 'Nom';
  static const String forgotPassword = 'Mot de passe oublie ?';
  static const String noAccount = 'Pas encore de compte ?';
  static const String alreadyHaveAccount = 'Deja un compte ?';
  static const String createAccount = 'Creer un compte';
  static const String signIn = 'Se connecter';
  static const String resetPassword = 'Reinitialiser le mot de passe';
  static const String sendResetLink = 'Envoyer le lien';

  // Profile
  static const String profile = 'Profil';
  static const String editProfile = 'Modifier le profil';
  static const String saveChanges = 'Enregistrer';
  static const String changePhoto = 'Changer la photo';
  static const String removePhoto = 'Supprimer la photo';

  // Contacts (Phase 2)
  static const String contacts = 'Contacts';
  static const String searchUser = 'Rechercher';
  static const String friendRequests = 'Demandes d\'amis';
  static const String addFriend = 'Ajouter';
  static const String pendingRequest = 'En attente';
  static const String accept = 'Accepter';
  static const String reject = 'Refuser';
  static const String noContacts = 'Aucun contact pour le moment';
  static const String noSearchResults = 'Aucun utilisateur trouve';
  static const String friendRequestSent = 'Demande envoyee';

  // Chat (Phase 3)
  static const String messages = 'Messages';
  static const String typeMessage = 'Votre message...';
  static const String noConversations = 'Aucune conversation pour le moment';
  static const String noMessages = 'Aucun message. Demarrez la conversation !';

  // Notifications (Phase 4)
  static const String notifications = 'Notifications';
  static const String noNotifications = 'Aucune notification pour le moment';
  static const String markAllAsRead = 'Tout marquer lu';

  // Errors
  static const String errorGeneric = 'Une erreur est survenue';
  static const String errorEmailRequired = 'L\'email est requis';
  static const String errorPasswordRequired = 'Le mot de passe est requis';
  static const String errorNameRequired = 'Le nom est requis';
  static const String errorEmailInvalid = 'Email invalide';
  static const String errorPasswordTooShort = 'Le mot de passe doit contenir au moins 6 caracteres';
  static const String errorPasswordsDoNotMatch = 'Les mots de passe ne correspondent pas';
  static const String errorLogin = 'Email ou mot de passe incorrect';
  static const String errorEmailAlreadyExists = 'Cet email est deja utilise';
  static const String errorNetwork = 'Erreur de connexion reseau';

  // Success
  static const String registerSuccess = 'Compte cree avec succes';
  static const String loginSuccess = 'Connexion reussie';
  static const String logoutSuccess = 'Deconnexion reussie';
  static const String profileUpdated = 'Profil mis a jour';
  static const String passwordResetSent = 'Email de reinitialisation envoye';

  // Validation
  static const String fieldRequired = 'Ce champ est requis';
}
