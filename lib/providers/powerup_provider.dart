// providers/powerup_provider.dart - FIXED VERSION
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

  // Check if double points is active
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

    print('🔮 Initializing PowerupProvider for lobby: $lobbyId');

    // Clean up previous subscriptions
    await dispose();

    _currentLobbyId = lobbyId;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Initialize powerup system in Firestore
      await PowerupService.initializePowerups(lobbyId);

      // Subscribe to powerup spawns
      _spawnsSubscription = PowerupService.getPowerupSpawns(lobbyId).listen(
            (spawns) {
          _powerupSpawns = spawns;
          notifyListeners();
        },
        onError: (error) {
          print('❌ Error listening to powerup spawns: $error');
        },
      );

      // Subscribe to player powerups
      _powerupsSubscription = PowerupService.getPlayerPowerups(lobbyId, user.uid).listen(
            (powerups) {
          _playerPowerups = powerups;
          notifyListeners();
        },
        onError: (error) {
          print('❌ Error listening to player powerups: $error');
        },
      );

      // Subscribe to active effects
      _effectsSubscription = PowerupService.getPowerupEffects(lobbyId, user.uid).listen(
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
      print('✅ PowerupProvider initialized successfully');

    } catch (e) {
      print('❌ Error initializing PowerupProvider: $e');
    }
  }

  /// Attempt to claim a powerup when solving a cell
  Future<bool> attemptClaimPowerup(int row, int col) async {
    if (!_isInitialized || _currentLobbyId == null) return false;

    // Find powerup at this position
    final powerupAtPosition = _powerupSpawns.firstWhere(
          (spawn) => spawn.row == row && spawn.col == col && spawn.isActive,
      orElse: () => PowerupSpawn(
        id: '',
        type: PowerupType.revealTwoCells,
        row: -1,
        col: -1,
        spawnTime: DateTime.now(),
      ),
    );

    if (powerupAtPosition.row == -1) return false;

    print('🎯 Attempting to claim powerup at ($row, $col)');

    final success = await PowerupService.claimPowerup(
      _currentLobbyId!,
      powerupAtPosition.id,
      row,
      col,
    );

    if (success) {
      print('✨ Successfully claimed ${_getDisplayNameForPowerupType(powerupAtPosition.type)}!');

      // Show claim notification
      _showPowerupClaimedNotification(powerupAtPosition.type);
    }

    return success;
  }

  /// Use a powerup - 🔥 FIXED VERSION with proper effect application
  Future<bool> usePowerup(String powerupId, PowerupType type) async {
    if (!_isInitialized || _currentLobbyId == null) return false;

    print('🔥 Using powerup: ${_getDisplayNameForPowerupType(type)}');

    final success = await PowerupService.usePowerup(_currentLobbyId!, powerupId);

    if (success) {
      _showPowerupUsedNotification(type);

      // 🔥 FIXED: Apply immediate powerup effects locally
      await _applyImmediatePowerupEffect(type);
    }

    return success;
  }

  /// Apply immediate powerup effects (for UI) - 🔥 FIXED VERSION
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
      // Other effects are handled by the service (freeze, bomb, shield, show solution)
        print('🔄 Effect ${_getDisplayNameForPowerupType(type)} handled by service');
        break;
    }
  }

  /// Apply reveal two cells effect - 🔥 FIXED VERSION
  Future<void> _applyRevealTwoCellsEffect() async {
    print('🔍 Applying reveal two cells effect');

    // Find the SudokuProvider and apply the effect
    try {
      // We need to get access to the SudokuProvider to apply the effect
      // This will be handled by the UI layer that has access to both providers
      _triggerSudokuProviderEffect('revealTwoCells');
    } catch (e) {
      print('❌ Error applying reveal cells effect: $e');
    }
  }

  /// Apply extra hints effect - 🔥 FIXED VERSION
  Future<void> _applyExtraHintsEffect() async {
    print('💡 Applying extra hints effect');

    try {
      _triggerSudokuProviderEffect('extraHints');
    } catch (e) {
      print('❌ Error applying extra hints effect: $e');
    }
  }

  /// Apply clear mistakes effect - 🔥 FIXED VERSION
  Future<void> _applyClearMistakesEffect() async {
    print('🧹 Applying clear mistakes effect');

    try {
      _triggerSudokuProviderEffect('clearMistakes');
    } catch (e) {
      print('❌ Error applying clear mistakes effect: $e');
    }
  }

  /// Apply time bonus effect - 🔥 FIXED VERSION
  Future<void> _applyTimeBonusEffect() async {
    print('⏰ Applying time bonus effect');

    try {
      _triggerSudokuProviderEffect('timeBonus');
    } catch (e) {
      print('❌ Error applying time bonus effect: $e');
    }
  }

  /// 🔥 NEW: Trigger effects in SudokuProvider
  /// This is a callback mechanism that the UI layer will hook into
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

  /// Get powerup at specific position
  PowerupSpawn? getPowerupAt(int row, int col) {
    try {
      return _powerupSpawns.firstWhere(
            (spawn) => spawn.row == row && spawn.col == col && spawn.isActive,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if there's a powerup at position
  bool hasPowerupAt(int row, int col) {
    return getPowerupAt(row, col) != null;
  }

  /// FIXED: Get powerup color for cell using safe color mapping
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

  @override
  Future<void> dispose() async {
    print('🧹 Disposing PowerupProvider');

    _spawnsSubscription?.cancel();
    _powerupsSubscription?.cancel();
    _effectsSubscription?.cancel();
    _cleanupTimer?.cancel();

    _powerupSpawns.clear();
    _playerPowerups.clear();
    _activeEffects.clear();

    _isInitialized = false;
    _currentLobbyId = null;
    _sudokuProviderCallback = null; // 🔥 Clear callback

    super.dispose();
  }
}