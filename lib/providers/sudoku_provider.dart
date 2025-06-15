import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/lobby_service.dart';
import '../utils/sudoku_engine.dart';
import '../models/lobby_model.dart';
import '../models/powerup_model.dart';
import '../providers/powerup_provider.dart';

class SudokuProvider extends ChangeNotifier {
  late List<List<int?>> _board;
  late List<List<int>> _solution;
  late List<List<bool>> _givenCells;
  late List<List<bool>> _errorCells;

  late List<List<String?>> _playerCellEntries;

  String? _lobbyId;

  int? _selectedRow;
  int? _selectedCol;

  int _mistakesCount = 0;
  int get mistakesCount => _mistakesCount;

  int _maxMistakes = 3;
  int get maxMistakes => _maxMistakes;

  int solvedCells = 0;

  int _hintsRemaining = 3;
  int get hintsRemaining => _hintsRemaining;

  GameSettings? _gameSettings;
  GameMode _currentGameMode = GameMode.classic;
  bool _isPowerupMode = false;
  VoidCallback? onRankedGameLost;

  PowerupProvider? _powerupProvider;

  int _bonusTimeAdded = 0;
  int get bonusTimeAdded => _bonusTimeAdded;

  bool isGameOver = false;
  bool? isGameWon;
  bool _isRankedGame = false;

  SudokuProvider() {
    _board = List.generate(9, (_) => List.filled(9, null));
    _solution = List.generate(9, (_) => List.filled(9, 0));
    _givenCells = List.generate(9, (_) => List.filled(9, false));
    _errorCells = List.generate(9, (_) => List.filled(9, false));

    _playerCellEntries = List.generate(9, (_) => List.filled(9, null));
  }

  List<List<int?>> get board => _board;
  List<List<int>> get solution => _solution;
  List<List<bool>> get givenCells => _givenCells;
  List<List<bool>> get errorCells => _errorCells;
  List<List<String?>> get playerCellEntries => _playerCellEntries;
  int? get selectedRow => _selectedRow;
  int? get selectedCol => _selectedCol;
  int get mistakes => _mistakesCount;
  int get solved => solvedCells;
  GameMode get currentGameMode => _currentGameMode;

  bool get isPowerupModeEnabled => _isPowerupMode;

  void initializePowerups(PowerupProvider powerupProvider) {
    _powerupProvider = powerupProvider;
    _isPowerupMode = true;

    _powerupProvider!.setSudokuProviderCallback((effectType) {
      print("DEBUG: SudokuProvider callback received effect: '$effectType'");

      if (effectType == 'updatePowerupPositions') {
        _powerupProvider!.updatePositionsWithCurrentBoard(_board, _givenCells);
        notifyListeners();
      } else {
        _handlePowerupEffect(effectType);
      }
    });

    print('🔮 SudokuProvider: Powerups initialized with position callback');
  }

  void setLobbyId(String lobbyId) {
    _lobbyId = lobbyId;
  }

  void setGameLostCallback(VoidCallback callback) {
    onRankedGameLost = callback;
  }

