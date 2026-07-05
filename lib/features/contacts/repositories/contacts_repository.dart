import '../../../core/services/supabase_service.dart';
import '../../../core/services/local_database_service.dart';
import '../../../models/user_model.dart';
import '../../../models/friend_model.dart';

class ContactsRepository {
  ContactsRepository();

  final _client = SupabaseService.client;
  final _localDb = LocalDatabaseService.instance;

  String? get _ownerId => SupabaseService.currentUserId;

  // ==================== RECHERCHE D'UTILISATEURS ====================

  /// Recherche des utilisateurs par nom ou email (insensible à la casse).
  /// Exclut l'utilisateur courant des résultats.
  /// Toujours en direct contre Supabase (recherche globale, n'a pas de sens
  /// hors connexion ni en cache local).
  Future<List<UserModel>> searchUsers(String query) async {
    final currentUserId = SupabaseService.currentUserId;
    if (query.trim().isEmpty) return [];

    final response = await _client
        .from('users')
        .select()
        .or('nom.ilike.%$query%,email.ilike.%$query%')
        .neq('id', currentUserId ?? '')
        .limit(30);

    return (response as List)
        .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ==================== DEMANDES D'AMI ====================

  /// Envoie une demande d'ami à [friendId].
  Future<void> sendFriendRequest(String friendId) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) throw Exception('Utilisateur non connecté');

