import 'package:flutter/material.dart';
import 'package:sudoku_solver_generator/sudoku_solver_generator.dart';
import 'package:sudoku_battle/models/sudoku_model.dart';

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

  /// Generate a new puzzle using the sudoku_solver_generator package.
  void generatePuzzle({required int emptyCells}) {
    var generator = SudokuGenerator(emptySquares: emptyCells);
    // Generate a new sudoku puzzle with the desired number of empty cells.
    var puzzle = generator.newSudoku;
    var solution = generator.newSudokuSolved;
    _board = puzzle;
    _solution = solution;
    _givenCells = List.generate(
      9,
          (i) => List.generate(9, (j) => _board[i][j] != null && _board[i][j] != 0),
    );
    // Reset errors and mistakes
    _errorCells = List.generate(9, (_) => List.filled(9, false));
    _mistakesCount = 0;
    _selectedRow = null;
    _selectedCol = null;
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

  /// Handle user number input.
  /// If the number does not match the solution, mark error and increase mistakes.
  void handleNumberInput(int number) {
    if (_selectedRow == null || _selectedCol == null) return;
    int row = _selectedRow!;
    int col = _selectedCol!;
    if (!_givenCells[row][col]) {
      // Always update the board with the new input.
      _board[row][col] = number;
      // Check if the input is correct.
      if (number == _solution[row][col]) {
        // If correct, clear any previous error.
        _errorCells[row][col] = false;
        solvedCells++;
      } else {
        // Wrong input: mark error and increment mistakes.
        _errorCells[row][col] = true;
        _mistakesCount++;
      }
      notifyListeners();
    }
  }


  /// Calculate how many of each number (1-9) are left.
  Map<int, int> calculateNumberCounts() {
    // In a complete Sudoku, each digit 1-9 should appear 9 times.
    Map<int, int> counts = {for (var i = 1; i <= 9; i++) i: 9};

    // Skip cells that are 0 or null.
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
        // If a cell is empty or does not match the solution, it's not solved.
        if (_board[i][j] == null || _board[i][j] == 0 || _board[i][j] != _solution[i][j]) {
          return false;
        }
      }
    }
    return true;
  }

}
