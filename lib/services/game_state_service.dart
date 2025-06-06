import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class GameStateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'lobbies',
  );
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Update player's game status in the lobby
  static Future<void> updatePlayerGameStatus(
      String lobbyId, {
        required bool isCompleted,
        required String completionTime,
        required int solvedCells,
        required int totalCells,
        required int mistakes,
      }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final data = {
        'playerId': user.uid,
        'playerName': user.displayName ?? 'Player',
        'isCompleted': isCompleted,
        'completionTime': completionTime,
        'solvedCells': solvedCells,
        'totalCells': totalCells,
        'mistakes': mistakes,
        'progress': solvedCells / totalCells,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add completion timestamp when finishing
      if (isCompleted) {
        data['finishedAt'] = FieldValue.serverTimestamp();
        data['localFinishedAt'] = DateTime.now().millisecondsSinceEpoch; // Fallback

        // Also try to claim first place in a separate atomic operation
        await _tryClaimFirstPlace(lobbyId, user.uid, user.displayName ?? 'Player');
      }

      await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection('gameStates')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));

      print('✅ Updated game status for ${user.displayName}: completed=$isCompleted');
    } catch (e) {
      print('Error updating game status: $e');
    }
  }

  // Try to atomically claim first place
  static Future<void> _tryClaimFirstPlace(String lobbyId, String playerId, String playerName) async {
    try {
      final firstPlaceRef = _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection('gameResults')
          .doc('firstPlace');

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(firstPlaceRef);

        if (!doc.exists) {
          // No one has claimed first place yet, claim it!
          transaction.set(firstPlaceRef, {
            'playerId': playerId,
            'playerName': playerName,
            'claimedAt': FieldValue.serverTimestamp(),
            'localClaimedAt': DateTime.now().millisecondsSinceEpoch,
          });
          print('🥇 ${playerName} claimed FIRST PLACE!');
        } else {
          print('🥈 ${playerName} finished SECOND - first place already taken by ${doc.data()?['playerName']}');
        }
      });
    } catch (e) {
      print('Error claiming first place: $e');
    }
  }

  // Get all players' game states for a lobby
  static Stream<List<PlayerGameState>> getGameStates(String lobbyId) {
    return _firestore
        .collection('lobbies')
        .doc(lobbyId)
        .collection('gameStates')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => PlayerGameState.fromFirestore(doc))
        .toList());
  }

  // Check if a specific player has completed the game
  static Future<PlayerGameState?> getPlayerGameState(
      String lobbyId, String playerId) async {
    try {
      final doc = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection('gameStates')
          .doc(playerId)
          .get();

      if (doc.exists) {
        return PlayerGameState.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting player game state: $e');
    }
    return null;
  }

  // Get the winner and check if current player was first (using atomic first place claim)
  static Future<Map<String, dynamic>> getGameResult(String lobbyId, String currentPlayerId) async {
    try {
      print('🔍 Getting game result for lobby: $lobbyId, player: $currentPlayerId');

      // Check who claimed first place atomically
      final firstPlaceDoc = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection('gameResults')
          .doc('firstPlace')
          .get();

      if (!firstPlaceDoc.exists) {
        print('⚠️ No first place claimed yet, defaulting to first place');
        return {'isFirstPlace': true, 'winnerName': null, 'totalFinished': 0};
      }

      final firstPlaceData = firstPlaceDoc.data()!;
      final winnerId = firstPlaceData['playerId'];
      final winnerName = firstPlaceData['playerName'];
      final isFirstPlace = winnerId == currentPlayerId;

      print('🥇 First place winner: $winnerName ($winnerId)');
      print('🎯 Current player ($currentPlayerId) is first place: $isFirstPlace');

      // Count total finished players
      final gameStates = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection('gameStates')
          .where('isCompleted', isEqualTo: true)
          .get();

      return {
        'isFirstPlace': isFirstPlace,
        'winnerName': winnerName,
        'totalFinished': gameStates.docs.length,
      };
    } catch (e) {
      print('❌ Error getting game result: $e');
      return {'isFirstPlace': true, 'winnerName': null, 'totalFinished': 0};
    }
  }

  // Get the winner of the game (first to complete)
  static Future<PlayerGameState?> getWinner(String lobbyId) async {
    try {
      final snapshot = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection('gameStates')
          .where('isCompleted', isEqualTo: true)
          .orderBy('finishedAt')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return PlayerGameState.fromFirestore(snapshot.docs.first);
      }
    } catch (e) {
      print('Error getting winner: $e');
    }
    return null;
  }

  // Clear game states when starting a new game
  static Future<void> clearGameStates(String lobbyId) async {
    try {
      // Clear game states
      final gameStates = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection('gameStates')
          .get();

      // Clear game results (first place claims)
      final gameResults = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection('gameResults')
          .get();

      final batch = _firestore.batch();

      // Delete all game states
      for (final doc in gameStates.docs) {
        batch.delete(doc.reference);
      }

      // Delete all game results
      for (final doc in gameResults.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('🧹 Cleared game states and results for lobby: $lobbyId');
    } catch (e) {
      print('Error clearing game states: $e');
    }
  }

  // Send a game event (like move updates, power-ups, etc.)
  static Future<void> sendGameEvent(
      String lobbyId, {
        required String eventType,
        required Map<String, dynamic> data,
      }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection('gameEvents')
          .add({
        'playerId': user.uid,
        'playerName': user.displayName ?? 'Player',
        'eventType': eventType,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error sending game event: $e');
    }
  }

  // Listen to game events
  static Stream<List<GameEvent>> getGameEvents(String lobbyId) {
    return _firestore
        .collection('lobbies')
        .doc(lobbyId)
        .collection('gameEvents')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => GameEvent.fromFirestore(doc))
        .toList());
  }
}

