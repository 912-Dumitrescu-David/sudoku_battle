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

  static const String _powerupSpawnsCollection = 'powerupSpawns';
  static const String _playerPowerupsCollection = 'playerPowerups';
  static const String _powerupEffectsCollection = 'powerupEffects';

  static const int TOTAL_POWERUPS_PER_GAME = 30;
  static const int MIN_SPAWN_INTERVAL_SECONDS = 15;
  static const int MAX_SPAWN_INTERVAL_SECONDS = 25;

  static Future<void> initializePowerups(String lobbyId) async {
    try {
      print('🔮 Initializing player-specific powerup system for lobby: $lobbyId');
      await clearLobbyPowerups(lobbyId);
      await _generateSharedPowerupSchedule(lobbyId);
      print('✅ Player-specific powerup system initialized');
    } catch (e) {
      print('❌ Error initializing powerups: $e');
    }
  }

  static Future<void> _generateSharedPowerupSchedule(String lobbyId) async {
    try {
      int currentTime = MIN_SPAWN_INTERVAL_SECONDS;
      final batch = _firestore.batch();
      for (int i = 0; i < TOTAL_POWERUPS_PER_GAME; i++) {
        final powerupType = _getRandomPowerupType(); // This now uses the skewed logic
        final powerupId = 'powerup_${DateTime.now().millisecondsSinceEpoch}_$i';
        final spawnRef = _firestore.collection('lobbies').doc(lobbyId).collection(_powerupSpawnsCollection).doc(powerupId);
        batch.set(spawnRef, {
          'id': powerupId,
          'type': powerupType.toString(),
          'spawnTime': currentTime,
          'isActive': false,
          'claimedBy': null,
          'claimedAt': null,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
        currentTime += MIN_SPAWN_INTERVAL_SECONDS + _random.nextInt(MAX_SPAWN_INTERVAL_SECONDS - MIN_SPAWN_INTERVAL_SECONDS + 1);
      }
      await batch.commit();
      print('✅ Created ${TOTAL_POWERUPS_PER_GAME} shared powerup spawns');
    } catch (e) {
      print('❌ Error generating shared spawns: $e');
    }
  }

  static Future<void> checkAndSpawnPowerups(String lobbyId, int gameTimeSeconds) async {
    try {
      final inactivePowerups = await _firestore.collection('lobbies').doc(lobbyId).collection(_powerupSpawnsCollection).where('isActive', isEqualTo: false).get();
      if (inactivePowerups.docs.isEmpty) return;
      final batch = _firestore.batch();
      int activatedCount = 0;
      for (final doc in inactivePowerups.docs) {
        final data = doc.data();
        final spawnTime = data['spawnTime'] as int? ?? 0;
        if (spawnTime <= gameTimeSeconds) {
          batch.update(doc.reference, {'isActive': true, 'activatedAt': DateTime.now().millisecondsSinceEpoch});
          activatedCount++;
        }
      }
      if (activatedCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      print('❌ Error checking powerup spawns: $e');
    }
  }

  static Stream<List<PowerupSpawn>> getPowerupSpawns(String lobbyId) {
    return _firestore.collection('lobbies').doc(lobbyId).collection(_powerupSpawnsCollection).where('isActive', isEqualTo: true).snapshots().map((snapshot) => snapshot.docs.map((doc) => PowerupSpawn.fromFirestore(doc)).toList());
  }

  static Map<String, int>? calculatePlayerSpecificLocation(String powerupId, List<List<int?>> currentBoard, List<List<bool>> givenCells) {
    try {
      final emptyCells = <Map<String, int>>[];
      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          if (!givenCells[row][col] && (currentBoard[row][col] == null || currentBoard[row][col] == 0)) {
            emptyCells.add({'row': row, 'col': col});
          }
        }
      }
      if (emptyCells.isEmpty) return null;
      final seed = powerupId.hashCode;
      final rng = Random(seed);
      emptyCells.shuffle(rng);
      return emptyCells.first;
    } catch (e) {
      print('❌ Error calculating player-specific location: $e');
      return null;
    }
  }

  static Future<bool> claimPowerup(String lobbyId, String spawnId, int row, int col) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      return await _firestore.runTransaction((transaction) async {
        final spawnRef = _firestore.collection('lobbies').doc(lobbyId).collection(_powerupSpawnsCollection).doc(spawnId);
        final spawnDoc = await transaction.get(spawnRef);
        if (!spawnDoc.exists) return false;
        final spawnData = spawnDoc.data() as Map<String, dynamic>;
        if (spawnData['claimedBy'] != null || spawnData['isActive'] != true) return false;
        transaction.update(spawnRef, {'claimedBy': user.uid, 'claimedAt': DateTime.now().millisecondsSinceEpoch, 'claimedLocation': {'row': row, 'col': col}});
        final powerupType = PowerupType.values.firstWhere((e) => e.toString() == spawnData['type']);
        final playerPowerup = PlayerPowerup(id: '${user.uid}_${DateTime.now().millisecondsSinceEpoch}', type: powerupType, playerId: user.uid, obtainedAt: DateTime.now());
        final playerPowerupRef = _firestore.collection('lobbies').doc(lobbyId).collection(_playerPowerupsCollection).doc(playerPowerup.id);
        transaction.set(playerPowerupRef, playerPowerup.toMap());
        return true;
      });
    } catch (e) {
      print('❌ Error claiming powerup: $e');
      return false;
    }
  }

  static Future<bool> usePowerup(String lobbyId, String powerupId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      return await _firestore.runTransaction((transaction) async {
        final powerupRef = _firestore.collection('lobbies').doc(lobbyId).collection(_playerPowerupsCollection).doc(powerupId);
        final powerupDoc = await transaction.get(powerupRef);
        if (!powerupDoc.exists) return false;
        final powerup = PlayerPowerup.fromFirestore(powerupDoc);
        if (powerup.playerId != user.uid || powerup.isUsed) return false;
        transaction.update(powerupRef, {'isUsed': true, 'usedAt': DateTime.now().millisecondsSinceEpoch});
        await _applyPowerupEffect(lobbyId, powerup, transaction);
        return true;
      });
    } catch (e) {
      print('❌ Error using powerup: $e');
      return false;
    }
  }

  static Future<void> _applyPowerupEffect(String lobbyId, PlayerPowerup powerup, Transaction transaction) async {
    final now = DateTime.now();
    switch (powerup.type) {
      case PowerupType.freezeOpponent:
        final opponentId = await _getOpponentId(lobbyId, powerup.playerId);
        if (opponentId != null) {
          final effect = PowerupEffect(id: '${powerup.id}_effect', type: powerup.type, targetPlayerId: opponentId, sourcePlayerId: powerup.playerId, appliedAt: now, expiresAt: now.add(Duration(seconds: 10)), data: {'freezeDuration': 10});
          final effectRef = _firestore.collection('lobbies').doc(lobbyId).collection(_powerupEffectsCollection).doc(effect.id);
          transaction.set(effectRef, effect.toMap());
        }
        break;
      case PowerupType.showSolution:
        final effect = PowerupEffect(id: '${powerup.id}_effect', type: powerup.type, targetPlayerId: powerup.playerId, sourcePlayerId: powerup.playerId, appliedAt: now, expiresAt: now.add(Duration(seconds: 3)), data: {'showDuration': 3});
        final effectRef = _firestore.collection('lobbies').doc(lobbyId).collection(_powerupEffectsCollection).doc(effect.id);
        transaction.set(effectRef, effect.toMap());
        break;
      case PowerupType.bomb:
        final opponentId = await _getOpponentId(lobbyId, powerup.playerId);
        if (opponentId != null) {
          final bombArea = _getRandomBombArea();
          final effect = PowerupEffect(id: '${powerup.id}_effect', type: powerup.type, targetPlayerId: opponentId, sourcePlayerId: powerup.playerId, appliedAt: now, data: {'bombArea': bombArea, 'startRow': bombArea['startRow'], 'startCol': bombArea['startCol']});
          final effectRef = _firestore.collection('lobbies').doc(lobbyId).collection(_powerupEffectsCollection).doc(effect.id);
          transaction.set(effectRef, effect.toMap());
        }
        break;
      case PowerupType.shield:
        final effect = PowerupEffect(id: '${powerup.id}_effect', type: powerup.type, targetPlayerId: powerup.playerId, sourcePlayerId: powerup.playerId, appliedAt: now, data: {'shieldActive': true});
        final effectRef = _firestore.collection('lobbies').doc(lobbyId).collection(_powerupEffectsCollection).doc(effect.id);
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
        if (id != playerId) return id;
      }
      return null;
    } catch (e) {
      print('❌ Error getting opponent ID: $e');
      return null;
    }
  }

  static Stream<List<PlayerPowerup>> getPlayerPowerups(String lobbyId, String playerId) {
    return _firestore.collection('lobbies').doc(lobbyId).collection(_playerPowerupsCollection).where('playerId', isEqualTo: playerId).where('isUsed', isEqualTo: false).snapshots().map((snapshot) => snapshot.docs.map((doc) => PlayerPowerup.fromFirestore(doc)).toList());
  }

  static Stream<List<PowerupEffect>> getPowerupEffects(String lobbyId, String playerId) {
    return _firestore.collection('lobbies').doc(lobbyId).collection(_powerupEffectsCollection).where('targetPlayerId', isEqualTo: playerId).where('isActive', isEqualTo: true).snapshots().map((snapshot) => snapshot.docs.map((doc) => PowerupEffect.fromFirestore(doc)).where((effect) => !effect.isExpired).toList());
  }

  static Future<void> clearLobbyPowerups(String lobbyId) async {
    try {
      final batch = _firestore.batch();
      final spawns = await _firestore.collection('lobbies').doc(lobbyId).collection(_powerupSpawnsCollection).get();
      for (final doc in spawns.docs) {
        batch.delete(doc.reference);
      }
      final playerPowerups = await _firestore.collection('lobbies').doc(lobbyId).collection(_playerPowerupsCollection).get();
      for (final doc in playerPowerups.docs) {
        batch.delete(doc.reference);
      }
      final effects = await _firestore.collection('lobbies').doc(lobbyId).collection(_powerupEffectsCollection).get();
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
      final effects = await _firestore.collection('lobbies').doc(lobbyId).collection(_powerupEffectsCollection).where('isActive', isEqualTo: true).get();
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
      await _firestore.collection('lobbies').doc(lobbyId).collection(_powerupEffectsCollection).doc(effectId).update({'isActive': false});
    } catch (e) {
      print('❌ Error marking bomb effect as inactive: $e');
    }
  }

  static Future<void> useShield(String lobbyId, String playerId) async {
    try {
      final effects = await _firestore.collection('lobbies').doc(lobbyId).collection(_powerupEffectsCollection).where('targetPlayerId', isEqualTo: playerId).where('type', isEqualTo: PowerupType.shield.toString()).where('isActive', isEqualTo: true).get();
      if (effects.docs.isNotEmpty) {
        await effects.docs.first.reference.update({'isActive': false});
      }
    } catch (e) {
      print('❌ Error using shield: $e');
    }
  }

  static Future<bool> hasActiveShield(String lobbyId, String playerId) async {
    try {
      final effects = await _firestore.collection('lobbies').doc(lobbyId).collection(_powerupEffectsCollection).where('targetPlayerId', isEqualTo: playerId).where('type', isEqualTo: PowerupType.shield.toString()).where('isActive', isEqualTo: true).get();
      return effects.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking shield: $e');
      return false;
    }
  }

  // ================== DEMO FIX IS HERE ==================
  static PowerupType _getRandomPowerupType() {
    List<PowerupType> availableTypes = PowerupType.values.toList();
    availableTypes.remove(PowerupType.shield);
    // availableTypes.remove(PowerupType.showSolution);

    // To revert to normal, just use this line instead:
    // final types = PowerupType.values;


    return availableTypes[_random.nextInt(availableTypes.length)];
  }
  // =====================================================

  static Map<String, int> _getRandomBombArea() {
    final areas = [
      {'startRow': 0, 'startCol': 0}, {'startRow': 0, 'startCol': 3}, {'startRow': 0, 'startCol': 6},
      {'startRow': 3, 'startCol': 0}, {'startRow': 3, 'startCol': 3}, {'startRow': 3, 'startCol': 6},
      {'startRow': 6, 'startCol': 0}, {'startRow': 6, 'startCol': 3}, {'startRow': 6, 'startCol': 6},
    ];
    return areas[_random.nextInt(areas.length)];
  }
}
