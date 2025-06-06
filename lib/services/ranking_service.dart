import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/lobby_model.dart';
import '../utils/sudoku_engine.dart';

class RankingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'lobbies',
  );
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ELO calculation constants
  static const double kFactor = 32.0; // Standard K-factor for ELO
  static const int defaultRating = 1000;

  // Queue collection names
  static const String _rankedQueueCollection = 'rankedQueue';
  static const String _usersCollection = 'users';

  /// Calculate new ELO ratings after a match
  static Map<String, int> calculateNewRatings({
    required int winnerRating,
    required int loserRating,
    bool isDraw = false,
  }) {
    // Expected scores
    double expectedWinner = 1 / (1 + pow(10, (loserRating - winnerRating) / 400));
    double expectedLoser = 1 / (1 + pow(10, (winnerRating - loserRating) / 400));

    // Actual scores
    double actualWinner = isDraw ? 0.5 : 1.0;
    double actualLoser = isDraw ? 0.5 : 0.0;

    // New ratings
    int newWinnerRating = (winnerRating + kFactor * (actualWinner - expectedWinner)).round();
    int newLoserRating = (loserRating + kFactor * (actualLoser - expectedLoser)).round();

    // Ensure minimum rating of 100
    newWinnerRating = max(100, newWinnerRating);
    newLoserRating = max(100, newLoserRating);

    return {
      'winner': newWinnerRating,
      'loser': newLoserRating,
    };
  }

  /// Update player ratings after a match
  static Future<void> updatePlayerRatings({
    required String winnerId,
    required String loserId,
    required int winnerOldRating,
    required int loserOldRating,
    bool isDraw = false,
  }) async {
    try {
      final newRatings = calculateNewRatings(
        winnerRating: winnerOldRating,
        loserRating: loserOldRating,
        isDraw: isDraw,
      );

      final batch = _firestore.batch();

      // Update winner's rating
      final winnerRef = _firestore.collection(_usersCollection).doc(winnerId);
      batch.update(winnerRef, {
        'rating': newRatings['winner'],
        'gamesPlayed': FieldValue.increment(1),
        'gamesWon': isDraw ? FieldValue.increment(0) : FieldValue.increment(1),
        'lastMatchAt': FieldValue.serverTimestamp(),
      });

      // Update loser's rating
      final loserRef = _firestore.collection(_usersCollection).doc(loserId);
      batch.update(loserRef, {
        'rating': newRatings['loser'],
        'gamesPlayed': FieldValue.increment(1),
        'gamesWon': FieldValue.increment(0),
        'lastMatchAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      print('✅ Updated ratings: Winner ${winnerOldRating} → ${newRatings['winner']}, Loser ${loserOldRating} → ${newRatings['loser']}');
    } catch (e) {
      print('❌ Error updating player ratings: $e');
      rethrow;
    }
  }

  /// Join the ranked queue
  static Future<void> joinRankedQueue() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Get user data including current rating
      final userDoc = await _firestore.collection(_usersCollection).doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final currentRating = userData['rating'] ?? defaultRating;

      // Add to ranked queue
      await _firestore.collection(_rankedQueueCollection).doc(user.uid).set({
        'playerId': user.uid,
        'playerName': user.displayName ?? 'Player',
        'rating': currentRating,
        'avatarUrl': user.photoURL,
        'joinedQueueAt': FieldValue.serverTimestamp(),
        'localJoinedAt': DateTime.now().millisecondsSinceEpoch,
        'searchRadius': 100, // Initial search radius (ELO points)
        'isMatched': false,
        'matchedWith': null,
      });

      print('🎯 Joined ranked queue with rating: $currentRating');
    } catch (e) {
      print('❌ Error joining ranked queue: $e');
      rethrow;
    }
  }

  /// Leave the ranked queue
  static Future<void> leaveRankedQueue() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection(_rankedQueueCollection).doc(user.uid).delete();
      print('🚪 Left ranked queue');
    } catch (e) {
      print('❌ Error leaving ranked queue: $e');
    }
  }

  /// Listen to queue status for current user
  static Stream<QueueStatus?> getQueueStatus() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection(_rankedQueueCollection)
        .doc(user.uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return QueueStatus.fromFirestore(doc);
    });
  }

  /// Find and create a ranked match
  static Future<String?> findRankedMatch(String playerId) async {
    try {
      print('🔍 Finding match for player: $playerId');

      // Get current player's queue entry
      final playerDoc = await _firestore.collection(_rankedQueueCollection).doc(playerId).get();
      if (!playerDoc.exists) {
        print('❌ Player not in queue');
        return null;
      }

      final playerData = playerDoc.data()!;
      final playerRating = playerData['rating'] as int;
      final searchRadius = playerData['searchRadius'] as int;

      print('🔍 Player rating: $playerRating, search radius: $searchRadius');

      // Find potential opponents within search radius
      final minRating = playerRating - searchRadius;
      final maxRating = playerRating + searchRadius;

      print('🔍 Searching for opponents with rating between $minRating and $maxRating');

      // Get all unmatched players in queue
      final allPlayersQuery = await _firestore
          .collection(_rankedQueueCollection)
          .where('isMatched', isEqualTo: false)
          .get();

      print('📊 Found ${allPlayersQuery.docs.length} unmatched players in queue');

      // Filter by rating range and exclude self
      final potentialOpponents = allPlayersQuery.docs
          .where((doc) {
        if (doc.id == playerId) return false; // Exclude self

        final opponentRating = doc.data()['rating'] as int;
        final inRange = opponentRating >= minRating && opponentRating <= maxRating;

        print('  👤 ${doc.data()['playerName']} (${doc.id}) - Rating: $opponentRating, InRange: $inRange');
        return inRange;
      })
          .toList();

      print('🎯 Found ${potentialOpponents.length} potential opponents');

      if (potentialOpponents.isEmpty) {
        print('⏰ No opponents found, expanding search radius');

        // Expand search radius for next time
        final newRadius = min(searchRadius + 50, 500);
        await _firestore.collection(_rankedQueueCollection).doc(playerId).update({
          'searchRadius': newRadius,
        });
        print('📈 Search radius expanded to: $newRadius');
        return null;
      }

      // Find the closest rating match
      potentialOpponents.sort((a, b) {
        final aRating = a.data()['rating'] as int;
        final bRating = b.data()['rating'] as int;
        final aDiff = (aRating - playerRating).abs();
        final bDiff = (bRating - playerRating).abs();
        return aDiff.compareTo(bDiff);
      });

      final opponentDoc = potentialOpponents.first;
      final opponentId = opponentDoc.id;
      final opponentData = opponentDoc.data();

      print('🎯 Best match found!');
      print('  Player: ${playerData['playerName']} (${playerData['rating']})');
      print('  Opponent: ${opponentData['playerName']} (${opponentData['rating']})');

      // Use transaction to prevent race conditions
      String? lobbyId;

      await _firestore.runTransaction((transaction) async {
        // Re-check that both players are still available
        final playerCheck = await transaction.get(_firestore.collection(_rankedQueueCollection).doc(playerId));
        final opponentCheck = await transaction.get(_firestore.collection(_rankedQueueCollection).doc(opponentId));

        if (!playerCheck.exists || !opponentCheck.exists) {
          throw Exception('One of the players left the queue');
        }

        final playerCheckData = playerCheck.data()!;
        final opponentCheckData = opponentCheck.data()!;

        if (playerCheckData['isMatched'] == true || opponentCheckData['isMatched'] == true) {
          throw Exception('One of the players is already matched');
        }

        // Create the lobby first
        lobbyId = await _createRankedLobby(playerCheckData, opponentCheckData);

        // Mark both players as matched
        transaction.update(_firestore.collection(_rankedQueueCollection).doc(playerId), {
          'isMatched': true,
          'matchedWith': opponentId,
          'lobbyId': lobbyId,
          'matchedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(_firestore.collection(_rankedQueueCollection).doc(opponentId), {
          'isMatched': true,
          'matchedWith': playerId,
          'lobbyId': lobbyId,
          'matchedAt': FieldValue.serverTimestamp(),
        });
      });

      print('✅ Match created successfully! Lobby ID: $lobbyId');

      // Clean up queue entries after a delay
      Future.delayed(Duration(seconds: 10), () async {
        try {
          final batch = _firestore.batch();
          batch.delete(_firestore.collection(_rankedQueueCollection).doc(playerId));
          batch.delete(_firestore.collection(_rankedQueueCollection).doc(opponentId));
          await batch.commit();
          print('🧹 Cleaned up queue entries');
        } catch (e) {
          print('⚠️ Warning: Failed to clean up queue entries: $e');
        }
      });

      return lobbyId;

    } catch (e) {
      print('❌ Error finding ranked match: $e');
      return null;
    }
  }

  /// Create a ranked lobby for matched players
  static Future<String> _createRankedLobby(
      Map<String, dynamic> player1Data,
      Map<String, dynamic> player2Data) async {
    try {
      print('🏆 Creating ranked lobby...');

      // Generate puzzle for ranked match using SudokuEngine
      final sharedPuzzle = _generateRankedPuzzle();

      // Create players
      final player1 = Player(
        id: player1Data['playerId'],
        name: player1Data['playerName'],
        avatarUrl: player1Data['avatarUrl'],
        rating: player1Data['rating'],
        joinedAt: DateTime.now(),
      );

      final player2 = Player(
        id: player2Data['playerId'],
        name: player2Data['playerName'],
        avatarUrl: player2Data['avatarUrl'],
        rating: player2Data['rating'],
        joinedAt: DateTime.now(),
      );

      print('👥 Player 1: ${player1.name} (${player1.rating})');
      print('👥 Player 2: ${player2.name} (${player2.rating})');

      // Ranked game settings (standardized)
      final gameSettings = GameSettings(
        timeLimit: 600, // 10 minutes
        allowHints: false, // No hints in ranked
        allowMistakes: true,
        maxMistakes: 3,
        difficulty: 'medium',
      );

      // Create lobby data - MAKE SURE isRanked is set!
      final lobbyData = {
        'hostPlayerId': player1.id,
        'hostPlayerName': player1.name,
        'gameMode': 'classic',
        'isPrivate': true, // Ranked matches are private
        'accessCode': null,
        'maxPlayers': 2,
        'currentPlayers': 2,
        'playersList': [player1.toMap(), player2.toMap()],
        'gameSettings': gameSettings.toMap(),
        'status': 'waiting',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'startedAt': null,
        'gameSessionId': null,
        'gameServerEndpoint': null,
        'sharedPuzzle': sharedPuzzle,
        'isRanked': true, // ⭐ CRITICAL: Mark as ranked match
        'averageRating': ((player1.rating + player2.rating) / 2).round(),
        'rankedMatchId': 'ranked_${DateTime.now().millisecondsSinceEpoch}', // Extra identifier
      };

      print('💾 Creating lobby with isRanked: true');

      final docRef = await _firestore.collection('lobbies').add(lobbyData);

      print('✅ Ranked lobby created: ${docRef.id}');
      print('🔍 Verifying lobby creation...');

      // Verify the lobby was created correctly
      final createdLobby = await docRef.get();
      final createdData = createdLobby.data() as Map<String, dynamic>;
      print('✅ Verification - isRanked: ${createdData['isRanked']}');

      return docRef.id;
    } catch (e) {
      print('❌ Error creating ranked lobby: $e');
      rethrow;
    }
  }

  /// Generate puzzle for ranked matches using SudokuEngine
  static Map<String, dynamic> _generateRankedPuzzle() {
    try {
      print('🎲 Generating random ranked puzzle using SudokuEngine...');

      // Generate a medium difficulty puzzle for ranked matches
      final puzzleData = SudokuEngine.generatePuzzle(Difficulty.medium);

      print('✅ SudokuEngine puzzle generated');
      print('Puzzle ID: ${puzzleData['id']}');
      print('Difficulty: ${puzzleData['difficulty']}');

      // Extract puzzle and solution as List<List<int>>
      final puzzle = puzzleData['puzzle'] as List<List<int>>;
      final solution = puzzleData['solution'] as List<List<int>>;

      // Flatten to 1D arrays for Firestore (avoid nested arrays)
      final puzzleFlat = puzzle.expand((row) => row).toList();
      final solutionFlat = solution.expand((row) => row).toList();

      // Count empty cells for verification
      final emptyCells = puzzleFlat.where((cell) => cell == 0).length;
      print('📊 Generated puzzle stats:');
      print('  Empty cells: $emptyCells');
      print('  Puzzle sample: ${puzzle[0].sublist(0, 5)}...');

      final firestorePuzzle = <String, dynamic>{
        'puzzleFlat': puzzleFlat,     // Flattened 1D array (81 elements)
        'solutionFlat': solutionFlat, // Flattened 1D array (81 elements)
        'difficulty': 'medium',       // Always medium for ranked
        'id': puzzleData['id'],       // Use the same ID format as SudokuEngine
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'puzzleRows': 9,
        'puzzleCols': 9,
        'emptyCells': emptyCells,
        'generatedBy': 'SudokuEngine',
        'isRanked': true,
      };

      print('✅ Ranked puzzle prepared for Firestore');
      print('Final puzzle ID: ${firestorePuzzle['id']}');

      return firestorePuzzle;

    } catch (e) {
      print('❌ Error generating puzzle with SudokuEngine: $e');
      print('🔄 Falling back to deterministic puzzle');
      return _createFallbackRankedPuzzle();
    }
  }

  /// Fallback deterministic puzzle if SudokuEngine fails (different from lobby service)
  static Map<String, dynamic> _createFallbackRankedPuzzle() {
    print('🔄 Creating fallback ranked puzzle');

    // Use a different base puzzle than the regular lobby service
    final basePuzzle = [
      [0, 2, 0, 6, 0, 8, 0, 0, 0],
      [5, 8, 0, 0, 0, 9, 7, 0, 0],
      [0, 0, 0, 0, 4, 0, 0, 0, 0],
      [3, 7, 0, 0, 0, 0, 5, 0, 0],
      [6, 0, 0, 0, 0, 0, 0, 0, 4],
      [0, 0, 8, 0, 0, 0, 0, 1, 3],
      [0, 0, 0, 0, 2, 0, 0, 0, 0],
      [0, 0, 9, 8, 0, 0, 0, 3, 6],
      [0, 0, 0, 3, 0, 6, 0, 9, 0]
    ];

    final solution = [
      [1, 2, 3, 6, 7, 8, 9, 4, 5],
      [5, 8, 4, 2, 3, 9, 7, 6, 1],
      [9, 6, 7, 1, 4, 5, 3, 2, 8],
      [3, 7, 2, 4, 6, 1, 5, 8, 9],
      [6, 9, 1, 5, 8, 3, 2, 7, 4],
      [4, 5, 8, 7, 9, 2, 6, 1, 3],
      [8, 3, 6, 9, 2, 4, 1, 5, 7],
      [2, 1, 9, 8, 5, 7, 4, 3, 6],
      [7, 4, 5, 3, 1, 6, 8, 9, 2]
    ];

    // Flatten for Firestore storage
    final puzzleFlat = basePuzzle.expand((row) => row).toList();
    final solutionFlat = solution.expand((row) => row).toList();
    final emptyCells = puzzleFlat.where((cell) => cell == 0).length;

    return {
      'puzzleFlat': puzzleFlat,
      'solutionFlat': solutionFlat,
      'difficulty': 'medium',
      'id': 'puzzle_${DateTime.now().millisecondsSinceEpoch}', // Use standard format
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'puzzleRows': 9,
      'puzzleCols': 9,
      'emptyCells': emptyCells,
      'generatedBy': 'Fallback',
      'isRanked': true,
    };
  }

  /// Get leaderboard
  static Future<List<PlayerRank>> getLeaderboard({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .where('rating', isGreaterThan: 0) // Show all users with ratings
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.asMap().entries.map((entry) {
        final index = entry.key;
        final doc = entry.value;
        return PlayerRank.fromFirestore(doc, index + 1);
      }).toList();
    } catch (e) {
      print('❌ Error getting leaderboard: $e');
      return [];
    }
  }

  /// Get player's rank
  static Future<PlayerRank?> getPlayerRank(String playerId) async {
    try {
      final userDoc = await _firestore.collection(_usersCollection).doc(playerId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      final playerRating = userData['rating'] ?? defaultRating;

      // Count players with higher rating
      final higherRatedCount = await _firestore
          .collection(_usersCollection)
          .where('rating', isGreaterThan: playerRating)
          .where('gamesPlayed', isGreaterThan: 0)
          .count()
          .get();

      final rank = higherRatedCount.count! + 1;
      return PlayerRank.fromFirestore(userDoc, rank);
    } catch (e) {
      print('❌ Error getting player rank: $e');
      return null;
    }
  }
}

