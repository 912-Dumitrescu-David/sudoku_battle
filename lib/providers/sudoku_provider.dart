import 'package:flutter/material.dart';
import '../utils/sudoku_engine.dart';

class SudokuProvider extends ChangeNotifier {
  late List<List<int?>> _board;
  late List<List<int>> _solution;
  late List<List<bool>> _givenCells;
  late List<List<bool>> _errorCells;

  int? _selectedRow;
  int? _selectedCol;

  int _mistakesCount = 0;
  int get mistakesCount => _mistakesCount;

  // Define maximum mistakes allowed (you can adjust this)
  final int maxMistakes = 3;
  int solvedCells = 0;

  SudokuProvider() {
    _board = List.generate(9, (_) => List.filled(9, null));
    _solution = List.generate(9, (_) => List.filled(9, 0));
    _givenCells = List.generate(9, (_) => List.filled(9, false));
    _errorCells = List.generate(9, (_) => List.filled(9, false));
  }

  List<List<int?>> get board => _board;
  List<List<bool>> get givenCells => _givenCells;
  List<List<bool>> get errorCells => _errorCells;
  int? get selectedRow => _selectedRow;
  int? get selectedCol => _selectedCol;
  int get mistakes => _mistakesCount;
  int get solved => solvedCells;

  /// Generate a new puzzle using our custom SudokuEngine
  void generatePuzzle({required int emptyCells}) {
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
    notifyListeners();
  }

  /// Generate puzzle from existing puzzle data (for multiplayer)
  void loadPuzzle(Map<String, dynamic> puzzleData) {
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

  /// Handle user number input with validation
  void handleNumberInput(int number) {
    if (_selectedRow == null || _selectedCol == null) return;
    int row = _selectedRow!;
    int col = _selectedCol!;

    if (!_givenCells[row][col]) {
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
        }
      } else {
        // Wrong input
        _errorCells[row][col] = true;
        _mistakesCount++;
        if (wasPreviousCorrect) {
          solvedCells--;
        }
      }

      notifyListeners();
    }
  }

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
}