  void _handlePowerupEffect(String effectType) {
    switch (effectType) {
      case 'updatePowerupPositions':
        _powerupProvider!.updatePositionsWithCurrentBoard(_board, _givenCells);
        break;

      case 'forceUIUpdate':
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

  void forceUpdatePowerupPositions() {
    if (_isPowerupMode && _powerupProvider != null) {
      print('🔄 Manually forcing powerup position update');
      _powerupProvider!.updatePositionsWithCurrentBoard(_board, _givenCells);
      notifyListeners();
    }
  }


  void generatePuzzle({
    required int emptyCells,
    GameSettings? gameSettings,
    GameMode gameMode = GameMode.classic,
  }) {
    print('🎲 SudokuProvider: Generating puzzle for mode: $gameMode');

    _gameSettings = gameSettings;
    _currentGameMode = gameMode;
    _isPowerupMode = gameMode == GameMode.powerup;

    if (gameSettings != null) {
      _maxMistakes = gameSettings.allowMistakes ? gameSettings.maxMistakes : 1;
      _hintsRemaining = gameSettings.allowHints ? 3 : 0;
    } else {
      _maxMistakes = 3;
      _hintsRemaining = 3;
    }

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

    _solution = puzzleData['solution'].map<List<int>>((row) =>
        (row as List).cast<int>()).toList();

    final puzzle = puzzleData['puzzle'] as List<List<int>>;
    _board = puzzle.map<List<int?>>((row) =>
        row.map<int?>((cell) => cell == 0 ? null : cell).toList()).toList();

    _givenCells = List.generate(
      9,
          (i) => List.generate(9, (j) => _board[i][j] != null && _board[i][j] != 0),
    );

    _errorCells = List.generate(9, (_) => List.filled(9, false));
    _playerCellEntries = List.generate(9, (_) => List.filled(9, null));
    _mistakesCount = 0;
    _selectedRow = null;
    _selectedCol = null;
    solvedCells = 0;
    _bonusTimeAdded = 0;

    print('✅ SudokuProvider: Puzzle generated. Powerups enabled: $_isPowerupMode');
    notifyListeners();
  }

  void loadPuzzle(
      Map<String, dynamic> puzzleData, {
        GameSettings? gameSettings,
        GameMode gameMode = GameMode.classic,
        bool isRanked = false,
      }) {
    print('📥 SudokuProvider: Loading puzzle for mode: $gameMode');

    _gameSettings = gameSettings;
    _currentGameMode = gameMode;
    _isRankedGame = isRanked;
    _isPowerupMode = gameMode == GameMode.powerup;
    _playerCellEntries = List.generate(9, (_) => List.filled(9, null));

    if (gameSettings != null) {
      _maxMistakes = gameSettings.allowMistakes ? gameSettings.maxMistakes : 1;
      _hintsRemaining = gameSettings.allowHints ? 3 : 0;
    } else {

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

    _errorCells = List.generate(9, (_) => List.filled(9, false));
    _playerCellEntries = List.generate(9, (_) => List.filled(9, null));
    _mistakesCount = 0;
    _selectedRow = null;
    _selectedCol = null;
    solvedCells = 0;
    _bonusTimeAdded = 0;

    print('✅ SudokuProvider: Puzzle loaded. Powerups enabled: $_isPowerupMode');
    notifyListeners();
  }

  void selectCell(int row, int col) {
    if (!_givenCells[row][col]) {
      _selectedRow = row;
      _selectedCol = col;
      notifyListeners();
    }
  }

  void handleNumberInput(int number) {
    if (_selectedRow == null || _selectedCol == null) return;
    int row = _selectedRow!;
    int col = _selectedCol!;

    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (!_givenCells[row][col]) {
      if (_isPowerupMode && _powerupProvider?.isFrozen == true) {
        print('❄️ Player is frozen, cannot input numbers');
        return;
      }

      int? previousValue = _board[row][col];
      bool wasPreviousCorrect = previousValue != null && previousValue == _solution[row][col];

      _board[row][col] = number;

      bool isCorrect = number == _solution[row][col];

      if (isCorrect) {
        _errorCells[row][col] = false;
        if (!wasPreviousCorrect) {
          solvedCells++;

          if (_isPowerupMode) {
            _powerupProvider?.attemptClaimPowerup(row, col);
          }
        }
      } else {
        if (_gameSettings?.allowMistakes ?? true) {
          _errorCells[row][col] = true;

          if (_currentGameMode == GameMode.coop) {
            if (_lobbyId != null) {
              LobbyService.incrementSharedMistakes(_lobbyId!);
            }
          } else {
            _mistakesCount++;
          }

        } else {
          _errorCells[row][col] = true;
        }

        if (wasPreviousCorrect) {
          solvedCells--;
        }
      }

      if (_currentGameMode == GameMode.coop) {
        _playerCellEntries[row][col] = userId;

        if (_lobbyId != null) {
          LobbyService.sendCoOpMove(_lobbyId!, row, col, number);
        }
      }

      if (_isPowerupMode && _powerupProvider != null) {
        print('🔄 Recalculating powerup positions after move...');
        Future.microtask(() {
          _powerupProvider!.updatePositionsWithCurrentBoard(_board, _givenCells);
        });
      }

      _internalCheckEndGameConditions();

      notifyListeners();

      if (!isCorrect && _isRankedGame) {
        if (_mistakesCount >= _maxMistakes) {
          onRankedGameLost?.call();
        }
      }
    }
  }

  int applyBombEffect(Map<String, dynamic> bombData) {
    if (bombData['startRow'] == null || bombData['startCol'] == null) {
      return 0;
    }

    final int startRow = bombData['startRow'];
    final int startCol = bombData['startCol'];
    int cellsCleared = 0;

    print('💣 Applying bomb effect at ($startRow, $startCol)');

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        final row = startRow + i;
        final col = startCol + j;

        if (row < 9 && col < 9) {
          if (!_givenCells[row][col] && _board[row][col] != null) {

            if (_board[row][col] == _solution[row][col]) {
              solvedCells--;
            }

            _board[row][col] = null;
            _errorCells[row][col] = false;
            cellsCleared++;
          }
        }
      }
    }

    if (cellsCleared > 0) {
      print('💣 Cleared $cellsCleared cells.');
      notifyListeners();
    }

    return cellsCleared;
  }

  void applyRevealCellPowerup() {
    print('🔍 Applying reveal cell powerup');

    final emptyCells = <Map<String, int>>[];
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (!_givenCells[i][j] && (_board[i][j] == null || _board[i][j] == 0)) {
          emptyCells.add({'row': i, 'col': j});
        }
      }
    }

