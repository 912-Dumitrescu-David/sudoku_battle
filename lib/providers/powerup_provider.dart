// providers/powerup_provider.dart - UPDATED VERSION (Local positioning)
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/powerup_model.dart';
import '../services/powerup_service.dart';

class PowerupProvider extends ChangeNotifier {
  List<PowerupSpawn> _powerupSpawns = [];
  List<PlayerPowerup> _playerPowerups = [];
  List<PowerupEffect> _activeEffects = [];

  bool _isInitialized = false;
  String? _currentLobbyId;
  String? _currentPlayerId;

  // 🔥 NEW: Local powerup positioning
  Map<String, Map<String, int>> _localPowerupPositions = {}; // powerupId -> {row, col}

  // Game timing for powerup spawning
  int _gameStartTime = 0;
  Timer? _spawnCheckTimer;

  // Subscriptions
  StreamSubscription? _spawnsSubscription;
  StreamSubscription? _powerupsSubscription;
  StreamSubscription? _effectsSubscription;

  // Cleanup timer
  Timer? _cleanupTimer;

  // Getters
  List<PowerupSpawn> get powerupSpawns => _powerupSpawns;
  List<PlayerPowerup> get playerPowerups => _playerPowerups;
  List<PowerupEffect> get activeEffects => _activeEffects;
  bool get isInitialized => _isInitialized;

  // Check if player is frozen
  bool get isFrozen {
    return _activeEffects.any((effect) =>
    effect.type == PowerupType.freezeOpponent &&
        effect.isActive &&
        !effect.isExpired);
  }

  // Check if solution should be shown
  bool get shouldShowSolution {
    return _activeEffects.any((effect) =>
    effect.type == PowerupType.showSolution &&
        effect.isActive &&
        !effect.isExpired);
  }

  // Check if bomb effect is active
  bool get hasBombEffect {
    return _activeEffects.any((effect) =>
    effect.type == PowerupType.bomb &&
        effect.isActive);
  }

  // Get bomb effect data
  Map<String, dynamic>? get bombEffectData {
    try {
      final effect = _activeEffects.firstWhere(
            (effect) => effect.type == PowerupType.bomb && effect.isActive,
      );
      return effect.data;
    } catch (e) {
      return null;
    }
  }

  // Check if player has shield
  bool get hasShield {
    return _activeEffects.any((effect) =>
    effect.type == PowerupType.shield &&
        effect.isActive);
  }

  /// Initialize powerup system for a lobby
  Future<void> initialize(String lobbyId) async {
    if (_currentLobbyId == lobbyId && _isInitialized) return;

    print('🔮 Initializing PowerupProvider for lobby: $lobbyId (local positioning)');

    // Clean up previous subscriptions
    await dispose();

    _currentLobbyId = lobbyId;
    _currentPlayerId = FirebaseAuth.instance.currentUser?.uid;

    if (_currentPlayerId == null) return;

    try {
      _spawnsSubscription = PowerupService.getPowerupSpawns(lobbyId).listen(
            (spawns) {
          print('🔮 Powerup spawns updated: ${spawns.length} spawns');

          // Check if we have new spawns
          final newSpawns = spawns.where((spawn) =>
          !_powerupSpawns.any((existing) => existing.id == spawn.id)
          ).toList();

          _powerupSpawns = spawns;

          // 🔥 CRITICAL: If new spawns, trigger immediate position calculation
          if (newSpawns.isNotEmpty && _sudokuProviderCallback != null) {
            print('🎆 New spawns detected: ${newSpawns.length}');

            // Small delay to ensure spawn data is fully processed
            Future.delayed(Duration(milliseconds: 100), () {
              _triggerPositionUpdate();
            });
          }

          // 🔥 FORCE UI UPDATE
          notifyListeners();
        },
        onError: (error) {
          print('❌ Error listening to powerup spawns: $error');
        },
      );

      // Subscribe to player powerups
      _powerupsSubscription = PowerupService.getPlayerPowerups(lobbyId, _currentPlayerId!).listen(
            (powerups) {
          _playerPowerups = powerups;
          notifyListeners();
        },
        onError: (error) {
          print('❌ Error listening to player powerups: $error');
        },
      );

      // Subscribe to active effects
      _effectsSubscription = PowerupService.getPowerupEffects(lobbyId, _currentPlayerId!).listen(
            (effects) {
          _activeEffects = effects;
          notifyListeners();
        },
        onError: (error) {
          print('❌ Error listening to powerup effects: $error');
        },
      );

      // Start cleanup timer
      _startCleanupTimer();

      _isInitialized = true;
      print('✅ PowerupProvider initialized successfully (local positioning)');

    } catch (e) {
      print('❌ Error initializing PowerupProvider: $e');
    }
  }

  /// Start the game and begin powerup spawn checking
  void startGame() {
    if (!_isInitialized || _currentLobbyId == null) return;

    _gameStartTime = DateTime.now().millisecondsSinceEpoch;

    // Start periodic checking for powerup spawns
    _startSpawnCheckTimer();

    print('🎮 Powerup system started - game time: 0s');
  }

