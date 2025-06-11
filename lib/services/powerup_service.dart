// services/powerup_service.dart - PLAYER-SPECIFIC SPAWN VERSION
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

  // Pre-generated powerup configuration
  static const int TOTAL_POWERUPS_PER_GAME = 8;
  static const int MIN_SPAWN_INTERVAL_SECONDS = 45;
  static const int MAX_SPAWN_INTERVAL_SECONDS = 90;

  /// 🔥 UPDATED: Initialize powerup system with shared timing but NO locations
  static Future<void> initializePowerups(String lobbyId) async {
    try {
      print('🔮 Initializing player-specific powerup system for lobby: $lobbyId');

      // Clear any existing powerup data
      await clearLobbyPowerups(lobbyId);

      // Generate shared powerup schedule (timing only, no locations)
      await _generateSharedPowerupSchedule(lobbyId);

      print('✅ Player-specific powerup system initialized');

    } catch (e) {
      print('❌ Error initializing powerups: $e');
    }
  }

  /// 🔥 NEW: Generate powerup schedule with timing only (no specific locations)
  static Future<void> _generateSharedPowerupSchedule(String lobbyId) async {
    try {
      // Generate spawn times and types, but NO locations
      int currentTime = MIN_SPAWN_INTERVAL_SECONDS;
      final batch = _firestore.batch();

      for (int i = 0; i < TOTAL_POWERUPS_PER_GAME; i++) {
        final powerupType = _getRandomPowerupType();
        final powerupId = 'powerup_${DateTime.now().millisecondsSinceEpoch}_$i';

        // Create shared spawn document with timing only
        final spawnRef = _firestore
            .collection('lobbies')
            .doc(lobbyId)
            .collection(_powerupSpawnsCollection)
            .doc(powerupId);

        batch.set(spawnRef, {
          'id': powerupId,
          'type': powerupType.toString(),
          'spawnTime': currentTime,
          'isActive': false, // Will become active when spawn time is reached
          'claimedBy': null,
          'claimedAt': null,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          // 🔥 KEY: NO row/col stored - will be calculated locally per player
        });

        print('📍 Scheduled ${powerupType.toString()} for ${currentTime}s (location calculated per player)');

        // Calculate next spawn time
        currentTime += MIN_SPAWN_INTERVAL_SECONDS + _random.nextInt(
            MAX_SPAWN_INTERVAL_SECONDS - MIN_SPAWN_INTERVAL_SECONDS + 1
        );
      }

      await batch.commit();
      print('✅ Created ${TOTAL_POWERUPS_PER_GAME} shared powerup spawns (no fixed locations)');

    } catch (e) {
      print('❌ Error generating shared spawns: $e');
    }
  }

  /// 🔥 SIMPLIFIED: Just activate powerups at the right time (no location assignment)
  static Future<void> checkAndSpawnPowerups(String lobbyId, int gameTimeSeconds) async {
    try {
      print('🔍 Checking powerups at ${gameTimeSeconds}s...');

      // Get all inactive powerups that should be activated
      final inactivePowerups = await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection(_powerupSpawnsCollection)
          .where('isActive', isEqualTo: false)
          .get();

      if (inactivePowerups.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      int activatedCount = 0;

      for (final doc in inactivePowerups.docs) {
        final data = doc.data();
        final spawnTime = data['spawnTime'] as int? ?? 0;

        if (spawnTime <= gameTimeSeconds) {
          // Just activate - location will be calculated locally per player
          batch.update(doc.reference, {
            'isActive': true,
            'activatedAt': DateTime.now().millisecondsSinceEpoch,
          });

          activatedCount++;
          print('✨ Activated ${data['type']} (location calculated per player)');
        }
      }

      if (activatedCount > 0) {
        await batch.commit();
        print('🎯 Activated $activatedCount powerups');
      }

    } catch (e) {
      print('❌ Error checking powerup spawns: $e');
    }
  }

  /// 🔥 NEW: Get powerup spawns with player-specific locations calculated locally
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

  /// 🔥 NEW: Calculate player-specific powerup location locally
  static Map<String, int>? calculatePlayerSpecificLocation(
      String powerupId,
      List<List<int?>> currentBoard, // Player's current board state
      List<List<bool>> givenCells,   // Original given cells
      ) {
    try {
      // Get all empty cells for this specific player
      final emptyCells = <Map<String, int>>[];

      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          // Cell is empty if it's not a given cell AND not solved by player
          if (!givenCells[row][col] && (currentBoard[row][col] == null || currentBoard[row][col] == 0)) {
            emptyCells.add({'row': row, 'col': col});
          }
        }
      }

      if (emptyCells.isEmpty) {
        print('⚠️ No empty cells available for powerup $powerupId');
        return null;
      }

      // Use powerup ID as seed for consistent but unique positioning per player/powerup combo
      final seed = powerupId.hashCode;
      final rng = Random(seed);

      // Shuffle with deterministic seed so same powerupId always gives same result for same board state
      emptyCells.shuffle(rng);

      final selectedLocation = emptyCells.first;

      print('🎯 Calculated location for powerup $powerupId: (${selectedLocation['row']}, ${selectedLocation['col']})');
      return selectedLocation;

    } catch (e) {
      print('❌ Error calculating player-specific location: $e');
      return null;
    }
  }

  /// 🔥 UPDATED: Claim powerup using player-calculated location
  static Future<bool> claimPowerup(String lobbyId, String spawnId, int row, int col) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      print('🎯 Attempting to claim powerup $spawnId at ($row, $col)');

      return await _firestore.runTransaction((transaction) async {
        // Get shared spawn
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

        final spawnData = spawnDoc.data() as Map<String, dynamic>;

        // 🔥 CRITICAL: Check if already claimed (first come, first served)
        if (spawnData['claimedBy'] != null) {
          print('❌ Powerup already claimed by ${spawnData['claimedBy']}');
          return false;
        }

        // Verify spawn is active
        if (spawnData['isActive'] != true) {
          print('❌ Powerup not active');
          return false;
        }

        // 🔥 CLAIM IT: Update spawn to mark as claimed
        transaction.update(spawnRef, {
          'claimedBy': user.uid,
          'claimedAt': DateTime.now().millisecondsSinceEpoch,
          'claimedLocation': {'row': row, 'col': col}, // Store where it was claimed
        });

        // Add to claiming player's powerups
        final powerupType = PowerupType.values.firstWhere(
                (e) => e.toString() == spawnData['type']
        );

        final playerPowerup = PlayerPowerup(
          id: '${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
          type: powerupType,
          playerId: user.uid,
          obtainedAt: DateTime.now(),
        );

        final playerPowerupRef = _firestore
            .collection('lobbies')
            .doc(lobbyId)
            .collection(_playerPowerupsCollection)
            .doc(playerPowerup.id);

        transaction.set(playerPowerupRef, playerPowerup.toMap());

        print('✅ Successfully claimed ${powerupType.toString()} powerup');
        return true;
      });

    } catch (e) {
      print('❌ Error claiming powerup: $e');
      return false;
    }
  }

  // ... REST OF THE METHODS REMAIN THE SAME (usePowerup, effects, etc.)

  static Future<bool> usePowerup(String lobbyId, String powerupId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      return await _firestore.runTransaction((transaction) async {
        final powerupRef = _firestore
            .collection('lobbies')
            .doc(lobbyId)
            .collection(_playerPowerupsCollection)
            .doc(powerupId);

        final powerupDoc = await transaction.get(powerupRef);

        if (!powerupDoc.exists) return false;

        final powerup = PlayerPowerup.fromFirestore(powerupDoc);

        if (powerup.playerId != user.uid || powerup.isUsed) {
          return false;
        }

        transaction.update(powerupRef, {
          'isUsed': true,
          'usedAt': DateTime.now().millisecondsSinceEpoch,
        });

        await _applyPowerupEffect(lobbyId, powerup, transaction);

        return true;
      });

    } catch (e) {
      print('❌ Error using powerup: $e');
      return false;
    }
  }

  static Future<void> _applyPowerupEffect(
      String lobbyId,
      PlayerPowerup powerup,
      Transaction transaction
      ) async {
    final now = DateTime.now();

    switch (powerup.type) {
      case PowerupType.freezeOpponent:
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
        final opponentId = await _getOpponentId(lobbyId, powerup.playerId);
        if (opponentId != null) {
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
        break;
    }
  }

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

  static Future<void> cleanupExpiredEffects(String lobbyId) async {
    try {
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

  static PowerupType getRandomPowerupType() {
    return _getRandomPowerupType();
  }

  static PowerupType _getRandomPowerupType() {
    final types = PowerupType.values;
    return types[_random.nextInt(types.length)];
  }

  static Map<String, int> _getRandomBombArea() {
    final areas = [
      {'startRow': 0, 'startCol': 0},
      {'startRow': 0, 'startCol': 3},
      {'startRow': 0, 'startCol': 6},
      {'startRow': 3, 'startCol': 0},
      {'startRow': 3, 'startCol': 3},
      {'startRow': 3, 'startCol': 6},
      {'startRow': 6, 'startCol': 0},
      {'startRow': 6, 'startCol': 3},
      {'startRow': 6, 'startCol': 6},
    ];

    return areas[_random.nextInt(areas.length)];
  }
}