    if (emptyCells.isNotEmpty) {
      final cellsToReveal = min(2, emptyCells.length);
      final Random random = Random();

      for (int k = 0; k < cellsToReveal; k++) {
        if (emptyCells.isEmpty) break;

        final randomIndex = random.nextInt(emptyCells.length);
        final randomCell = emptyCells.removeAt(randomIndex);
        final row = randomCell['row']!;
        final col = randomCell['col']!;

        _board[row][col] = _solution[row][col];
        _errorCells[row][col] = false;
        solvedCells++;

        print('🔍 Revealed cell at ($row, $col) = ${_solution[row][col]}');
      }

      notifyListeners();
      print('✅ Revealed $cellsToReveal cells');
    } else {
      print('⚠️ No empty cells to reveal');
    }
  }

  void applyExtraHintsPowerup() {
    _hintsRemaining += 2;
    notifyListeners();
    print('💡 Added 2 extra hints. Total: $_hintsRemaining');
  }

  void applyClearErrorsPowerup() {
    int errorsCleared = 0;
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (_errorCells[i][j]) {
          _errorCells[i][j] = false;
          _board[i][j] = null;
          errorsCleared++;
        }
      }
    }

    _mistakesCount = 0;


    notifyListeners();
    print('🧹 Cleared $errorsCleared errors and reset mistake count');
  }

  void applyTimeBonusPowerup() {
    _bonusTimeAdded += 60;
    notifyListeners();
    print('⏰ Added 60 seconds to timer. Total bonus: $_bonusTimeAdded');
  }

  bool canUseHint() {
    return _hintsRemaining > 0 &&
        _selectedRow != null &&
        _selectedCol != null &&
        !_givenCells[_selectedRow!][_selectedCol!] &&
        (_gameSettings?.allowHints ?? true) &&
        (!_isPowerupMode || _powerupProvider?.isFrozen != true);
  }

  void useHint() {
    if (!canUseHint()) return;

    final row = _selectedRow!;
    final col = _selectedCol!;
    final correctNumber = _solution[row][col];

    if (_currentGameMode == GameMode.coop) {
      if (_lobbyId != null) {
        LobbyService.useSharedHint(_lobbyId!);
      }
    } else {
      _hintsRemaining--;
    }

    _board[row][col] = correctNumber;
    _errorCells[row][col] = false;

    solvedCells++;

    if (_isPowerupMode) {
      _powerupProvider?.attemptClaimPowerup(row, col);
    }

    if (_currentGameMode == GameMode.coop && _lobbyId != null) {
      LobbyService.sendCoOpMove(_lobbyId!, row, col, correctNumber);
    }

    notifyListeners();

    _internalCheckEndGameConditions();
  }

  void resetHints() {
    _hintsRemaining = (_gameSettings?.allowHints ?? true) ? 3 : 0;
    notifyListeners();
  }

  bool isValidMove(int row, int col, int number) {
    if (_givenCells[row][col]) return false;
    return SudokuEngine.isValidMove(_getCurrentBoard(), row, col, number);
  }

  List<List<int>> _getCurrentBoard() {
    return _board.map((row) =>
        row.map((cell) => cell ?? 0).toList()).toList();
  }

  void applyMove(int row, int col, int number, String playerId) {
    if (!_givenCells[row][col]) {
      int? previousValue = _board[row][col];
      bool wasCorrect = previousValue != null && previousValue == _solution[row][col];

      _board[row][col] = number;
      bool isNowCorrect = number == _solution[row][col];

      if (isNowCorrect && !wasCorrect) {
        solvedCells++;
      } else if (!isNowCorrect && wasCorrect) {
        solvedCells--;
      }

      if (_currentGameMode == GameMode.coop) {
        _playerCellEntries[row][col] = playerId;
      }

      _errorCells[row][col] = !isNowCorrect;
      notifyListeners();
    }

    _internalCheckEndGameConditions();
  }

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


  bool hasPowerupAt(int row, int col) {
    if (!_isPowerupMode) return false;
    return _powerupProvider?.hasPowerupAt(row, col) ?? false;
  }

  Color? getPowerupColor(int row, int col) {
    if (!_isPowerupMode) return null;

    final powerup = _powerupProvider?.getPowerupAt(row, col);
    if (powerup == null) return null;

    return _getColorForPowerupType(powerup.type);
  }

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

  PowerupSpawn? getPowerupAt(int row, int col) {
    if (!_isPowerupMode) return null;
    return _powerupProvider?.getPowerupAt(row, col);
  }

  void updateSharedHints(int? hintCount) {
    if (_currentGameMode == GameMode.coop) {
      if (_hintsRemaining != hintCount && hintCount != null) {
        _hintsRemaining = hintCount;
        notifyListeners();
      }
    }
  }

  void updateSharedMistakes(int? mistakeCount) {
    if (_currentGameMode == GameMode.coop && _mistakesCount != mistakeCount && mistakeCount != null) {
      _mistakesCount = mistakeCount;
      notifyListeners();
    }
  }

  Map<String, int> getPlayerSolveCounts() {
    final Map<String, int> counts = {};
    if (_currentGameMode != GameMode.coop) {
      return counts;
    }

    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        final playerId = _playerCellEntries[i][j];
        if (playerId != null) {
          counts[playerId] = (counts[playerId] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  void _internalCheckEndGameConditions() {
    if (isGameOver) return;
    bool shouldNotify = false;

    if (isSolved) {
      isGameOver = true;
      isGameWon = true;
      shouldNotify = true;
    } else if ((_gameSettings?.allowMistakes ?? true) && _mistakesCount >= maxMistakes) {
      isGameOver = true;
      isGameWon = false;
      shouldNotify = true;
    }
  }

}