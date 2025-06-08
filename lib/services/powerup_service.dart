// services/powerup_service.dart - FIXED VERSION (One powerup at a time)
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/powerup_model.dart';

class PowerupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'lobbies',
  );
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Random _random = Random();

  // Collection names
  static const String _powerupSpawnsCollection = 'powerupSpawns';
  static const String _playerPowerupsCollection = 'playerPowerups';
  static const String _powerupEffectsCollection = 'powerupEffects';

  // 🔥 FIXED: Updated timing configuration for single powerup spawn
  static const int MIN_POWERUPS_PER_GAME = 1; // Only 1 powerup at a time
  static const int MAX_POWERUPS_PER_GAME = 1; // Only 1 powerup at a time
  static const int MIN_SPAWN_INTERVAL_SECONDS = 45; // Longer intervals between spawns

  /// Initialize improved powerup system for a lobby
  static Future<void> initializePowerups(String lobbyId) async {
    try {
      print('🔮 Initializing powerups for lobby: $lobbyId (one at a time)');

      // Clear any existing powerups
      await clearLobbyPowerups(lobbyId);

      // 🔥 FIXED: Only spawn one powerup at a time
      final spawnTimes = _generateSpawnTimes(1); // Always generate for 1 powerup

      // Store spawn configuration in lobby metadata
      await _firestore.collection('lobbies').doc(lobbyId).update({
        'powerupConfig': {
          'totalPowerups': 1,
          'spawnTimes': spawnTimes,
          'currentSpawnIndex': 0,
          'gameStartTime': DateTime.now().millisecondsSinceEpoch,
          'isActive': true,
          'lastSpawnTime': 0, // Track when last powerup was spawned
        }
      });

      print('✅ Powerups initialized: Single powerup system');
      print('   First spawn time: ${spawnTimes[0]}s');

      // Start the spawn scheduler
      _startSpawnScheduler(lobbyId);

    } catch (e) {
      print('❌ Error initializing powerups: $e');
    }
  }

  /// Generate spawn times with minimum intervals - 🔥 FIXED for single powerup
  static List<int> _generateSpawnTimes(int totalPowerups) {
    final spawnTimes = <int>[];

    // Start first powerup after 45-75 seconds
    int currentTime = 45 + _random.nextInt(31); // 45-75s
    spawnTimes.add(currentTime);

    print('🎯 Generated spawn time: ${currentTime}s');
    return spawnTimes;
  }

  /// Start the spawn scheduler
  static void _startSpawnScheduler(String lobbyId) {
    Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        final shouldContinue = await _checkAndSpawnPowerup(lobbyId);
        if (!shouldContinue) {
          timer.cancel();
          print('🏁 Powerup spawning completed for lobby: $lobbyId');
        }
      } catch (e) {
        print('❌ Error in spawn scheduler: $e');
      }
    });
  }

  // Check if it's time to spawn a powerup and spawn it
  static Future<bool> _checkAndSpawnPowerup(String lobbyId) async {
    try {
      // Get lobby powerup config
      final lobbyDoc = await _firestore.collection('lobbies').doc(lobbyId).get();
      if (!lobbyDoc.exists) return false;

      final data = lobbyDoc.data() as Map<String, dynamic>;
      final powerupConfig = data['powerupConfig'] as Map<String, dynamic>?;

      if (powerupConfig == null || powerupConfig['isActive'] != true) {
        return false;
      }

      // 🔥 FIXED: Check if there's already an active powerup on the board
      final activeSpawns = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection(_powerupSpawnsCollection)
          .where('isActive', isEqualTo: true)
          .get();

      if (activeSpawns.docs.isNotEmpty) {
        print('⏳ Powerup already active on board, waiting...');
        return true; // Continue checking, but don't spawn yet
      }

      final spawnTimes = List<int>.from(powerupConfig['spawnTimes'] ?? []);
      final gameStartTime = powerupConfig['gameStartTime'] ?? 0;
      final lastSpawnTime = powerupConfig['lastSpawnTime'] ?? 0;

      // Calculate elapsed time since game start
      final elapsedSeconds = (DateTime.now().millisecondsSinceEpoch - gameStartTime) ~/ 1000;
      final nextSpawnTime = spawnTimes.isNotEmpty ? spawnTimes[0] : 60;

      // Check if it's time to spawn AND enough time has passed since last spawn
      final timeSinceLastSpawn = (DateTime.now().millisecondsSinceEpoch - lastSpawnTime) ~/ 1000;

      if (elapsedSeconds >= nextSpawnTime && timeSinceLastSpawn >= MIN_SPAWN_INTERVAL_SECONDS) {
        await _spawnRandomPowerup(lobbyId);

        // Update last spawn time and generate next spawn time
        final nextSpawnDelay = MIN_SPAWN_INTERVAL_SECONDS + _random.nextInt(31); // 45-75s
        final newSpawnTime = elapsedSeconds + nextSpawnDelay;

        await _firestore.collection('lobbies').doc(lobbyId).update({
          'powerupConfig.lastSpawnTime': DateTime.now().millisecondsSinceEpoch,
          'powerupConfig.spawnTimes': [newSpawnTime], // Set next spawn time
        });

        print('⏰ Spawned powerup at ${elapsedSeconds}s, next spawn at ${newSpawnTime}s');
        return true;
      }

      return true; // Continue checking
    } catch (e) {
      print('❌ Error checking powerup spawn: $e');
      return false;
    }
  }

  /// Spawn a random powerup at a random empty location
  static Future<void> _spawnRandomPowerup(String lobbyId) async {
    try {
      // Get available empty cells
      final availableCells = await _getAvailableEmptyCells(lobbyId);

      if (availableCells.isEmpty) {
        print('⚠️ No available empty cells for powerup spawn');
        return;
      }

      // Pick random cell and powerup type
      final cell = availableCells[_random.nextInt(availableCells.length)];
      final powerupType = _getRandomPowerupType();

      // Create powerup spawn
      final spawn = PowerupSpawn(
        id: '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}',
        type: powerupType,
        row: cell['row']!,
        col: cell['col']!,
        spawnTime: DateTime.now(),
      );

      // Save to Firestore
      await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection(_powerupSpawnsCollection)
          .doc(spawn.id)
          .set(spawn.toMap());

      print('✨ Spawned ${_getDisplayName(powerupType)} at (${cell['row']}, ${cell['col']})');

    } catch (e) {
      print('❌ Error spawning powerup: $e');
    }
  }

  /// Get available empty cells for powerup spawning (improved)
  static Future<List<Map<String, int>>> _getAvailableEmptyCells(String lobbyId) async {
    try {
      // Get lobby to find shared puzzle
      final lobbyDoc = await _firestore.collection('lobbies').doc(lobbyId).get();
      if (!lobbyDoc.exists) return [];

      final lobbyData = lobbyDoc.data() as Map<String, dynamic>;
      final sharedPuzzle = lobbyData['sharedPuzzle'] as Map<String, dynamic>?;

      if (sharedPuzzle == null) return [];

      // Convert puzzle data
      final puzzleFlat = (sharedPuzzle['puzzleFlat'] as List).cast<int>();
      final availableCells = <Map<String, int>>[];

      // Get all players' current game states to see what they've solved
      final gameStates = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection('gameStates')
          .get();

      // Create a set of solved positions across all players
      final Set<String> solvedPositions = {};

      for (final gameStateDoc in gameStates.docs) {
        // You could add logic here to track solved positions per player
        // For now, we'll just check if the original puzzle cell is empty
      }

      // Find empty cells from the original puzzle (value = 0)
      for (int i = 0; i < puzzleFlat.length; i++) {
        if (puzzleFlat[i] == 0) { // Only empty cells from original puzzle
          final row = i ~/ 9;
          final col = i % 9;
          final positionKey = '$row,$col';

          // Only add if not solved by any player yet
          if (!solvedPositions.contains(positionKey)) {
            availableCells.add({'row': row, 'col': col});
          }
        }
      }

      print('🎯 Found ${availableCells.length} available empty cells for powerup spawn');
      return availableCells;
    } catch (e) {
      print('❌ Error getting available cells: $e');
      return [];
    }
  }

  /// Claim a powerup when player solves the cell
  static Future<bool> claimPowerup(String lobbyId, String spawnId, int row, int col) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      print('🎯 Attempting to claim powerup $spawnId at ($row, $col)');

      return await _firestore.runTransaction((transaction) async {
        // Get powerup spawn
        final spawnRef = _firestore
            .collection('lobbies')
            .doc(lobbyId)
            .collection(_powerupSpawnsCollection)
            .doc(spawnId);

        final spawnDoc = await transaction.get(spawnRef);

        if (!spawnDoc.exists) {
          print('❌ Powerup spawn not found');
          return false;
        }

        final spawn = PowerupSpawn.fromFirestore(spawnDoc);

        // Check if powerup is still available and at correct position
        if (!spawn.isActive || spawn.claimedBy != null) {
          print('❌ Powerup already claimed or inactive');
          return false;
        }

        if (spawn.row != row || spawn.col != col) {
          print('❌ Powerup position mismatch');
          return false;
        }

        // Claim the powerup
        transaction.update(spawnRef, {
          'claimedBy': user.uid,
          'claimedAt': DateTime.now().millisecondsSinceEpoch,
          'isActive': false,
        });

        // Add to player's powerups
        final playerPowerup = PlayerPowerup(
          id: '${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
          type: spawn.type,
          playerId: user.uid,
          obtainedAt: DateTime.now(),
        );

        final playerPowerupRef = _firestore
            .collection('lobbies')
            .doc(lobbyId)
            .collection(_playerPowerupsCollection)
            .doc(playerPowerup.id);

        transaction.set(playerPowerupRef, playerPowerup.toMap());

        print('✅ Successfully claimed ${spawn.type.toString()} powerup');
        return true;
      });

    } catch (e) {
      print('❌ Error claiming powerup: $e');
      return false;
    }
  }

  /// Use a powerup
  static Future<bool> usePowerup(String lobbyId, String powerupId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      return await _firestore.runTransaction((transaction) async {
        // Get player powerup
        final powerupRef = _firestore
            .collection('lobbies')
            .doc(lobbyId)
            .collection(_playerPowerupsCollection)
            .doc(powerupId);

        final powerupDoc = await transaction.get(powerupRef);

        if (!powerupDoc.exists) return false;

        final powerup = PlayerPowerup.fromFirestore(powerupDoc);

        // Verify ownership and usage status
        if (powerup.playerId != user.uid || powerup.isUsed) {
          return false;
        }

        // Mark as used
        transaction.update(powerupRef, {
          'isUsed': true,
          'usedAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Apply powerup effect
        await _applyPowerupEffect(lobbyId, powerup, transaction);

        return true;
      });

    } catch (e) {
      print('❌ Error using powerup: $e');
      return false;
    }
  }

  /// Apply powerup effect
  static Future<void> _applyPowerupEffect(
      String lobbyId,
      PlayerPowerup powerup,
      Transaction transaction
      ) async {
    final now = DateTime.now();

    switch (powerup.type) {
      case PowerupType.freezeOpponent:
      // Find opponent and apply freeze effect
        final opponentId = await _getOpponentId(lobbyId, powerup.playerId);
        if (opponentId != null) {
          final effect = PowerupEffect(
            id: '${powerup.id}_effect',
            type: powerup.type,
            targetPlayerId: opponentId,
            sourcePlayerId: powerup.playerId,
            appliedAt: now,
            expiresAt: now.add(Duration(seconds: 10)),
            data: {'freezeDuration': 10},
          );

          final effectRef = _firestore
              .collection('lobbies')
              .doc(lobbyId)
              .collection(_powerupEffectsCollection)
              .doc(effect.id);

          transaction.set(effectRef, effect.toMap());
        }
        break;

      case PowerupType.showSolution:
      // Apply show solution effect to user
        final effect = PowerupEffect(
          id: '${powerup.id}_effect',
          type: powerup.type,
          targetPlayerId: powerup.playerId,
          sourcePlayerId: powerup.playerId,
          appliedAt: now,
          expiresAt: now.add(Duration(seconds: 3)),
          data: {'showDuration': 3},
        );

        final effectRef = _firestore
            .collection('lobbies')
            .doc(lobbyId)
            .collection(_powerupEffectsCollection)
            .doc(effect.id);

        transaction.set(effectRef, effect.toMap());
        break;

      case PowerupType.bomb:
      // Apply bomb effect to opponent
        final opponentId = await _getOpponentId(lobbyId, powerup.playerId);
        if (opponentId != null) {
          // Get a random 3x3 area to bomb
          final bombArea = _getRandomBombArea();

          final effect = PowerupEffect(
            id: '${powerup.id}_effect',
            type: powerup.type,
            targetPlayerId: opponentId,
            sourcePlayerId: powerup.playerId,
            appliedAt: now,
            data: {
              'bombArea': bombArea,
              'startRow': bombArea['startRow'],
              'startCol': bombArea['startCol'],
            },
          );

          final effectRef = _firestore
              .collection('lobbies')
              .doc(lobbyId)
              .collection(_powerupEffectsCollection)
              .doc(effect.id);

          transaction.set(effectRef, effect.toMap());
        }
        break;

      case PowerupType.shield:
      // Apply shield effect
        final effect = PowerupEffect(
          id: '${powerup.id}_effect',
          type: powerup.type,
          targetPlayerId: powerup.playerId,
          sourcePlayerId: powerup.playerId,
          appliedAt: now,
          data: {'shieldActive': true},
        );

        final effectRef = _firestore
            .collection('lobbies')
            .doc(lobbyId)
            .collection(_powerupEffectsCollection)
            .doc(effect.id);

        transaction.set(effectRef, effect.toMap());
        break;

      default:
      // Immediate effects don't need to be stored
        break;
    }
  }

  /// Get opponent player ID
  static Future<String?> _getOpponentId(String lobbyId, String playerId) async {
    try {
      final lobbyDoc = await _firestore.collection('lobbies').doc(lobbyId).get();
      if (!lobbyDoc.exists) return null;

      final data = lobbyDoc.data() as Map<String, dynamic>;
      final playersList = data['playersList'] as List<dynamic>?;

      if (playersList == null || playersList.length < 2) return null;

      for (final playerData in playersList) {
        final id = playerData['id'] as String;
        if (id != playerId) {
          return id;
        }
      }

      return null;
    } catch (e) {
      print('❌ Error getting opponent ID: $e');
      return null;
    }
  }

  // Re-export existing methods that are still needed
  static Stream<List<PowerupSpawn>> getPowerupSpawns(String lobbyId) {
    return _firestore
        .collection('lobbies')
        .doc(lobbyId)
        .collection(_powerupSpawnsCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => PowerupSpawn.fromFirestore(doc))
        .toList());
  }

  static Stream<List<PlayerPowerup>> getPlayerPowerups(String lobbyId, String playerId) {
    return _firestore
        .collection('lobbies')
        .doc(lobbyId)
        .collection(_playerPowerupsCollection)
        .where('playerId', isEqualTo: playerId)
        .where('isUsed', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => PlayerPowerup.fromFirestore(doc))
        .toList());
  }

  static Stream<List<PowerupEffect>> getPowerupEffects(String lobbyId, String playerId) {
    return _firestore
        .collection('lobbies')
        .doc(lobbyId)
        .collection(_powerupEffectsCollection)
        .where('targetPlayerId', isEqualTo: playerId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => PowerupEffect.fromFirestore(doc))
        .where((effect) => !effect.isExpired)
        .toList());
  }

  /// Clear all powerups for a lobby
  static Future<void> clearLobbyPowerups(String lobbyId) async {
    try {
      final batch = _firestore.batch();

      // Clear spawns
      final spawns = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection(_powerupSpawnsCollection)
          .get();

      for (final doc in spawns.docs) {
        batch.delete(doc.reference);
      }

      // Clear player powerups
      final playerPowerups = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection(_playerPowerupsCollection)
          .get();

      for (final doc in playerPowerups.docs) {
        batch.delete(doc.reference);
      }

      // Clear effects
      final effects = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection(_powerupEffectsCollection)
          .get();

      for (final doc in effects.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('🧹 Cleared all powerups for lobby: $lobbyId');

    } catch (e) {
      print('❌ Error clearing lobby powerups: $e');
    }
  }

  /// Clean up expired effects
  static Future<void> cleanupExpiredEffects(String lobbyId) async {
    try {
      final now = DateTime.now();
      final effects = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection(_powerupEffectsCollection)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      for (final doc in effects.docs) {
        final effect = PowerupEffect.fromFirestore(doc);
        if (effect.isExpired) {
          batch.update(doc.reference, {'isActive': false});
        }
      }

      await batch.commit();
    } catch (e) {
      print('❌ Error cleaning up expired effects: $e');
    }
  }

  /// Mark bomb effect as inactive
  static Future<void> markBombEffectInactive(String lobbyId, String effectId) async {
    try {
      await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection(_powerupEffectsCollection)
          .doc(effectId)
          .update({'isActive': false});
    } catch (e) {
      print('❌ Error marking bomb effect as inactive: $e');
    }
  }

  /// Use shield (remove it when protecting from an attack)
  static Future<void> useShield(String lobbyId, String playerId) async {
    try {
      final effects = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection(_powerupEffectsCollection)
          .where('targetPlayerId', isEqualTo: playerId)
          .where('type', isEqualTo: PowerupType.shield.toString())
          .where('isActive', isEqualTo: true)
          .get();

      if (effects.docs.isNotEmpty) {
        await effects.docs.first.reference.update({'isActive': false});
      }
    } catch (e) {
      print('❌ Error using shield: $e');
    }
  }

  /// Check if player has active shield
  static Future<bool> hasActiveShield(String lobbyId, String playerId) async {
    try {
      final effects = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection(_powerupEffectsCollection)
          .where('targetPlayerId', isEqualTo: playerId)
          .where('type', isEqualTo: PowerupType.shield.toString())
          .where('isActive', isEqualTo: true)
          .get();

      return effects.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking shield: $e');
      return false;
    }
  }

  /// Get random powerup type with weighted probability
  static PowerupType getRandomPowerupType() {
    // Weighted probabilities for different powerup types
    const weights = <PowerupType, int>{
      PowerupType.revealTwoCells: 20,
      PowerupType.extraHints: 15,
      PowerupType.clearMistakes: 15,
      PowerupType.freezeOpponent: 12,
      PowerupType.timeBonus: 10,
      PowerupType.showSolution: 8,
      PowerupType.shield: 10,
      PowerupType.bomb: 10,
    };

    final totalWeight = weights.values.reduce((a, b) => a + b);
    final randomValue = _random.nextInt(totalWeight);

    int currentWeight = 0;
    for (final entry in weights.entries) {
      currentWeight += entry.value;
      if (randomValue < currentWeight) {
        return entry.key;
      }
    }

    return PowerupType.revealTwoCells; // Fallback
  }

  /// Get random 3x3 bomb area
  static Map<String, int> _getRandomBombArea() {
    // Possible 3x3 areas in a 9x9 grid (each 3x3 box)
    final areas = [
      {'startRow': 0, 'startCol': 0}, // Top-left
      {'startRow': 0, 'startCol': 3}, // Top-middle
      {'startRow': 0, 'startCol': 6}, // Top-right
      {'startRow': 3, 'startCol': 0}, // Middle-left
      {'startRow': 3, 'startCol': 3}, // Center
      {'startRow': 3, 'startCol': 6}, // Middle-right
      {'startRow': 6, 'startCol': 0}, // Bottom-left
      {'startRow': 6, 'startCol': 3}, // Bottom-middle
      {'startRow': 6, 'startCol': 6}, // Bottom-right
    ];

    return areas[_random.nextInt(areas.length)];
  }

  /// Get random powerup type with balanced distribution
  static PowerupType _getRandomPowerupType() {
    final types = PowerupType.values;
    return types[_random.nextInt(types.length)];
  }

  /// Get display name for powerup type
  static String _getDisplayName(PowerupType type) {
    switch (type) {
      case PowerupType.revealTwoCells:
        return 'Reveal 2 Cells';
      case PowerupType.freezeOpponent:
        return 'Freeze Opponent';
      case PowerupType.extraHints:
        return 'Extra Hints';
      case PowerupType.clearMistakes:
        return 'Clear Mistakes';
      case PowerupType.timeBonus:
        return 'Time Bonus';
      case PowerupType.showSolution:
        return 'Show Solution';
      case PowerupType.shield:
        return 'Shield';
      case PowerupType.bomb:
        return 'Bomb';
      default:
        return 'Unknown Powerup';
    }
  }
}