class PlayerGameState {
  final String playerId;
  final String playerName;
  final bool isCompleted;
  final String completionTime;
  final int solvedCells;
  final int totalCells;
  final int mistakes;
  final int finishedAt;
  final double progress;

  PlayerGameState({
    required this.playerId,
    required this.playerName,
    required this.isCompleted,
    required this.completionTime,
    required this.solvedCells,
    required this.totalCells,
    required this.mistakes,
    required this.finishedAt,
    required this.progress,
  });

  factory PlayerGameState.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle server timestamp conversion
    int finishedAtValue = 0;
    if (data['finishedAt'] != null) {
      if (data['finishedAt'] is Timestamp) {
        finishedAtValue = (data['finishedAt'] as Timestamp).millisecondsSinceEpoch;
      } else if (data['finishedAt'] is int) {
        finishedAtValue = data['finishedAt'];
      } else if (data['localFinishedAt'] != null) {
        finishedAtValue = data['localFinishedAt'];
      }
    }

    return PlayerGameState(
      playerId: data['playerId'] ?? '',
      playerName: data['playerName'] ?? 'Player',
      isCompleted: data['isCompleted'] ?? false,
      completionTime: data['completionTime'] ?? '00:00',
      solvedCells: data['solvedCells'] ?? 0,
      totalCells: data['totalCells'] ?? 81,
      mistakes: data['mistakes'] ?? 0,
      finishedAt: finishedAtValue,
      progress: (data['progress'] ?? 0.0).toDouble(),
    );
  }
}

class GameEvent {
  final String playerId;
  final String playerName;
  final String eventType;
  final Map<String, dynamic> data;
  final int timestamp;

  GameEvent({
    required this.playerId,
    required this.playerName,
    required this.eventType,
    required this.data,
    required this.timestamp,
  });

  factory GameEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GameEvent(
      playerId: data['playerId'] ?? '',
      playerName: data['playerName'] ?? 'Player',
      eventType: data['eventType'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      timestamp: data['timestamp'] ?? 0,
    );
  }
}