    await _client.from('friends').insert({
      'user_id': currentUserId,
      'friend_id': friendId,
      'status': 'pending',
    });
  }

  /// Accepte une demande d'ami reçue.
  Future<void> acceptFriendRequest(String friendRowId) async {
    await _client
        .from('friends')
        .update({'status': 'accepted'})
        .eq('id', friendRowId);
  }

  /// Refuse une demande d'ami reçue.
  Future<void> rejectFriendRequest(String friendRowId) async {
    await _client
        .from('friends')
        .update({'status': 'rejected'})
        .eq('id', friendRowId);
  }

  /// Annule une demande envoyée, ou supprime une relation existante.
  /// Supprime aussi la ligne du cache local immédiatement.
  Future<void> removeFriendRelation(String friendRowId) async {
    await _client.from('friends').delete().eq('id', friendRowId);

    final ownerId = _ownerId;
    if (ownerId != null) {
      await _localDb.deleteFriend(ownerId, friendRowId);
    }
  }

  // ==================== LECTURE LOCALE (cache instantané) ====================

  /// Lecture INSTANTANÉE depuis le cache local des demandes en attente.
  Future<List<FriendModel>> getLocalPendingRequests() async {
    final ownerId = _ownerId;
    if (ownerId == null) return [];

    final rows = await _localDb.getFriendsByStatus(
      ownerId,
      status: 'pending',
      column: 'friend_id',
      currentUserId: ownerId,
    );

    return _hydrateFriendProfiles(ownerId, rows);
  }

  /// Lecture INSTANTANÉE depuis le cache local des amis acceptés.
  Future<List<FriendModel>> getLocalFriends() async {
    final ownerId = _ownerId;
    if (ownerId == null) return [];

    final asRequesterRows = await _localDb.getFriendsByStatus(
      ownerId,
      status: 'accepted',
      column: 'user_id',
      currentUserId: ownerId,
    );
    final asReceiverRows = await _localDb.getFriendsByStatus(
      ownerId,
      status: 'accepted',
      column: 'friend_id',
      currentUserId: ownerId,
    );

    return _hydrateFriendProfiles(ownerId, [...asRequesterRows, ...asReceiverRows]);
  }

  /// Reconstruit les [FriendModel] à partir des lignes SQLite brutes, en
  /// rattachant le profil (`friendProfile`) depuis `local_users` grâce à la
  /// colonne `friend_profile_id` enregistrée au moment du cache.
  Future<List<FriendModel>> _hydrateFriendProfiles(
    String ownerId,
    List<Map<String, dynamic>> rows,
  ) async {
    return Future.wait(rows.map((dbRow) async {
      final friend = FriendModel.fromLocalDb(dbRow);
      final profileId = dbRow['friend_profile_id'] as String?;
      if (profileId == null) return friend;
      final userRow = await _localDb.getUser(ownerId, profileId);
      return friend.copyWith(
        friendProfile: userRow != null ? UserModel.fromLocalDb(userRow) : null,
      );
    }));
  }

  // ==================== LECTURE RÉSEAU (source de vérité + mise à jour du cache) ====================

  /// Liste des demandes d'ami reçues, en attente, avec le profil du demandeur.
  /// Met à jour le cache local (`local_friends` + `local_users`).
  Future<List<FriendModel>> getPendingRequests() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return [];

    final response = await _client
        .from('friends')
        .select('*, friend_profile:users!friends_user_id_fkey(*)')
        .eq('friend_id', currentUserId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    final requests = (response as List)
        .map((json) => FriendModel.fromJson(json as Map<String, dynamic>))
        .toList();

    await _cacheFriends(currentUserId, requests);

    return requests;
  }

  /// Liste des amis acceptés (dans les deux sens : demandeur ou destinataire),
  /// avec le profil de l'ami affiché via [FriendModel.friendProfile].
  /// Met à jour le cache local (`local_friends` + `local_users`).
  ///
  /// Les deux requêtes (en tant que demandeur / en tant que destinataire)
  /// sont lancées en parallèle avec Future.wait au lieu de s'enchaîner l'une
  /// après l'autre, pour réduire le temps de chargement de la liste de moitié.
  Future<List<FriendModel>> getFriends() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return [];

    final asRequesterFuture = _client
        .from('friends')
        .select('*, friend_profile:users!friends_friend_id_fkey(*)')
        .eq('user_id', currentUserId)
        .eq('status', 'accepted');

    final asReceiverFuture = _client
        .from('friends')
        .select('*, friend_profile:users!friends_user_id_fkey(*)')
        .eq('friend_id', currentUserId)
        .eq('status', 'accepted');

    final results = await Future.wait<dynamic>([asRequesterFuture, asReceiverFuture]);
    final asRequester = results[0] as List;
    final asReceiver = results[1] as List;

    final all = [...asRequester, ...asReceiver];

    final friends = all
        .map((json) => FriendModel.fromJson(json as Map<String, dynamic>))
        .toList();

    await _cacheFriends(currentUserId, friends);

    return friends;
  }

  /// Écrit une liste de [FriendModel] (avec leur `friendProfile` déjà
  /// résolu) dans le cache local : profils dans `local_users`, relations
  /// dans `local_friends` avec leur `friend_profile_id`.
  Future<void> _cacheFriends(String ownerId, List<FriendModel> friends) async {
    final profiles = friends
        .where((f) => f.friendProfile != null)
        .map((f) => f.friendProfile!.toLocalDb())
        .toList();

    await _localDb.upsertUsers(ownerId, profiles);
    await _localDb.upsertFriends(
      ownerId,
      friends.map((f) => f.toLocalDb(friendProfileId: f.friendProfile?.id)).toList(),
    );
  }

  /// Renvoie le statut de relation avec [otherUserId], ou null si aucune relation.
  /// Utile pour afficher le bon bouton (Ajouter / En attente / Ami) sur un profil.
  Future<FriendModel?> getRelationWith(String otherUserId) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return null;

    final response = await _client
        .from('friends')
        .select()
        .or(
          'and(user_id.eq.$currentUserId,friend_id.eq.$otherUserId),'
          'and(user_id.eq.$otherUserId,friend_id.eq.$currentUserId)',
        )
        .maybeSingle();

    if (response == null) return null;
    return FriendModel.fromJson(response);
  }

  /// Stream temps réel GLOBAL : émet un événement chaque fois qu'une ligne de
  /// la table `friends` est créée ou modifiée (nouvelle demande, acceptation,
  /// refus, suppression), peu importe qui est concerné.
  ///
  /// Comme pour `watchAnyMessageChange()`, ce flux n'est pas filtré par
  /// utilisateur côté serveur (limite du `.stream()` de Supabase avec un
  /// filtre OR sur deux colonnes) — il sert uniquement de déclencheur pour
  /// relancer `getFriends()` / `getPendingRequests()`, qui restent protégés
  /// par les RLS de la table.
  ///
  /// ⚠️ Nécessite que la table `friends` soit ajoutée à la publication
  /// Realtime de Supabase :
  ///   ALTER PUBLICATION supabase_realtime ADD TABLE friends;
  Stream<void> watchAnyFriendChange() {
    return _client
        .from('friends')
        .stream(primaryKey: ['id'])
        .map((_) {});
  }
}