  /// Start timer to check for powerup spawns
  void _startSpawnCheckTimer() {
    _spawnCheckTimer?.cancel();

    // Check every 5 seconds for new powerups to spawn
    _spawnCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      if (_currentLobbyId == null) {
        timer.cancel();
        return;
      }

      final currentGameTime = _getCurrentGameTimeSeconds();
      await PowerupService.checkAndSpawnPowerups(_currentLobbyId!, currentGameTime);
    });
  }

  /// Get current game time in seconds
  int _getCurrentGameTimeSeconds() {
    if (_gameStartTime == 0) return 0;
    return (DateTime.now().millisecondsSinceEpoch - _gameStartTime) ~/ 1000;
  }

  /// 🔥 NEW: Calculate and cache powerup positions for current player
  void updatePowerupPositions(List<List<int?>> currentBoard, List<List<bool>> givenCells) {
    if (!_isInitialized) return;

    // Calculate positions for all active powerups that aren't claimed yet
    for (final spawn in _powerupSpawns) {
      if (spawn.claimedBy == null) { // Only position unclaimed powerups
        final location = PowerupService.calculatePlayerSpecificLocation(
          spawn.id,
          currentBoard,
          givenCells,
        );

        if (location != null) {
          _localPowerupPositions[spawn.id] = location;
        } else {
          // Remove position if no empty cells available
          _localPowerupPositions.remove(spawn.id);
        }
      }
    }

    notifyListeners();
  }

  /// 🔥 UPDATED: Attempt to claim a powerup using local position
  Future<bool> attemptClaimPowerup(int row, int col) async {
    if (!_isInitialized || _currentLobbyId == null) return false;

    // Find powerup at this position for this player
    String? powerupIdAtPosition;

    for (final entry in _localPowerupPositions.entries) {
      final powerupId = entry.key;
      final position = entry.value;

      if (position['row'] == row && position['col'] == col) {
        // Check if this powerup still exists and isn't claimed
        final spawn = _powerupSpawns.where((s) => s.id == powerupId && s.claimedBy == null).firstOrNull;
        if (spawn != null) {
          powerupIdAtPosition = powerupId;
          break;
        }
      }
    }

    if (powerupIdAtPosition == null) {
      print('🔍 No claimable powerup found at ($row, $col)');
      return false;
    }

    print('🎯 Attempting to claim powerup $powerupIdAtPosition at ($row, $col)');

    final success = await PowerupService.claimPowerup(
      _currentLobbyId!,
      powerupIdAtPosition,
      row,
      col,
    );

    if (success) {
      final powerupType = _powerupSpawns
          .where((s) => s.id == powerupIdAtPosition)
          .firstOrNull?.type;

      if (powerupType != null) {
        print('✨ Successfully claimed ${_getDisplayNameForPowerupType(powerupType)}!');
        _showPowerupClaimedNotification(powerupType);
      }

      // Remove from local positions since it's claimed
      _localPowerupPositions.remove(powerupIdAtPosition);
    }

    return success;
  }

  /// Use a powerup - same as before
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
      final effects = _activeEffects.where((e) => e.type == PowerupType.bomb && e.isActive);
      for (final effect in effects) {
        // Mark bomb effect as inactive after it's been applied
        await PowerupService.markBombEffectInactive(_currentLobbyId!, effect.id);
      }
    }
  }

  /// 🔥 UPDATED: Get powerup at specific position using local positions
  PowerupSpawn? getPowerupAt(int row, int col) {
    try {
      // Look through local positions to find powerup at this location
      for (final entry in _localPowerupPositions.entries) {
        final powerupId = entry.key;
        final position = entry.value;

        if (position['row'] == row && position['col'] == col) {
          // Find the corresponding spawn
          try {
            return _powerupSpawns.where((spawn) =>
            spawn.id == powerupId && spawn.claimedBy == null
            ).first;
          } catch (e) {
            // No matching spawn found
            return null;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🔥 UPDATED: Check if there's a powerup at position using local positions
  bool hasPowerupAt(int row, int col) {
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
    final freezeEffect = _activeEffects.firstWhere(
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
    final solutionEffect = _activeEffects.firstWhere(
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
    updatePowerupPositions(board, givenCells);

    // Log the calculated positions for debugging
    print('📍 Calculated positions:');
    for (final entry in _localPowerupPositions.entries) {
      final powerupId = entry.key;
      final position = entry.value;
      final spawn = _powerupSpawns.where((s) => s.id == powerupId).firstOrNull;
      if (spawn != null) {
        print('   ${spawn.type} -> (${position['row']}, ${position['col']})');
      }
    }

    // 🔥 CRITICAL: Force UI update by notifying listeners
    notifyListeners();

    // 🔥 ADDITIONAL: Trigger SudokuProvider update too
    _triggerSudokuProviderUpdate();
  }

  void _triggerPositionUpdate() {
    print('🎯 Triggering position update for ${_powerupSpawns.length} spawns');
    _sudokuProviderCallback?.call('updatePowerupPositions');
  }

  // 🔥 NEW: Method to force SudokuProvider to update
  void _triggerSudokuProviderUpdate() {
    if (_sudokuProviderCallback != null) {
      print('🔄 Forcing SudokuProvider UI update');
      _sudokuProviderCallback!('forceUIUpdate');
    }
  }


  @override
  Future<void> dispose() async {
    print('🧹 Disposing PowerupProvider');

    _spawnsSubscription?.cancel();
    _powerupsSubscription?.cancel();
    _effectsSubscription?.cancel();
    _cleanupTimer?.cancel();
    _spawnCheckTimer?.cancel();

    _powerupSpawns.clear();
    _playerPowerups.clear();
    _activeEffects.clear();
    _localPowerupPositions.clear(); // 🔥 NEW: Clear local positions

    _isInitialized = false;
    _currentLobbyId = null;
    _currentPlayerId = null;
    _gameStartTime = 0;
    _sudokuProviderCallback = null;

    super.dispose();
  }




}