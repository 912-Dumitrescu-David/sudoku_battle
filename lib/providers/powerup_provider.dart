// providers/powerup_provider.dart - STABILIZED VERSION

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart'; // 🔥 IMPORT for deep equality check
import '../models/powerup_model.dart';
import '../services/powerup_service.dart';

class PowerupProvider extends ChangeNotifier {
  // 🔥 STATE CHANGE: Use a Map for efficient and stable state
  Map<String, PowerupSpawn> _powerupSpawns = {};
  Map<String, PlayerPowerup> _playerPowerups = {};
  Map<String, PowerupEffect> _activeEffects = {};

  bool _isInitialized = false;
  String? _currentLobbyId;
  String? _currentPlayerId;

  Map<String, Map<String, int>> _localPowerupPositions = {};

  int _gameStartTime = 0;
  Timer? _spawnCheckTimer;

  StreamSubscription? _spawnsSubscription;
  StreamSubscription? _powerupsSubscription;
  StreamSubscription? _effectsSubscription;

  Timer? _cleanupTimer;

  // 🔥 GETTERS UPDATED: Getters now read from the maps
  List<PowerupSpawn> get powerupSpawns => _powerupSpawns.values.toList();
  List<PlayerPowerup> get playerPowerups => _playerPowerups.values.toList();
  List<PowerupEffect> get activeEffects => _activeEffects.values.toList();
  bool get isInitialized => _isInitialized;

  bool get isFrozen {
    return _activeEffects.values.any((effect) =>
    effect.type == PowerupType.freezeOpponent &&
        effect.isActive &&
        !effect.isExpired);
  }

  bool get shouldShowSolution {
    return _activeEffects.values.any((effect) =>
    effect.type == PowerupType.showSolution &&
        effect.isActive &&
        !effect.isExpired);
  }

  bool get hasBombEffect {
    return _activeEffects.values.any((effect) =>
    effect.type == PowerupType.bomb && effect.isActive);
  }

  Map<String, dynamic>? get bombEffectData {
    try {
      final effect = _activeEffects.values.firstWhere(
            (effect) => effect.type == PowerupType.bomb && effect.isActive,
      );
      return effect.data;
    } catch (e) {
      return null;
    }
  }

  bool get hasShield {
    return _activeEffects.values.any((effect) =>
    effect.type == PowerupType.shield && effect.isActive);
  }

  Future<void> initialize(String lobbyId) async {
    if (_currentLobbyId == lobbyId && _isInitialized) return;

    await _resetState();

    _currentLobbyId = lobbyId;
    _currentPlayerId = FirebaseAuth.instance.currentUser?.uid;

    if (_currentPlayerId == null) return;

    try {
      // 🔥 STABILIZED LISTENER LOGIC
      _spawnsSubscription = PowerupService.getPowerupSpawns(lobbyId).listen(
            (spawns) {
          final newSpawnsMap = {for (var s in spawns) s.id: s};
          if (!const MapEquality().equals(newSpawnsMap, _powerupSpawns)) {
            final newSpawns = spawns.where((spawn) => !_powerupSpawns.containsKey(spawn.id)).toList();
            _powerupSpawns = newSpawnsMap;

            // ✅ FIX: ADD THIS LOGIC TO REMOVE CLAIMED POWERUPS
            // When a powerup is claimed by anyone, remove its position from the local cache.
            // This prevents the UI from trying to render it.
            _localPowerupPositions.removeWhere((powerupId, position) {
              final spawn = _powerupSpawns[powerupId];
              // Remove if the spawn doesn't exist anymore OR if it has been claimed.
              if (spawn == null || spawn.claimedBy != null) {
                print('🧹 Cleaning up local position for claimed powerup: $powerupId');
                return true;
              }
              return false;
            });

            if (newSpawns.isNotEmpty && _sudokuProviderCallback != null) {
              Future.delayed(const Duration(milliseconds: 100), () {
                _triggerPositionUpdate();
              });
            }
            notifyListeners();
          }
        },
      );

      _powerupsSubscription = PowerupService.getPlayerPowerups(lobbyId, _currentPlayerId!).listen(
            (powerups) {
          final newPowerupsMap = {for (var p in powerups) p.id: p};
          if (!const MapEquality().equals(newPowerupsMap, _playerPowerups)) {
            _playerPowerups = newPowerupsMap;
            notifyListeners();
          }
        },
      );

      _effectsSubscription = PowerupService.getPowerupEffects(lobbyId, _currentPlayerId!).listen(
            (effects) {
          final newEffectsMap = {for (var e in effects) e.id: e};
          if (!const MapEquality().equals(newEffectsMap, _activeEffects)) {
            _activeEffects = newEffectsMap;
            notifyListeners();
          }
        },
      );

      _startCleanupTimer();
      _isInitialized = true;
      print('✅ PowerupProvider initialized successfully (Stabilized)');

    } catch (e) {
      print('❌ Error initializing PowerupProvider: $e');
    }
  }

