import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lobby_model.dart';
import '../services/lobby_service.dart';

class LobbyProvider extends ChangeNotifier {
  List<Lobby> _publicLobbies = [];
  Lobby? _currentLobby;
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _publicLobbiesSubscription;
  StreamSubscription? _currentLobbySubscription;

  // Getters
  List<Lobby> get publicLobbies => _publicLobbies;
  Lobby? get currentLobby => _currentLobby;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInLobby => _currentLobby != null;
  bool get isHost => _currentLobby?.hostPlayerId == FirebaseAuth.instance.currentUser?.uid;

  // Initialize provider
  void initialize() {
    _subscribeToPublicLobbies();
  }

  // Subscribe to public lobbies
  void _subscribeToPublicLobbies() {
    _publicLobbiesSubscription?.cancel();
    _publicLobbiesSubscription = LobbyService.getPublicLobbies().listen(
          (lobbies) {
        _publicLobbies = lobbies;
        notifyListeners();
      },
      onError: (error) {
        _setError('Failed to load lobbies: $error');
      },
    );
  }

  // Create a new lobby
  Future<String?> createLobby(LobbyCreationRequest request) async {
    _setLoading(true);
    _clearError();

    try {
      final lobbyId = await LobbyService.createLobby(request);
      await joinLobby(lobbyId);
      return lobbyId;
    } catch (e) {
      _setError('Failed to create lobby: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Join a public lobby
  Future<bool> joinPublicLobby(String lobbyId) async {
    _setLoading(true);
    _clearError();

    try {
      await LobbyService.joinPublicLobby(lobbyId);
      await joinLobby(lobbyId);
      return true;
    } catch (e) {
      _setError('Failed to join lobby: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Join a private lobby with access code
  Future<bool> joinPrivateLobby(String accessCode) async {
    _setLoading(true);
    _clearError();

    try {
      print('🔐 LobbyProvider: Joining private lobby with code: $accessCode');

      final lobbyId = await LobbyService.joinPrivateLobby(accessCode);
      print('✅ LobbyService returned lobby ID: $lobbyId');

      // Join the lobby to start listening to updates
      await joinLobby(lobbyId);

      // Wait a bit for the lobby data to be populated
      await Future.delayed(Duration(milliseconds: 1000));

      if (_currentLobby != null) {
        print('✅ Successfully joined private lobby: ${_currentLobby!.id}');
        print('Players in lobby: ${_currentLobby!.playersList.map((p) => p.name).join(", ")}');
        return true;
      } else {
        print('❌ Current lobby is still null after joining');
        _setError('Failed to load lobby data after joining');
        return false;
      }
    } catch (e) {
      print('❌ LobbyProvider error joining private lobby: $e');
      _setError('Failed to join private lobby: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Join lobby and subscribe to updates
  Future<void> joinLobby(String lobbyId) async {
    _currentLobbySubscription?.cancel();

    _currentLobbySubscription = LobbyService.getLobby(lobbyId).listen(
          (lobby) {
        _currentLobby = lobby;
        notifyListeners();

        // Handle game start
        if (lobby?.status == LobbyStatus.starting) {
          _handleGameStarting(lobby!);
        }
      },
      onError: (error) {
        _setError('Lobby connection error: $error');
        _currentLobby = null;
        notifyListeners();
      },
    );
  }

  // Leave current lobby
  Future<bool> leaveLobby() async {
    if (_currentLobby == null) return true;

    _setLoading(true);
    _clearError();

    try {
      await LobbyService.leaveLobby(_currentLobby!.id);
      _currentLobbySubscription?.cancel();
      _currentLobby = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to leave lobby: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Start game (host only)
  Future<bool> startGame() async {
    if (_currentLobby == null || !isHost) {
      print('❌ Cannot start game - currentLobby: ${_currentLobby != null}, isHost: $isHost');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      print('🎮 LobbyProvider.startGame - calling service...');
      await LobbyService.startGame(_currentLobby!.id);
      print('✅ LobbyService.startGame completed');
      return true;
    } catch (e) {
      print('❌ LobbyProvider.startGame error: $e');
      _setError('Failed to start game: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Handle game starting
  void _handleGameStarting(Lobby lobby) {
    // This will be called when the lobby status changes to 'starting'
    print('🎮 Game starting for lobby: ${lobby.id}');

    // You can emit a custom event or use a callback here
    // For now, we'll let the UI handle navigation by listening to status changes
  }

  // Check if current user should be navigated to game
  bool shouldNavigateToGame() {
    return _currentLobby?.status == LobbyStatus.starting;
  }

  // Get game navigation data
  Map<String, dynamic>? getGameNavigationData() {
    if (_currentLobby?.status == LobbyStatus.starting) {
      return {
        'lobby': _currentLobby,
        'gameSessionId': _currentLobby?.gameSessionId,
        'gameServerEndpoint': _currentLobby?.gameServerEndpoint,
      };
    }
    return null;
  }

  // Get lobby by ID
  Future<Lobby?> getLobbyById(String lobbyId) async {
    try {
      final stream = LobbyService.getLobby(lobbyId);
      final lobby = await stream.first;
      return lobby;
    } catch (e) {
      _setError('Failed to get lobby: $e');
      return null;
    }
  }

  // Refresh public lobbies
  Future<void> refreshLobbies() async {
    // The stream will automatically update, but we can trigger a manual refresh
    _subscribeToPublicLobbies();
  }

  // Check if user can join lobby
  bool canJoinLobby(Lobby lobby) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    return lobby.status == LobbyStatus.waiting &&
        lobby.currentPlayers < lobby.maxPlayers &&
        !lobby.playersList.any((player) => player.id == user.uid);
  }

  // Get user's current lobby if any
  Future<Lobby?> getCurrentUserLobby() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final userLobbies = await LobbyService.getUserLobbies().first;
      final activeLobby = userLobbies.where((lobby) =>
      lobby.status == LobbyStatus.waiting ||
          lobby.status == LobbyStatus.starting ||
          lobby.status == LobbyStatus.inProgress
      ).toList();

      if (activeLobby.isNotEmpty) {
        _currentLobby = activeLobby.first;
        notifyListeners();
        await joinLobby(_currentLobby!.id);
        return _currentLobby;
      }
    } catch (e) {
      print('Error getting user lobby: $e');
    }

    return null;
  }

  // Filter lobbies by criteria
  List<Lobby> getFilteredLobbies({
    GameMode? gameMode,
    String? difficulty,
    bool? hasSpace,
  }) {
    return _publicLobbies.where((lobby) {
      if (gameMode != null && lobby.gameMode != gameMode) return false;
      if (difficulty != null && lobby.gameSettings.difficulty != difficulty) return false;
      if (hasSpace == true && lobby.currentPlayers >= lobby.maxPlayers) return false;
      return true;
    }).toList();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();

    // Auto-clear error after 5 seconds
    Timer(Duration(seconds: 5), () {
      if (_error == error) {
        _clearError();
      }
    });
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _publicLobbiesSubscription?.cancel();
    _currentLobbySubscription?.cancel();
    super.dispose();
  }
}