// providers/sudoku_provider.dart - FIXED VERSION
import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/sudoku_engine.dart';
import '../models/lobby_model.dart';
import '../models/powerup_model.dart';
import '../providers/powerup_provider.dart';

class SudokuProvider extends ChangeNotifier {
  late List<List<int?>> _board;
  late List<List<int>> _solution;
  late List<List<bool>> _givenCells;
  late List<List<bool>> _errorCells;

  int? _selectedRow;
  int? _selectedCol;

  int _mistakesCount = 0;
  int get mistakesCount => _mistakesCount;

  // Maximum mistakes from game settings (default to 3)
  int _maxMistakes = 3;
  int get maxMistakes => _maxMistakes;

  int solvedCells = 0;

  // Hints functionality
  int _hintsRemaining = 3;
  int get hintsRemaining => _hintsRemaining;

  // Game settings and mode tracking
  GameSettings? _gameSettings;
  GameMode _currentGameMode = GameMode.classic; // 🔥 Track current game mode
  bool _isPowerupMode = false; // 🔥 Track if powerups are enabled

  // Powerup integration
  PowerupProvider? _powerupProvider;

  // Time bonus tracking
  int _bonusTimeAdded = 0;
  int get bonusTimeAdded => _bonusTimeAdded;

  SudokuProvider() {
    _board = List.generate(9, (_) => List.filled(9, null));
    _solution = List.generate(9, (_) => List.filled(9, 0));
    _givenCells = List.generate(9, (_) => List.filled(9, false));
    _errorCells = List.generate(9, (_) => List.filled(9, false));
  }

  List<List<int?>> get board => _board;
  List<List<int>> get solution => _solution;
  List<List<bool>> get givenCells => _givenCells;
  List<List<bool>> get errorCells => _errorCells;
  int? get selectedRow => _selectedRow;
  int? get selectedCol => _selectedCol;
  int get mistakes => _mistakesCount;
  int get solved => solvedCells;

  // 🔥 NEW: Getter to check if powerups are enabled
  bool get isPowerupModeEnabled => _isPowerupMode;

  void initializePowerups(PowerupProvider powerupProvider) {
    _powerupProvider = powerupProvider;
    _isPowerupMode = true;

    // 🔥 CRITICAL FIX: Set up callback to handle position updates
    _powerupProvider!.setSudokuProviderCallback((effectType) {
      print('🔗 SudokuProvider received effect: $effectType');

      if (effectType == 'updatePowerupPositions') {
        // 🎯 AUTO-CALCULATE positions when new powerups spawn
        _powerupProvider!.updatePositionsWithCurrentBoard(_board, _givenCells);
      } else {
        // Handle other powerup effects
        _handlePowerupEffect(effectType);
      }
    });

    print('🔮 SudokuProvider: Powerups initialized with position callback');
  }

  void _handlePowerupEffect(String effectType) {
    switch (effectType) {
      case 'updatePowerupPositions':
      // 🎯 AUTO-CALCULATE positions when new powerups spawn
        _powerupProvider!.updatePositionsWithCurrentBoard(_board, _givenCells);

        // 🔥 CRITICAL: Force UI update after position calculation
        notifyListeners();
        break;

      case 'forceUIUpdate':
      // 🔥 NEW: Force UI update
        print('🔄 Forcing SudokuProvider UI update');
        notifyListeners();
        break;

      case 'revealTwoCells':
        applyRevealCellPowerup();
        break;
      case 'extraHints':
        applyExtraHintsPowerup();
        break;
      case 'clearMistakes':
        applyClearErrorsPowerup();
        break;
      case 'timeBonus':
        applyTimeBonusPowerup();
        break;
      default:
        print('🔄 Unknown powerup effect: $effectType');
    }
  }

  // 🔥 ADDITIONAL: Add a method to manually force powerup position updates
  void forceUpdatePowerupPositions() {
    if (_isPowerupMode && _powerupProvider != null) {
      print('🔄 Manually forcing powerup position update');
      _powerupProvider!.updatePositionsWithCurrentBoard(_board, _givenCells);
      notifyListeners();
    }
  }


