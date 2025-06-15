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

  List<Lobby> get publicLobbies => _publicLobbies;
  Lobby? get currentLobby => _currentLobby;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInLobby => _currentLobby != null;
  bool get isHost => _currentLobby?.hostPlayerId == FirebaseAuth.instance.currentUser?.uid;

  void initialize() {
    _subscribeToPublicLobbies();
  }

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

  Future<bool> joinPrivateLobby(String accessCode) async {
    _setLoading(true);
    _clearError();

    try {
      print('🔐 LobbyProvider: Joining private lobby with code: $accessCode');

      final lobbyId = await LobbyService.joinPrivateLobby(accessCode);
      print('✅ LobbyService returned lobby ID: $lobbyId');

      await joinLobby(lobbyId);

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

  Future<void> joinLobby(String lobbyId) async {
    _currentLobbySubscription?.cancel();

    _currentLobbySubscription = LobbyService.getLobby(lobbyId).listen(
          (lobby) {
        _currentLobby = lobby;
        notifyListeners();

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

  void _handleGameStarting(Lobby lobby) {
    print('🎮 Game starting for lobby: ${lobby.id}');
  }

  bool shouldNavigateToGame() {
    return _currentLobby?.status == LobbyStatus.starting;
  }

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

  Future<void> refreshLobbies() async {
    _subscribeToPublicLobbies();
  }

  bool canJoinLobby(Lobby lobby) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    return lobby.status == LobbyStatus.waiting &&
        lobby.currentPlayers < lobby.maxPlayers &&
        !lobby.playersList.any((player) => player.id == user.uid);
  }

  Future<Lobby?> getCurrentUserLobby() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      print('🔍 Checking for current user lobby...');

      final userLobbies = await LobbyService.getUserLobbies().first;
      print('📋 Found ${userLobbies.length} lobbies user is in');

      final activeLobby = userLobbies.where((lobby) {
        final isActive = lobby.status == LobbyStatus.waiting ||
            lobby.status == LobbyStatus.starting ||
            lobby.status == LobbyStatus.inProgress;

        print('   Lobby ${lobby.id}: status=${lobby.status}, active=$isActive');
        return isActive;
      }).toList();

      if (activeLobby.isNotEmpty) {
        print('✅ Found active lobby: ${activeLobby.first.id}');
        _currentLobby = activeLobby.first;
        notifyListeners();
        await joinLobby(_currentLobby!.id);
        return _currentLobby;
      } else {
        print('✅ No active lobbies found');

        for (final lobby in userLobbies) {
          if (lobby.status == LobbyStatus.completed) {
            print('🧹 Cleaning up completed lobby: ${lobby.id}');
            try {
              await LobbyService.leaveLobby(lobby.id);
            } catch (e) {
              print('⚠️ Error leaving completed lobby: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error getting user lobby: $e');
    }

    return null;
  }

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

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();

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

  void forceCleanupLobbyState() {
    print('🧹 Force cleaning up lobby provider state');
    _currentLobbySubscription?.cancel();
    _currentLobby = null;
    _clearError();
    notifyListeners();
    print('✅ Lobby provider state cleared');
  }

}