// Data models for queue and ranking
class QueueStatus {
  final String playerId;
  final String playerName;
  final int rating;
  final DateTime joinedAt;
  final int searchRadius;
  final bool isMatched;
  final String? matchedWith;
  final String? lobbyId;

  QueueStatus({
    required this.playerId,
    required this.playerName,
    required this.rating,
    required this.joinedAt,
    required this.searchRadius,
    required this.isMatched,
    this.matchedWith,
    this.lobbyId,
  });

  factory QueueStatus.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle timestamp conversion
    DateTime joinedAt = DateTime.now();
    if (data['joinedQueueAt'] != null) {
      if (data['joinedQueueAt'] is Timestamp) {
        joinedAt = (data['joinedQueueAt'] as Timestamp).toDate();
      } else if (data['localJoinedAt'] != null) {
        joinedAt = DateTime.fromMillisecondsSinceEpoch(data['localJoinedAt']);
      }
    }

    return QueueStatus(
      playerId: data['playerId'] ?? '',
      playerName: data['playerName'] ?? 'Player',
      rating: data['rating'] ?? 1000,
      joinedAt: joinedAt,
      searchRadius: data['searchRadius'] ?? 100,
      isMatched: data['isMatched'] ?? false,
      matchedWith: data['matchedWith'],
      lobbyId: data['lobbyId'],
    );
  }
}