  /// Generate a new puzzle using our custom SudokuEngine
  void generatePuzzle({
    required int emptyCells,
    GameSettings? gameSettings,
    GameMode gameMode = GameMode.classic, // 🔥 Add game mode parameter
  }) {
    print('🎲 SudokuProvider: Generating puzzle for mode: $gameMode');

    // Store game settings and mode
    _gameSettings = gameSettings;
    _currentGameMode = gameMode;
    _isPowerupMode = gameMode == GameMode.powerup; // 🔥 Only enable powerups for powerup mode

    // Apply game settings
    if (gameSettings != null) {
      _maxMistakes = gameSettings.allowMistakes ? gameSettings.maxMistakes : 1;
      _hintsRemaining = gameSettings.allowHints ? 3 : 0;
    } else {
      // Default values for classic mode
      _maxMistakes = 3;
      _hintsRemaining = 3;
    }

    // Convert emptyCells to difficulty
    Difficulty difficulty;
    if (emptyCells <= 40) {
      difficulty = Difficulty.easy;
    } else if (emptyCells <= 50) {
      difficulty = Difficulty.medium;
    } else if (emptyCells <= 54) {
      difficulty = Difficulty.hard;
    } else {
      difficulty = Difficulty.expert;
    }

    final puzzleData = SudokuEngine.generatePuzzle(difficulty);

    // Convert puzzle format
    _solution = puzzleData['solution'].map<List<int>>((row) =>
        (row as List).cast<int>()).toList();

    // Convert puzzle to nullable format for compatibility
    final puzzle = puzzleData['puzzle'] as List<List<int>>;
    _board = puzzle.map<List<int?>>((row) =>
        row.map<int?>((cell) => cell == 0 ? null : cell).toList()).toList();

    _givenCells = List.generate(
      9,
          (i) => List.generate(9, (j) => _board[i][j] != null && _board[i][j] != 0),
    );

    // Reset errors and mistakes
    _errorCells = List.generate(9, (_) => List.filled(9, false));
    _mistakesCount = 0;
    _selectedRow = null;
    _selectedCol = null;
    solvedCells = 0;
    _bonusTimeAdded = 0;

    print('✅ SudokuProvider: Puzzle generated. Powerups enabled: $_isPowerupMode');
    notifyListeners();
  }

  /// Generate puzzle from existing puzzle data (for multiplayer)
  void loadPuzzle(
      Map<String, dynamic> puzzleData, {
        GameSettings? gameSettings,
        GameMode gameMode = GameMode.classic, // 🔥 Add game mode parameter
      }) {
    print('📥 SudokuProvider: Loading puzzle for mode: $gameMode');

    // Store game settings and mode
    _gameSettings = gameSettings;
    _currentGameMode = gameMode;
    _isPowerupMode = gameMode == GameMode.powerup; // 🔥 Only enable powerups for powerup mode

    // Apply game settings
    if (gameSettings != null) {
      _maxMistakes = gameSettings.allowMistakes ? gameSettings.maxMistakes : 1;
      _hintsRemaining = gameSettings.allowHints ? 3 : 0;
    } else {
      // Default values
      _maxMistakes = 3;
      _hintsRemaining = 3;
    }

    _solution = (puzzleData['solution'] as List).map<List<int>>((row) =>
        (row as List).cast<int>()).toList();

    final puzzle = puzzleData['puzzle'] as List<List<int>>;
    _board = puzzle.map<List<int?>>((row) =>
        row.map<int?>((cell) => cell == 0 ? null : cell).toList()).toList();

    _givenCells = List.generate(
      9,
          (i) => List.generate(9, (j) => _board[i][j] != null && _board[i][j] != 0),
    );

    // Reset state
    _errorCells = List.generate(9, (_) => List.filled(9, false));
    _mistakesCount = 0;
    _selectedRow = null;
    _selectedCol = null;
    solvedCells = 0;
    _bonusTimeAdded = 0;

    print('✅ SudokuProvider: Puzzle loaded. Powerups enabled: $_isPowerupMode');
    notifyListeners();
  }

  /// Select an editable cell.
  void selectCell(int row, int col) {
    if (!_givenCells[row][col]) {
      _selectedRow = row;
      _selectedCol = col;
      notifyListeners();
    }
  }

