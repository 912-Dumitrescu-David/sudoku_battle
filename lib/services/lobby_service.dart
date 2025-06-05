import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/lobby_model.dart';

class LobbyService {
  // 🎯 Use your custom "lobbies" database instead of default
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'lobbies', // Your custom database name
  );
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🏷️ COLLECTION NAMES DEFINED HERE
  static const String _lobbiesCollection = 'lobbies';        // ← Lobbies collection
  static const String _usersCollection = 'users';            // ← Users collection
  static const String _gameResultsCollection = 'gameResults'; // ← Game results collection

  // Create a new lobby
  static Future<String> createLobby(LobbyCreationRequest request) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Get user data
      final userData = await getUserData(user.uid);

      final accessCode = request.isPrivate ? _generateAccessCode() : null;

      // Create player object
      final hostPlayer = Player(
        id: user.uid,
        name: userData['name'] ?? user.displayName ?? 'Unknown',
        avatarUrl: userData['avatarUrl'] ?? user.photoURL,
        rating: userData['rating'] ?? 1000,
        joinedAt: DateTime.now(),
      );

      // Create lobby data map directly (avoid using Lobby class for creation)
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
      };

      print('Creating lobby with data: $lobbyData');

      final docRef = await _firestore
          .collection(_lobbiesCollection)
          .add(lobbyData);

      print('Lobby created successfully with ID: ${docRef.id}');
      return docRef.id;

    } catch (e) {
      print('Error creating lobby: $e');
      rethrow;
    }
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
        transaction.delete(lobbyRef);
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

  // Get public lobbies stream (full query with index)
  static Stream<List<Lobby>> getPublicLobbies() {
    return _firestore
        .collection(_lobbiesCollection)
        .where('isPrivate', isEqualTo: false)
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Lobby.fromFirestore(doc))
        .toList());
  }

  // Get specific lobby stream
  static Stream<Lobby?> getLobby(String lobbyId) {
    return _firestore
        .collection(_lobbiesCollection)
        .doc(lobbyId)
        .snapshots()
        .map((doc) => doc.exists ? Lobby.fromFirestore(doc) : null);
  }

  // Start game (host only) - Simple version without storing puzzle in Firestore
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

        if (!lobbyDoc.exists) {
          print('❌ Lobby document not found');
          throw Exception('Lobby not found');
        }

        print('✅ Lobby document found');
        final lobby = Lobby.fromFirestore(lobbyDoc);
        print('Lobby details:');
        print('  - Host: ${lobby.hostPlayerId}');
        print('  - Current user: ${user.uid}');
        print('  - Player count: ${lobby.playersList.length}');
        print('  - Status: ${lobby.status}');

        if (lobby.hostPlayerId != user.uid) {
          print('❌ User is not the host');
          throw Exception('Only host can start the game');
        }

        if (lobby.playersList.length < 2) {
          print('❌ Not enough players');
          throw Exception('Need at least 2 players to start');
        }

        print('🔄 Updating lobby status to starting...');
        // Just update status - no puzzle data to avoid serialization issues
        transaction.update(lobbyRef, {
          'status': 'starting',
          'startedAt': DateTime.now().millisecondsSinceEpoch,
        });

        print('✅ Lobby status updated successfully');
      });

      print('✅ Transaction completed successfully');
    } catch (e) {
      print('❌ Error in startGame: $e');
      rethrow;
    }
  }

  // Generate puzzle for sharing using actual SudokuEngine
  static Map<String, dynamic> _generateSharedPuzzle(String difficulty) {
    try {
      print('🎯 Using fallback puzzle for testing (to avoid serialization issues)');
      // Temporarily use fallback puzzle to test game flow
      return _getFallbackPuzzle();

      /* TODO: Fix SudokuEngine serialization and restore this code:
      // Convert string to Difficulty enum
      Difficulty difficultyEnum;
      switch (difficulty.toLowerCase()) {
        case 'easy':
          difficultyEnum = Difficulty.easy;
          break;
        case 'medium':
          difficultyEnum = Difficulty.medium;
          break;
        case 'hard':
          difficultyEnum = Difficulty.hard;
          break;
        case 'expert':
          difficultyEnum = Difficulty.expert;
          break;
        default:
          difficultyEnum = Difficulty.medium;
      }

      // Use the actual SudokuEngine to generate puzzle
      final puzzleData = SudokuEngine.generatePuzzle(difficultyEnum);

      // Convert to Firestore-compatible format (ensure all data is serializable)
      final firestoreCompatiblePuzzle = {
        'puzzle': _convertToFirestoreList(puzzleData['puzzle']),
        'solution': _convertToFirestoreList(puzzleData['solution']),
        'difficulty': difficulty,
        'id': puzzleData['id']?.toString() ?? _generatePuzzleId(),
        'createdAt': puzzleData['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      };

      print('✅ Generated shared puzzle with difficulty: $difficulty');
      print('Puzzle data keys: ${firestoreCompatiblePuzzle.keys}');
      return firestoreCompatiblePuzzle;
      */

    } catch (e) {
      print('❌ Error generating puzzle: $e');
      // Fallback to a simple puzzle if SudokuEngine fails
      return _getFallbackPuzzle();
    }
  }

  // Simple fallback puzzle (only used if SudokuEngine fails)
  static Map<String, dynamic> _getFallbackPuzzle() {
    return {
      'puzzle': [
        [5, 3, 0, 0, 7, 0, 0, 0, 0],
        [6, 0, 0, 1, 9, 5, 0, 0, 0],
        [0, 9, 8, 0, 0, 0, 0, 6, 0],
        [8, 0, 0, 0, 6, 0, 0, 0, 3],
        [4, 0, 0, 8, 0, 3, 0, 0, 1],
        [7, 0, 0, 0, 2, 0, 0, 0, 6],
        [0, 6, 0, 0, 0, 0, 2, 8, 0],
        [0, 0, 0, 4, 1, 9, 0, 0, 5],
        [0, 0, 0, 0, 8, 0, 0, 7, 9]
      ],
      'solution': [
        [5, 3, 4, 6, 7, 8, 9, 1, 2],
        [6, 7, 2, 1, 9, 5, 3, 4, 8],
        [1, 9, 8, 3, 4, 2, 5, 6, 7],
        [8, 5, 9, 7, 6, 1, 4, 2, 3],
        [4, 2, 6, 8, 5, 3, 7, 9, 1],
        [7, 1, 3, 9, 2, 4, 8, 5, 6],
        [9, 6, 1, 5, 3, 7, 2, 8, 4],
        [2, 8, 7, 4, 1, 9, 6, 3, 5],
        [3, 4, 5, 2, 8, 6, 1, 7, 9]
      ],
      'difficulty': 'medium',
      'id': _generatePuzzleId(),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static String _generatePuzzleId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(1000).toString();
  }

  // Update lobby with game session info
  static Future<void> updateLobbyWithGameSession(
      String lobbyId,
      String gameSessionId,
      String gameServerEndpoint
      ) async {
    await _firestore.collection(_lobbiesCollection).doc(lobbyId).update({
      'status': 'inprogress',
      'gameSessionId': gameSessionId,
      'gameServerEndpoint': gameServerEndpoint,
    });
  }

  // Complete game
  static Future<void> completeGame(String lobbyId) async {
    await _firestore.collection(_lobbiesCollection).doc(lobbyId).update({
      'status': 'completed',
    });
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

  // Clean up old lobbies (call periodically)
  static Future<void> cleanupOldLobbies() async {
    final cutoffTime = DateTime.now().subtract(Duration(hours: 1));

    final oldLobbies = await _firestore
        .collection(_lobbiesCollection)
        .where('createdAt', isLessThan: cutoffTime.millisecondsSinceEpoch)
        .where('status', whereIn: ['waiting', 'starting'])
        .get();

    final batch = _firestore.batch();
    for (final doc in oldLobbies.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
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
}