class PlayerRank {
  final String playerId;
  final String playerName;
  final String? avatarUrl;
  final int rating;
  final int gamesPlayed;
  final int gamesWon;
  final int rank;
  final double winRate;

  PlayerRank({
    required this.playerId,
    required this.playerName,
    this.avatarUrl,
    required this.rating,
    required this.gamesPlayed,
    required this.gamesWon,
    required this.rank,
    required this.winRate,
  });

  factory PlayerRank.fromFirestore(DocumentSnapshot doc, int rank) {
    final data = doc.data() as Map<String, dynamic>;
    final gamesPlayed = data['gamesPlayed'] ?? 0;
    final gamesWon = data['gamesWon'] ?? 0;
    final winRate = gamesPlayed > 0 ? (gamesWon / gamesPlayed) * 100 : 0.0;

    return PlayerRank(
      playerId: doc.id,
      playerName: data['name'] ?? data['username'] ?? 'Player',
      avatarUrl: data['avatarUrl'] ?? data['photoURL'],
      rating: data['rating'] ?? 1000,
      gamesPlayed: gamesPlayed,
      gamesWon: gamesWon,
      rank: rank,
      winRate: winRate,
    );
  }

  String get rankDisplay {
    if (rank <= 3) {
      return ['🥇', '🥈', '🥉'][rank - 1];
    }
    return '#$rank';
  }
}