  //// Handle user number input with validation and powerup integration
  void handleNumberInput(int number) {
    if (_selectedRow == null || _selectedCol == null) return;
    int row = _selectedRow!;
    int col = _selectedCol!;

    if (!_givenCells[row][col]) {
      // Only check freeze if powerups are enabled
      if (_isPowerupMode && _powerupProvider?.isFrozen == true) {
        print('❄️ Player is frozen, cannot input numbers');
        return;
      }

      // Store previous value to check if it was correct
      int? previousValue = _board[row][col];
      bool wasPreviousCorrect = previousValue != null && previousValue == _solution[row][col];

      // Update the board
      _board[row][col] = number;

      // Check if the new input is correct
      bool isCorrect = number == _solution[row][col];

      if (isCorrect) {
        // Correct input
        _errorCells[row][col] = false;
        if (!wasPreviousCorrect) {
          solvedCells++;

          // 🔥 ONLY try to claim powerup if powerups are enabled
          if (_isPowerupMode) {
            _powerupProvider?.attemptClaimPowerup(row, col);
          }
        }
      } else {
        // Wrong input - only count as mistake if mistakes are enabled
        if (_gameSettings?.allowMistakes ?? true) {
          _errorCells[row][col] = true;
          _mistakesCount++;
        } else {
          // If mistakes not allowed, still show error but don't increment counter
          _errorCells[row][col] = true;
        }

        if (wasPreviousCorrect) {
          solvedCells--;
        }
      }

      // 🔥 NEW: Update powerup positions after any board change (if powerups enabled)
      if (_isPowerupMode && _powerupProvider != null) {
        _powerupProvider!.updatePowerupPositions(_board, _givenCells);
      }

      notifyListeners();
    }
  }

  /// 🔥 NEW: Update powerup positions whenever the board changes
  void _updatePowerupPositions() {
    if (_isPowerupMode && _powerupProvider != null) {
      _powerupProvider!.updatePowerupPositions(_board, _givenCells);
    }
  }

  // POWERUP APPLICATION METHODS

