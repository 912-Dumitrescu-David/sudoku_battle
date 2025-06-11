// services/lobby_service.dart - UPDATED VERSION (Powerup integration)
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/lobby_model.dart';
import '../utils/sudoku_engine.dart';
import '../services/game_state_service.dart';
import '../services/powerup_service.dart'; // 🔥 NEW: Import powerup service

class LobbyService {
  // Use your custom "lobbies" database instead of default
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'lobbies',
  );
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection names defined here
  static const String _lobbiesCollection = 'lobbies';
  static const String _usersCollection = 'users';
  static const String _gameResultsCollection = 'gameResults';
  static const String _movesCollection = 'moves';

  // Create a new lobby with puzzle generated immediately
  static Future<String> createLobby(LobbyCreationRequest request) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Get user data
      final userData = await getUserData(user.uid);

      // Generate puzzle immediately when creating lobby
      print('🎲 Generating puzzle for difficulty: ${request.gameSettings.difficulty}');
      final sharedPuzzle = _generateSharedPuzzle(request.gameSettings.difficulty);
      print('✅ Puzzle generated with ID: ${sharedPuzzle['id']}');

      final accessCode = request.isPrivate ? _generateAccessCode() : null;

      // Create player object
      final hostPlayer = Player(
        id: user.uid,
        name: userData['name'] ?? user.displayName ?? 'Unknown',
        avatarUrl: userData['avatarUrl'] ?? user.photoURL,
        rating: userData['rating'] ?? 1000,
        joinedAt: DateTime.now(),
      );

      // Create lobby data map with shared puzzle
      final lobbyData = {
        'hostPlayerId': user.uid,
        'hostPlayerName': hostPlayer.name,
        'gameMode': request.gameMode.toString().split('.').last,
        'isPrivate': request.isPrivate,
        'accessCode': accessCode,
        'maxPlayers': request.maxPlayers,
        'currentPlayers': 1,
        'playersList': [hostPlayer.toMap()],
        'gameSettings': request.gameSettings.toMap(),
        'status': 'waiting',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'startedAt': null,
        'gameSessionId': null,
        'gameServerEndpoint': null,
        'sharedPuzzle': sharedPuzzle,
      };

      if (request.gameMode == GameMode.coop) {
        lobbyData['sharedHintCount'] = 6;
        lobbyData['sharedMistakeCount'] = 0;
      }

      print('Creating lobby with shared puzzle');

      final docRef = await _firestore
          .collection(_lobbiesCollection)
          .add(lobbyData);

      final lobbyId = docRef.id;

      // 🔥 NEW: Initialize powerups if this is a powerup game mode
      if (request.gameMode == GameMode.powerup) {
        print('🔮 Initializing powerup system for powerup lobby: $lobbyId');
        await PowerupService.initializePowerups(lobbyId);
        print('✅ Powerup system initialized');
      }

      print('Lobby created successfully with ID: $lobbyId');
      return lobbyId;

    } catch (e) {
      print('Error creating lobby: $e');
      rethrow;
    }
  }

  // CO-OP: New method to decrement the shared hint count using a transaction
  static Future<void> useSharedHint(String lobbyId) async {
    final lobbyRef = _firestore.collection(_lobbiesCollection).doc(lobbyId);
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(lobbyRef);
        if (!snapshot.exists) {
          throw Exception("Lobby does not exist!");
        }
        final currentHints = snapshot.data()?['sharedHintCount'] ?? 0;
        if (currentHints > 0) {
          transaction.update(lobbyRef, {'sharedHintCount': currentHints - 1});
        }
      });
    } catch (e) {
      print("Failed to use shared hint: $e");
    }
  }


  // Generate shared puzzle using SudokuEngine with proper Firestore serialization
  static Map<String, dynamic> _generateSharedPuzzle(String difficulty) {
    try {
      print('🎯 Generating puzzle with SudokuEngine for difficulty: $difficulty');

      // Convert string to Difficulty enum
      Difficulty difficultyEnum = _stringToDifficulty(difficulty);

      // Generate puzzle using SudokuEngine
      final rawPuzzleData = SudokuEngine.generatePuzzle(difficultyEnum);
      print('✅ Raw puzzle generated');

      // Extract puzzle and solution as List<List<int>>
      final puzzle = rawPuzzleData['puzzle'] as List<List<int>>;
      final solution = rawPuzzleData['solution'] as List<List<int>>;

      // Flatten to 1D arrays for Firestore (avoid nested arrays)
      final puzzleFlat = puzzle.expand((row) => row).toList();
      final solutionFlat = solution.expand((row) => row).toList();

      final firestorePuzzle = <String, dynamic>{
        'puzzleFlat': puzzleFlat,     // Flattened 1D array (81 elements)
        'solutionFlat': solutionFlat, // Flattened 1D array (81 elements)
        'difficulty': difficulty,
        'id': 'puzzle_${DateTime.now().millisecondsSinceEpoch}',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'puzzleRows': 9,
        'puzzleCols': 9,
      };

      print('✅ Puzzle prepared for Firestore storage');
      print('Puzzle flattened: ${puzzleFlat.length} elements');
      print('Solution flattened: ${solutionFlat.length} elements');

      return firestorePuzzle;

    } catch (e) {
      print('❌ Error generating puzzle with SudokuEngine: $e');
      print('Falling back to deterministic puzzle');
      return _createDeterministicPuzzle(difficulty);
    }
  }

  // Fallback deterministic puzzle if SudokuEngine fails
  static Map<String, dynamic> _createDeterministicPuzzle(String difficulty) {
    print('🔄 Creating deterministic fallback puzzle');

    final basePuzzle = [
      [5, 3, 0, 0, 7, 0, 0, 0, 0],
      [6, 0, 0, 1, 9, 5, 0, 0, 0],
      [0, 9, 8, 0, 0, 0, 0, 6, 0],
      [8, 0, 0, 0, 6, 0, 0, 0, 3],
      [4, 0, 0, 8, 0, 3, 0, 0, 1],
      [7, 0, 0, 0, 2, 0, 0, 0, 6],
      [0, 6, 0, 0, 0, 0, 2, 8, 0],
      [0, 0, 0, 4, 1, 9, 0, 0, 5],
      [0, 0, 0, 0, 8, 0, 0, 7, 9]
    ];

    final solution = [
      [5, 3, 4, 6, 7, 8, 9, 1, 2],
      [6, 7, 2, 1, 9, 5, 3, 4, 8],
      [1, 9, 8, 3, 4, 2, 5, 6, 7],
      [8, 5, 9, 7, 6, 1, 4, 2, 3],
      [4, 2, 6, 8, 5, 3, 7, 9, 1],
      [7, 1, 3, 9, 2, 4, 8, 5, 6],
      [9, 6, 1, 5, 3, 7, 2, 8, 4],
      [2, 8, 7, 4, 1, 9, 6, 3, 5],
      [3, 4, 5, 2, 8, 6, 1, 7, 9]
    ];

    // Flatten for Firestore storage
    final puzzleFlat = basePuzzle.expand((row) => row).toList();
    final solutionFlat = solution.expand((row) => row).toList();

    return {
      'puzzleFlat': puzzleFlat,
      'solutionFlat': solutionFlat,
      'difficulty': difficulty,
      'id': 'fallback_${DateTime.now().millisecondsSinceEpoch}',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'puzzleRows': 9,
      'puzzleCols': 9,
    };
  }

  // Join a public lobby
  static Future<void> joinPublicLobby(String lobbyId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userData = await getUserData(user.uid);

    await _firestore.runTransaction((transaction) async {
      final lobbyRef = _firestore.collection(_lobbiesCollection).doc(lobbyId);
      final lobbyDoc = await transaction.get(lobbyRef);

      if (!lobbyDoc.exists) {
        throw Exception('Lobby not found');
      }

      final lobby = Lobby.fromFirestore(lobbyDoc);

      if (lobby.status != LobbyStatus.waiting) {
        throw Exception('Game already started');
      }

      if (lobby.currentPlayers >= lobby.maxPlayers) {
        throw Exception('Lobby is full');
      }

      if (lobby.playersList.any((player) => player.id == user.uid)) {
        throw Exception('Already in lobby');
      }

      final newPlayer = Player(
        id: user.uid,
        name: userData['name'] ?? user.displayName ?? 'Unknown',
        avatarUrl: userData['avatarUrl'] ?? user.photoURL,
        rating: userData['rating'] ?? 1000,
        joinedAt: DateTime.now(),
      );

      transaction.update(lobbyRef, {
        'currentPlayers': lobby.currentPlayers + 1,
        'playersList': [
          ...lobby.playersList.map((p) => p.toMap()),
          newPlayer.toMap(),
        ],
      });
    });
  }

  // Join a private lobby with access code
  static Future<String> joinPrivateLobby(String accessCode) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    print('🔐 LobbyService: Searching for lobby with access code: $accessCode');

    final querySnapshot = await _firestore
        .collection(_lobbiesCollection)
        .where('accessCode', isEqualTo: accessCode)
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    print('Query returned ${querySnapshot.docs.length} lobbies');

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Invalid access code or game already started');
    }

    final lobbyDoc = querySnapshot.docs.first;
    print('✅ Found lobby: ${lobbyDoc.id}');

    // Join the public lobby logic (reuse existing logic)
    await joinPublicLobby(lobbyDoc.id);

    print('✅ Successfully joined private lobby: ${lobbyDoc.id}');
    return lobbyDoc.id;
  }

  // Leave a lobby
  static Future<void> leaveLobby(String lobbyId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore.runTransaction((transaction) async {
      final lobbyRef = _firestore.collection(_lobbiesCollection).doc(lobbyId);
      final lobbyDoc = await transaction.get(lobbyRef);

      if (!lobbyDoc.exists) return;

      final lobby = Lobby.fromFirestore(lobbyDoc);

      final updatedPlayersList = lobby.playersList
          .where((player) => player.id != user.uid)
          .toList();

      if (updatedPlayersList.isEmpty) {
        // Delete lobby if no players left
        print('🗑️ Deleting empty lobby: $lobbyId');
        transaction.delete(lobbyRef);

        // Also clean up associated data
        _cleanupLobbyData(lobbyId);
      } else if (updatedPlayersList.length == 1 && lobby.status != LobbyStatus.waiting) {
        // If only 1 player left after a completed game, mark lobby for cleanup
        print('⚠️ Only 1 player left in post-game lobby, marking for cleanup');
        transaction.update(lobbyRef, {
          'currentPlayers': updatedPlayersList.length,
          'playersList': updatedPlayersList.map((p) => p.toMap()).toList(),
          'markedForCleanup': true,
          'cleanupAt': DateTime.now().add(Duration(minutes: 5)).millisecondsSinceEpoch,
        });
      } else if (lobby.hostPlayerId == user.uid) {
        // Transfer host to another player
        final newHost = updatedPlayersList.first;
        transaction.update(lobbyRef, {
          'hostPlayerId': newHost.id,
          'hostPlayerName': newHost.name,
          'currentPlayers': updatedPlayersList.length,
          'playersList': updatedPlayersList.map((p) => p.toMap()).toList(),
        });
      } else {
        // Just remove the player
        transaction.update(lobbyRef, {
          'currentPlayers': updatedPlayersList.length,
          'playersList': updatedPlayersList.map((p) => p.toMap()).toList(),
        });
      }
    });
  }

  // Clean up lobby associated data
  static Future<void> _cleanupLobbyData(String lobbyId) async {
    try {
      final batch = _firestore.batch();

      // Clean up game states
      final gameStates = await _firestore
          .collection(_lobbiesCollection)
          .doc(lobbyId)
          .collection('gameStates')
          .get();

      for (final doc in gameStates.docs) {
        batch.delete(doc.reference);
      }

      // Clean up game results
      final gameResults = await _firestore
          .collection(_lobbiesCollection)
          .doc(lobbyId)
          .collection('gameResults')
          .get();

      for (final doc in gameResults.docs) {
        batch.delete(doc.reference);
      }

      // Clean up messages
      final messages = await _firestore
          .collection(_lobbiesCollection)
          .doc(lobbyId)
          .collection('messages')
          .get();

      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // 🔥 NEW: Clean up powerup data
      await PowerupService.clearLobbyPowerups(lobbyId);

      await batch.commit();
      print('🧹 Cleaned up all data for lobby: $lobbyId');
    } catch (e) {
      print('Error cleaning up lobby data: $e');
    }
  }

  // Get public lobbies stream with cleanup filtering
  static Stream<List<Lobby>> getPublicLobbies() {
    return _firestore
        .collection(_lobbiesCollection)
        .where('isPrivate', isEqualTo: false)
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      // Filter out lobbies marked for cleanup or with insufficient players
      final validLobbies = snapshot.docs
          .where((doc) {
        final lobby = Lobby.fromFirestore(doc);
        final data = doc.data() as Map<String, dynamic>?;

        // Don't show lobbies marked for cleanup
        if (data?['markedForCleanup'] == true) {
          return false;
        }

        // Don't show lobbies with only 1 player after 2 minutes
        if (lobby.currentPlayers == 1) {
          final ageInMinutes = DateTime.now().difference(lobby.createdAt).inMinutes;
          if (ageInMinutes > 2) {
            return false;
          }
        }

        return true;
      })
          .map((doc) => Lobby.fromFirestore(doc))
          .toList();

      return validLobbies;
    });
  }

  // Get specific lobby stream
  static Stream<Lobby?> getLobby(String lobbyId) {
    return _firestore
        .collection(_lobbiesCollection)
        .doc(lobbyId)
        .snapshots()
        .map((doc) => doc.exists ? Lobby.fromFirestore(doc) : null);
  }

  // Start game (host only) - Just change status since puzzle already exists
  static Future<void> startGame(String lobbyId) async {
    print('🎮 LobbyService.startGame called for lobby: $lobbyId');

    final user = _auth.currentUser;
    if (user == null) {
      print('❌ User not authenticated');
      throw Exception('User not authenticated');
    }

    print('✅ User authenticated: ${user.uid}');

    try {
      await _firestore.runTransaction((transaction) async {
        print('🔄 Starting Firestore transaction...');

        final lobbyRef = _firestore.collection(_lobbiesCollection).doc(lobbyId);
        final lobbyDoc = await transaction.get(lobbyRef);

        print('✅ Lobby document found');
        final lobby = Lobby.fromFirestore(lobbyDoc);

        if (lobby.hostPlayerId != user.uid) {
          print('❌ User is not the host');
          throw Exception('Only host can start the game');
        }

        if (lobby.playersList.length < 2) {
          print('❌ Not enough players');
          throw Exception('Need at least 2 players to start');
        }

        // Verify shared puzzle exists
        if (lobby.sharedPuzzle == null || lobby.sharedPuzzle!.isEmpty) {
          print('❌ No shared puzzle found');
          throw Exception('No puzzle available for this lobby');
        }

        print('✅ Shared puzzle verified');
        print('🔄 Updating lobby status to starting...');

        // Clear previous game states before starting new game
        await GameStateService.clearGameStates(lobbyId);

        // Just update status since puzzle already exists
        transaction.update(lobbyRef, {
          'status': 'starting',
          'startedAt': DateTime.now().millisecondsSinceEpoch,
        });

        print('✅ Lobby status updated to starting');
      });

      print('✅ Transaction completed successfully');
    } catch (e) {
      print('❌ Error in startGame: $e');
      rethrow;
    }
  }

  // Reset lobby status after game completion
  static Future<void> resetLobbyForNewGame(String lobbyId) async {
    try {
      await _firestore.collection(_lobbiesCollection).doc(lobbyId).update({
        'status': 'waiting',
        'startedAt': null,
        'gameSessionId': null,
        'gameServerEndpoint': null,
      });

      print('✅ Lobby reset for new game: $lobbyId');
    } catch (e) {
      print('❌ Error resetting lobby: $e');
      rethrow;
    }
  }

  // Get user data with better offline handling
  static Future<Map<String, dynamic>> getUserData(String userId) async {
    try {
      // Try to get from cache first
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get(const GetOptions(source: Source.cache));

      if (userDoc.exists && userDoc.data() != null) {
        return userDoc.data()!;
      }

      // If not in cache, try server
      final serverDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get(const GetOptions(source: Source.server));

      if (serverDoc.exists && serverDoc.data() != null) {
        return serverDoc.data()!;
      } else {
        // Create user document if it doesn't exist
        return await _createDefaultUserData(userId);
      }
    } catch (e) {
      print('Error getting user data: $e');
      // Return default data if all else fails
      final user = _auth.currentUser;
      return {
        'name': user?.displayName ?? 'Player',
        'email': user?.email ?? '',
        'rating': 1000,
        'gamesPlayed': 0,
        'gamesWon': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }

  // Create default user data
  static Future<Map<String, dynamic>> _createDefaultUserData(String userId) async {
    final user = _auth.currentUser;
    final userData = {
      'name': user?.displayName ?? 'Player',
      'email': user?.email ?? '',
      'rating': 1000,
      'gamesPlayed': 0,
      'gamesWon': 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .set(userData);
    } catch (e) {
      print('Failed to create user document: $e');
    }

    return userData;
  }

  // Generate 6-character access code
  static String _generateAccessCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      6,
          (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ));
  }

  // Get lobbies user is currently in
  static Stream<List<Lobby>> getUserLobbies() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection(_lobbiesCollection)
        .where('playersList', arrayContains: {'id': user.uid})
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Lobby.fromFirestore(doc))
        .toList());
  }


  // CO-OP: Method to send a single move to Firebase.
  static Future<void> sendCoOpMove(String lobbyId, int row, int col, int number) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection(_lobbiesCollection)
          .doc(lobbyId)
          .collection(_movesCollection)
          .add({
        'playerId': user.uid,
        'row': row,
        'col': col,
        'number': number,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending co-op move: $e');
      // Handle error appropriately
    }
  }

  // CO-OP: Method to get a stream of moves from Firebase.
  static Stream<Map<String, dynamic>> getCoOpMoves(String lobbyId) {
    return _firestore
        .collection(_lobbiesCollection)
        .doc(lobbyId)
        .collection(_movesCollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .transform(StreamTransformer.fromHandlers(handleData: (snapshot, sink) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          sink.add(change.doc.data() as Map<String, dynamic>);
        }
      }
    }));
  }

  // NEW: Method to increment the shared mistake count using a transaction
  static Future<void> incrementSharedMistakes(String lobbyId) async {
    final lobbyRef = _firestore.collection(_lobbiesCollection).doc(lobbyId);
    try {
      // Use a transaction to prevent race conditions
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(lobbyRef);
        if (!snapshot.exists) throw Exception("Lobby does not exist!");
        final currentMistakes = snapshot.data()?['sharedMistakeCount'] ?? 0;
        transaction.update(lobbyRef, {'sharedMistakeCount': currentMistakes + 1});
      });
    } catch (e) {
      print("Failed to increment shared mistakes: $e");
    }
  }

}


// Helper function to convert string to Difficulty enum
Difficulty _stringToDifficulty(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return Difficulty.easy;
    case 'medium':
      return Difficulty.medium;
    case 'hard':
      return Difficulty.hard;
    case 'expert':
      return Difficulty.expert;
    default:
      return Difficulty.medium; // Default fallback
  }
}