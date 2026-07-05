import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_model.dart';
import '../../../models/friend_model.dart';
import '../repositories/contacts_repository.dart';

// ==================== RECHERCHE ====================

class SearchState {
  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  final List<UserModel> results;
  final bool isLoading;
  final String? error;
  final String query;

  SearchState copyWith({
    List<UserModel>? results,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._repository) : super(const SearchState());

  final ContactsRepository _repository;

  Future<void> search(String query) async {
    state = state.copyWith(query: query);

    if (query.trim().isEmpty) {
      state = state.copyWith(results: [], isLoading: false, error: null);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final results = await _repository.searchUsers(query);
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors de la recherche',
      );
    }
  }

  void clear() {
    state = const SearchState();
  }
}

// ==================== AMIS / DEMANDES ====================

class ContactsState {
  const ContactsState({
    this.friends = const [],
    this.pendingRequests = const [],
    this.isLoading = false,
    this.error,
  });

  final List<FriendModel> friends;
  final List<FriendModel> pendingRequests;
  final bool isLoading;
  final String? error;

  ContactsState copyWith({
    List<FriendModel>? friends,
    List<FriendModel>? pendingRequests,
    bool? isLoading,
    String? error,
  }) {
    return ContactsState(
      friends: friends ?? this.friends,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ContactsNotifier extends StateNotifier<ContactsState> {
  ContactsNotifier(this._repository) : super(const ContactsState()) {
    _loadInitial();
    _listenForChanges();
  }

  final ContactsRepository _repository;
  StreamSubscription<void>? _changesSubscription;
  Timer? _debounceTimer;

  /// Démarrage "offline-first" : on affiche D'ABORD le cache local
  /// (amis + demandes en attente, instantané, même hors connexion), puis on
  /// lance la synchronisation réseau en arrière-plan.
  Future<void> _loadInitial() async {
    try {
      final localResults = await Future.wait<dynamic>([
        _repository.getLocalFriends(),
        _repository.getLocalPendingRequests(),
      ]);
      if (!mounted) return;
      final localFriends = localResults[0] as List<FriendModel>;
      final localPending = localResults[1] as List<FriendModel>;

      if (localFriends.isNotEmpty || localPending.isNotEmpty) {
        state = state.copyWith(
          friends: localFriends,
          pendingRequests: localPending,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: true);
      }
    } catch (_) {
      // Le cache local est best-effort : une erreur ici ne doit jamais
      // bloquer le chargement réseau qui suit.
    }

    if (!mounted) return;
    await loadAll();
  }

  /// Synchronisation réseau (source de vérité) : charge la liste des amis ET
  /// des demandes en attente EN PARALLÈLE (Future.wait), et met à jour le
  /// cache local (fait par le repository).
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait<dynamic>([
        _repository.getFriends(),
        _repository.getPendingRequests(),
      ]);
      if (!mounted) return;
      final friends = results[0] as List<FriendModel>;
      final pending = results[1] as List<FriendModel>;
      state = state.copyWith(
        friends: friends,
        pendingRequests: pending,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors du chargement des contacts',
      );
    }
  }

  /// Écoute en temps réel tout changement sur la table `friends` (nouvelle
  /// demande reçue, acceptation, refus) et relance automatiquement le
  /// chargement — c'est ce qui fait apparaître une demande d'ami reçue dès
  /// qu'elle est envoyée, sans avoir à rouvrir l'écran manuellement.
  ///
  /// Debounce de 300 ms pour éviter les rechargements en rafale.
  void _listenForChanges() {
    _changesSubscription = _repository.watchAnyFriendChange().listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        loadAll();
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _changesSubscription?.cancel();
    super.dispose();
  }

  Future<bool> sendFriendRequest(String friendId) async {
    try {
      await _repository.sendFriendRequest(friendId);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Erreur lors de l\'envoi de la demande');
      return false;
    }
  }

  Future<void> acceptRequest(String friendRowId) async {
    try {
      await _repository.acceptFriendRequest(friendRowId);
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: 'Erreur lors de l\'acceptation');
    }
  }

  Future<void> rejectRequest(String friendRowId) async {
    try {
      await _repository.rejectFriendRequest(friendRowId);
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: 'Erreur lors du refus');
    }
  }

  Future<void> removeFriend(String friendRowId) async {
    try {
      await _repository.removeFriendRelation(friendRowId);
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: 'Erreur lors de la suppression');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ==================== PROVIDERS ====================

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository();
});

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.watch(contactsRepositoryProvider));
});

final contactsProvider = StateNotifierProvider<ContactsNotifier, ContactsState>((ref) {
  return ContactsNotifier(ref.watch(contactsRepositoryProvider));
});