  /// Apply reveal cell powerup - 🔥 UPDATED VERSION
  void applyRevealCellPowerup() {
    print('🔍 Applying reveal cell powerup');

    // Find all empty cells
    final emptyCells = <Map<String, int>>[];
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (!_givenCells[i][j] && (_board[i][j] == null || _board[i][j] == 0)) {
          emptyCells.add({'row': i, 'col': j});
        }
      }
    }

    if (emptyCells.isNotEmpty) {
      // Reveal TWO random cells (as the powerup name suggests)
      final cellsToReveal = min(2, emptyCells.length);
      final Random random = Random();

      for (int k = 0; k < cellsToReveal; k++) {
        if (emptyCells.isEmpty) break;

        final randomIndex = random.nextInt(emptyCells.length);
        final randomCell = emptyCells.removeAt(randomIndex); // Remove to avoid duplicates
        final row = randomCell['row']!;
        final col = randomCell['col']!;

        // Reveal the correct number
        _board[row][col] = _solution[row][col];
        _errorCells[row][col] = false;
        solvedCells++;

        print('🔍 Revealed cell at ($row, $col) = ${_solution[row][col]}');
      }

      // 🔥 NEW: Update powerup positions after revealing cells
      _updatePowerupPositions();

      // Update UI
      notifyListeners();
      print('✅ Revealed $cellsToReveal cells');
    } else {
      print('⚠️ No empty cells to reveal');
    }
  }

  /// Apply extra hints powerup - 🔥 FIXED VERSION
  void applyExtraHintsPowerup() {
    _hintsRemaining += 2;
    notifyListeners(); // 🔥 FIXED: Added notifyListeners
    print('💡 Added 2 extra hints. Total: $_hintsRemaining');
  }

  void applyClearErrorsPowerup() {
    int errorsCleared = 0;
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (_errorCells[i][j]) {
          _errorCells[i][j] = false;
          _board[i][j] = null; // Clear the incorrect value
          errorsCleared++;
        }
      }
    }

    // Reset mistake count
    _mistakesCount = 0;

    // 🔥 NEW: Update powerup positions after clearing errors
    _updatePowerupPositions();

    notifyListeners();
    print('🧹 Cleared $errorsCleared errors and reset mistake count');
  }
  /// Apply time bonus powerup - 🔥 FIXED VERSION
  void applyTimeBonusPowerup() {
    _bonusTimeAdded += 60; // Add 60 seconds
    notifyListeners(); // 🔥 FIXED: Added notifyListeners
    print('⏰ Added 60 seconds to timer. Total bonus: $_bonusTimeAdded');
  }

  // HINT FUNCTIONALITY (Enhanced with powerups)

  /// Check if hint can be used
  bool canUseHint() {
    return _hintsRemaining > 0 &&
        _selectedRow != null &&
        _selectedCol != null &&
        !_givenCells[_selectedRow!][_selectedCol!] &&
        (_gameSettings?.allowHints ?? true) &&
        // 🔥 ONLY check freeze if powerups are enabled
        (!_isPowerupMode || _powerupProvider?.isFrozen != true);
  }

  /// Use a hint on the selected cell
  void useHint() {
    if (!canUseHint()) return;

    final row = _selectedRow!;
    final col = _selectedCol!;
    final correctNumber = _solution[row][col];

    // Store previous value to check if it was already correct
    int? previousValue = _board[row][col];
    bool wasPreviousCorrect = previousValue != null && previousValue == correctNumber;

    // Set the correct number
    _board[row][col] = correctNumber;
    _errorCells[row][col] = false;

    // Update solved cells count
    if (!wasPreviousCorrect) {
      solvedCells++;

      // 🔥 ONLY try to claim powerup if powerups are enabled
      if (_isPowerupMode) {
        _powerupProvider?.attemptClaimPowerup(row, col);
      }
    }

    // Decrease hints remaining
    _hintsRemaining--;

    // 🔥 NEW: Update powerup positions after hint usage
    _updatePowerupPositions();

    notifyListeners();
  }

  /// Reset hints to default value
  void resetHints() {
    _hintsRemaining = (_gameSettings?.allowHints ?? true) ? 3 : 0;
    notifyListeners();
  }

  // EXISTING METHODS (updated to work with powerups)

  /// Validate a move (for multiplayer sync)
  bool isValidMove(int row, int col, int number) {
    if (_givenCells[row][col]) return false;
    return SudokuEngine.isValidMove(_getCurrentBoard(), row, col, number);
  }

  /// Get current board as int grid (for validation)
  List<List<int>> _getCurrentBoard() {
    return _board.map((row) =>
        row.map((cell) => cell ?? 0).toList()).toList();
  }

  /// Apply move from multiplayer (opponent's move)
  void applyMove(int row, int col, int number, String playerId) {
    if (!_givenCells[row][col]) {
      _board[row][col] = number;

      // Don't count as mistake for opponent moves, just apply
      if (number == _solution[row][col]) {
        _errorCells[row][col] = false;
      }

      notifyListeners();
    }
  }

  /// Calculate how many of each number (1-9) are left.
  Map<int, int> calculateNumberCounts() {
    Map<int, int> counts = {for (var i = 1; i <= 9; i++) i: 9};

    for (var row in _board) {
      for (var value in row) {
        if (value != null && value != 0) {
          counts[value] = counts[value]! - 1;
        }
      }
    }
    return counts;
  }

  bool get isSolved {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (_board[i][j] == null || _board[i][j] == 0 || _board[i][j] != _solution[i][j]) {
          return false;
        }
      }
    }
    return true;
  }

  /// Check if puzzle is complete (all cells filled)
  bool get isPuzzleComplete {
    return SudokuEngine.isPuzzleComplete(_getCurrentBoard());
  }

  void resetMistakes() {
    _mistakesCount = 0;
    notifyListeners();
  }

  void resetSolvedCells() {
    solvedCells = 0;
    notifyListeners();
  }

  void resetBonusTime() {
    _bonusTimeAdded = 0;
    notifyListeners();
  }

  /// Get puzzle progress percentage
  double get progress {
    int totalCells = 0;
    int filledCells = 0;

    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (!_givenCells[i][j]) {
          totalCells++;
          if (_board[i][j] != null && _board[i][j] != 0) {
            filledCells++;
          }
        }
      }
    }

    return totalCells > 0 ? filledCells / totalCells : 0.0;
  }

  /// Check if cell has powerup (for UI highlighting) - 🔥 ONLY for powerup mode
  bool hasPowerupAt(int row, int col) {
    if (!_isPowerupMode) return false; // 🔥 Return false if not in powerup mode
    return _powerupProvider?.hasPowerupAt(row, col) ?? false;
  }

  /// Get powerup color for cell - 🔥 ONLY for powerup mode
  Color? getPowerupColor(int row, int col) {
    if (!_isPowerupMode) return null; // 🔥 Return null if not in powerup mode

    final powerup = _powerupProvider?.getPowerupAt(row, col);
    if (powerup == null) return null;

    // Use safe color mapping instead of extension
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

  /// Get powerup at position (for UI display) - 🔥 ONLY for powerup mode
  PowerupSpawn? getPowerupAt(int row, int col) {
    if (!_isPowerupMode) return null; // 🔥 Return null if not in powerup mode
    return _powerupProvider?.getPowerupAt(row, col);
  }
}