  void startGame() {
    if (!_isInitialized || _currentLobbyId == null) return;
    _gameStartTime = DateTime.now().millisecondsSinceEpoch;
    _startSpawnCheckTimer();
    print('🎮 Powerup system started - game time: 0s');
  }

  void _startSpawnCheckTimer() {
    _spawnCheckTimer?.cancel();
    _spawnCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_currentLobbyId == null) {
        timer.cancel();
        return;
      }
      final currentGameTime = (DateTime.now().millisecondsSinceEpoch - _gameStartTime) ~/ 1000;
      await PowerupService.checkAndSpawnPowerups(_currentLobbyId!, currentGameTime);
    });
  }

  void updatePowerupPositions(List<List<int?>> currentBoard, List<List<bool>> givenCells) {
    if (!_isInitialized) return;
    for (final spawn in _powerupSpawns.values) {
      if (spawn.claimedBy == null) {
        final location = PowerupService.calculatePlayerSpecificLocation(spawn.id, currentBoard, givenCells);
        if (location != null) {
          _localPowerupPositions[spawn.id] = location;
        } else {
          _localPowerupPositions.remove(spawn.id);
        }
      }
    }
    notifyListeners();
  }

  Future<bool> attemptClaimPowerup(int row, int col) async {
    if (!_isInitialized || _currentLobbyId == null) return false;

    String? powerupIdAtPosition;
    for (final entry in _localPowerupPositions.entries) {
      final position = entry.value;
      if (position['row'] == row && position['col'] == col) {
        if (_powerupSpawns.containsKey(entry.key) && _powerupSpawns[entry.key]?.claimedBy == null) {
          powerupIdAtPosition = entry.key;
          break;
        }
      }
    }

    if (powerupIdAtPosition == null) return false;

    final success = await PowerupService.claimPowerup(_currentLobbyId!, powerupIdAtPosition, row, col);
    if (success) {
      _localPowerupPositions.remove(powerupIdAtPosition);
    }
    return success;
  }

  Future<void> markBombEffectAsHandled(String effectId) async {
    if (_currentLobbyId == null) return;
    print('✅ Marking bomb effect $effectId as handled.');
    await PowerupService.markBombEffectInactive(_currentLobbyId!, effectId);
  }

  // No changes to usePowerup, _apply...Effect methods, callbacks, getPowerupAt, etc.
  // ... (All other methods remain the same)

  Future<bool> usePowerup(String powerupId, PowerupType type) async {
    if (!_isInitialized || _currentLobbyId == null) return false;

    print('🔥 Using powerup: ${_getDisplayNameForPowerupType(type)}');

    final success = await PowerupService.usePowerup(_currentLobbyId!, powerupId);

    if (success) {
      _showPowerupUsedNotification(type);

      // Apply immediate powerup effects locally
      await _applyImmediatePowerupEffect(type);
    }

    return success;
  }

  /// Apply immediate powerup effects (for UI)
  Future<void> _applyImmediatePowerupEffect(PowerupType type) async {
    print('⚡ Applying immediate effect for: ${_getDisplayNameForPowerupType(type)}');

    switch (type) {
      case PowerupType.revealTwoCells:
        await _applyRevealTwoCellsEffect();
        break;
      case PowerupType.extraHints:
        await _applyExtraHintsEffect();
        break;
      case PowerupType.clearMistakes:
        await _applyClearMistakesEffect();
        break;
      case PowerupType.timeBonus:
        await _applyTimeBonusEffect();
        break;
      default:
        print('🔄 Effect ${_getDisplayNameForPowerupType(type)} handled by service');
        break;
    }
  }

  /// Apply reveal two cells effect
  Future<void> _applyRevealTwoCellsEffect() async {
    print('🔍 Applying reveal two cells effect');
    try {
      _triggerSudokuProviderEffect('revealTwoCells');
    } catch (e) {
      print('❌ Error applying reveal cells effect: $e');
    }
  }

  /// Apply extra hints effect
  Future<void> _applyExtraHintsEffect() async {
    print('💡 Applying extra hints effect');
    try {
      _triggerSudokuProviderEffect('extraHints');
    } catch (e) {
      print('❌ Error applying extra hints effect: $e');
    }
  }

  /// Apply clear mistakes effect
  Future<void> _applyClearMistakesEffect() async {
    print('🧹 Applying clear mistakes effect');
    try {
      _triggerSudokuProviderEffect('clearMistakes');
    } catch (e) {
      print('❌ Error applying clear mistakes effect: $e');
    }
  }

  /// Apply time bonus effect
  Future<void> _applyTimeBonusEffect() async {
    print('⏰ Applying time bonus effect');
    try {
      _triggerSudokuProviderEffect('timeBonus');
    } catch (e) {
      print('❌ Error applying time bonus effect: $e');
    }
  }

  /// Trigger effects in SudokuProvider
  void Function(String effectType)? _sudokuProviderCallback;

  void setSudokuProviderCallback(void Function(String effectType)? callback) {
    _sudokuProviderCallback = callback;
    print('🔗 SudokuProvider callback ${callback != null ? 'set' : 'removed'}');
  }

  void _triggerSudokuProviderEffect(String effectType) {
    if (_sudokuProviderCallback != null) {
      print('🔗 Triggering SudokuProvider effect: $effectType');
      _sudokuProviderCallback!(effectType);
    } else {
      print('⚠️ No SudokuProvider callback available for effect: $effectType');
    }
  }

  /// Handle when a correct cell is solved (remove bomb effects)
  Future<void> onCorrectCellSolved() async {
    if (!_isInitialized || _currentLobbyId == null) return;

    // Handle bomb effects - mark them as processed so UI can clear them
    if (hasBombEffect) {
      final effects = _activeEffects.values.where((e) => e.type == PowerupType.bomb && e.isActive);
      for (final effect in effects) {
        // Mark bomb effect as inactive after it's been applied
        await PowerupService.markBombEffectInactive(_currentLobbyId!, effect.id);
      }
    }
  }

  /// 🔥 UPDATED: Get powerup at specific position using local positions
  PowerupSpawn? getPowerupAt(int row, int col) {
    try {
      // Find the ID of the powerup at the target position.
      final entry = _localPowerupPositions.entries.firstWhere(
            (entry) => entry.value['row'] == row && entry.value['col'] == col,
      );

      // Use the found ID to directly look up the PowerupSpawn object from our main map.
      final powerupId = entry.key;
      final spawn = _powerupSpawns[powerupId];

      // Return the spawn only if it exists and hasn't been claimed yet.
      if (spawn != null && spawn.claimedBy == null) {
        return spawn;
      }

      return null;

    } catch (e) {
      // This will happen if .firstWhere finds no match. It's safe to return null.
      return null;
    }
  }

  /// 🔥 UPDATED: Check if there's a powerup at position using local positions
  bool hasPowerupAt(int row, int col) {
    // ✅ FIX: This now uses the same logic as the getPowerupAt method,
    // ensuring it correctly checks if the powerup is still available (not claimed).
    return getPowerupAt(row, col) != null;
  }

  /// Get powerup color for cell using safe color mapping
  Color? getPowerupColor(int row, int col) {
    final powerup = getPowerupAt(row, col);
    if (powerup == null) return null;

    return _getColorForPowerupType(powerup.type);
  }

  /// Safe color mapping for powerup types
  Color _getColorForPowerupType(PowerupType type) {
    switch (type) {
      case PowerupType.revealTwoCells:
        return Color(0xFF4CAF50); // Green
      case PowerupType.freezeOpponent:
        return Color(0xFF2196F3); // Blue
      case PowerupType.extraHints:
        return Color(0xFFFF9800); // Orange
      case PowerupType.clearMistakes:
        return Color(0xFF9C27B0); // Purple
      case PowerupType.timeBonus:
        return Color(0xFFF44336); // Red
      case PowerupType.showSolution:
        return Color(0xFF607D8B); // Blue Grey
      case PowerupType.shield:
        return Color(0xFF795548); // Brown
      case PowerupType.bomb:
        return Color(0xFFFF5722); // Deep Orange
      default:
        return Color(0xFF9C27B0); // Purple fallback
    }
  }

  /// Safe display name mapping for powerup types
  String _getDisplayNameForPowerupType(PowerupType type) {
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

  /// Show powerup claimed notification
  void _showPowerupClaimedNotification(PowerupType type) {
    // This can be handled by the UI layer
    print('🎉 Powerup claimed: ${_getDisplayNameForPowerupType(type)}');
  }

  /// Show powerup used notification
  void _showPowerupUsedNotification(PowerupType type) {
    // This can be handled by the UI layer
    print('⚡ Powerup used: ${_getDisplayNameForPowerupType(type)}');
  }

  /// Start cleanup timer for expired effects
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      if (_currentLobbyId != null) {
        await PowerupService.cleanupExpiredEffects(_currentLobbyId!);
      }
    });
  }

  /// Get freeze time remaining
  int get freezeTimeRemaining {
    final freezeEffect = _activeEffects.values.firstWhere(
          (effect) => effect.type == PowerupType.freezeOpponent &&
          effect.isActive &&
          !effect.isExpired,
      orElse: () => PowerupEffect(
        id: '',
        type: PowerupType.freezeOpponent,
        targetPlayerId: '',
        sourcePlayerId: '',
        appliedAt: DateTime.now(),
      ),
    );

    if (freezeEffect.id.isEmpty || freezeEffect.expiresAt == null) return 0;

    final remaining = freezeEffect.expiresAt!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Get solution show time remaining
  int get solutionShowTimeRemaining {
    final solutionEffect = _activeEffects.values.firstWhere(
          (effect) => effect.type == PowerupType.showSolution &&
          effect.isActive &&
          !effect.isExpired,
      orElse: () => PowerupEffect(
        id: '',
        type: PowerupType.showSolution,
        targetPlayerId: '',
        sourcePlayerId: '',
        appliedAt: DateTime.now(),
      ),
    );

    if (solutionEffect.id.isEmpty || solutionEffect.expiresAt == null) return 0;

    final remaining = solutionEffect.expiresAt!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void updatePositionsWithCurrentBoard(List<List<int?>> board, List<List<bool>> givenCells) {
    print('🎯 Updating powerup positions with current board state');

    if (!_isInitialized) {
      print("DEBUG: updatePositionsWithCurrentBoard exited because provider is not initialized.");
      return;
    }

    updatePowerupPositions(board, givenCells);

    print('📍 Calculated positions:');
    _localPowerupPositions.entries.forEach((entry) {
      final powerupId = entry.key;
      final position = entry.value;
      final spawn = _powerupSpawns[powerupId];
      if (spawn != null) {
        print('   ${spawn.type} -> (${position['row']}, ${position['col']})');
      }
    });

    // 🔥 FIX: Only call notifyListeners ONCE, and don't trigger SudokuProvider
    notifyListeners();

    // 🔥 REMOVED: Don't trigger SudokuProvider update - it causes double notifications
    // _triggerSudokuProviderUpdate();
  }
  void _triggerPositionUpdate() {
    print('🎯 Triggering position update for ${_powerupSpawns.length} spawns');
    _sudokuProviderCallback?.call('updatePowerupPositions');
  }

  void _triggerSudokuProviderUpdate() {
    if (_sudokuProviderCallback != null) {
      print('🔄 Forcing SudokuProvider UI update');
      _sudokuProviderCallback!('forceUIUpdate');
    }
  }


  @override
  void dispose() {
    print('🧹 Disposing PowerupProvider for good.');
    _resetState();
    super.dispose();
  }

  Future<void> _resetState() async {
    print('🔄 Resetting PowerupProvider state...');

    // Cancel all active subscriptions and timers
    _spawnsSubscription?.cancel();
    _powerupsSubscription?.cancel();
    _effectsSubscription?.cancel();
    _cleanupTimer?.cancel();
    _spawnCheckTimer?.cancel();

    // Clear all local data
    _powerupSpawns.clear();
    _playerPowerups.clear();
    _activeEffects.clear();
    _localPowerupPositions.clear();

    // Reset all state variables
    _isInitialized = false;
    _currentLobbyId = null;
    _currentPlayerId = null;
    _gameStartTime = 0;
    _sudokuProviderCallback = null;
  }
}