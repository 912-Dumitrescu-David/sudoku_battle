import 'dart:math';

enum Difficulty { easy, medium, hard, expert }

class SudokuEngine {
  static const int gridSize = 9;
  static const int boxSize = 3;

  // Generate a complete valid Sudoku grid
  static List<List<int>> generateCompleteGrid() {
    List<List<int>> grid = List.generate(
        gridSize,
            (_) => List.filled(gridSize, 0)
    );

    _fillGrid(grid);
    return grid;
  }

  // Generate a puzzle with given difficulty
  static Map<String, dynamic> generatePuzzle(Difficulty difficulty) {
    List<List<int>> completeGrid = generateCompleteGrid();
    List<List<int>> puzzle = _removeCells(completeGrid, difficulty);

    return {
      'puzzle': puzzle,
      'solution': completeGrid,
      'difficulty': difficulty.toString().split('.').last,
      'id': _generatePuzzleId(),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // Fill grid using backtracking with randomization
  static bool _fillGrid(List<List<int>> grid) {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (grid[row][col] == 0) {
          List<int> numbers = List.generate(9, (i) => i + 1);
          numbers.shuffle(Random());

          for (int num in numbers) {
            if (isValidMove(grid, row, col, num)) {
              grid[row][col] = num;

              if (_fillGrid(grid)) {
                return true;
              }

              grid[row][col] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  // Remove cells to create puzzle based on difficulty
  static List<List<int>> _removeCells(List<List<int>> completeGrid, Difficulty difficulty) {
    List<List<int>> puzzle = completeGrid.map((row) => List<int>.from(row)).toList();

    int cellsToRemove = _getCellsToRemove(difficulty);
    List<List<int>> positions = [];

    // Create list of all positions
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        positions.add([i, j]);
      }
    }

    positions.shuffle(Random());

    int removed = 0;
    for (List<int> pos in positions) {
      if (removed >= cellsToRemove) break;

      int row = pos[0];
      int col = pos[1];
      int backup = puzzle[row][col];

      puzzle[row][col] = 0;

      // Check if puzzle still has unique solution
      if (hasUniqueSolution(puzzle)) {
        removed++;
      } else {
        puzzle[row][col] = backup; // Restore if multiple solutions
      }
    }

    return puzzle;
  }

  // Get number of cells to remove based on difficulty
  static int _getCellsToRemove(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return 35 + Random().nextInt(6); // 35-40 cells removed
      case Difficulty.medium:
        return 41 + Random().nextInt(5); // 41-45 cells removed
      case Difficulty.hard:
        return 46 + Random().nextInt(5); // 46-50 cells removed
      case Difficulty.expert:
        return 51 + Random().nextInt(5); // 51-55 cells removed
    }
  }

  // Validate if a move is legal
  static bool isValidMove(List<List<int>> grid, int row, int col, int num) {
    // Check row
    for (int i = 0; i < gridSize; i++) {
      if (i != col && grid[row][i] == num) {
        return false;
      }
    }

    // Check column
    for (int i = 0; i < gridSize; i++) {
      if (i != row && grid[i][col] == num) {
        return false;
      }
    }

    // Check 3x3 box
    int boxRow = (row ~/ boxSize) * boxSize;
    int boxCol = (col ~/ boxSize) * boxSize;

    for (int i = boxRow; i < boxRow + boxSize; i++) {
      for (int j = boxCol; j < boxCol + boxSize; j++) {
        if ((i != row || j != col) && grid[i][j] == num) {
          return false;
        }
      }
    }

    return true;
  }

  // Check if puzzle has unique solution
  static bool hasUniqueSolution(List<List<int>> puzzle) {
    List<List<List<int>>> solutions = [];
    _solvePuzzle(
        puzzle.map((row) => List<int>.from(row)).toList(),
        solutions,
        2 // Stop after finding 2 solutions
    );
    return solutions.length == 1;
  }

  // Solve puzzle and count solutions
  static void _solvePuzzle(List<List<int>> grid, List<List<List<int>>> solutions, int maxSolutions) {
    if (solutions.length >= maxSolutions) return;

    List<int>? emptyCell = _findEmptyCell(grid);
    if (emptyCell == null) {
      solutions.add(grid.map((row) => List<int>.from(row)).toList());
      return;
    }

    int row = emptyCell[0];
    int col = emptyCell[1];

    for (int num = 1; num <= 9; num++) {
      if (isValidMove(grid, row, col, num)) {
        grid[row][col] = num;
        _solvePuzzle(grid, solutions, maxSolutions);
        grid[row][col] = 0;
      }
    }
  }

  // Find next empty cell
  static List<int>? _findEmptyCell(List<List<int>> grid) {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (grid[row][col] == 0) {
          return [row, col];
        }
      }
    }
    return null;
  }

  // Check if puzzle is complete
  static bool isPuzzleComplete(List<List<int>> grid) {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (grid[row][col] == 0) {
          return false;
        }
      }
    }
    return isValidSudoku(grid);
  }

  // Validate complete Sudoku
  static bool isValidSudoku(List<List<int>> grid) {
    // Check all rows, columns, and boxes
    for (int i = 0; i < gridSize; i++) {
      if (!_isValidUnit(_getRow(grid, i)) ||
          !_isValidUnit(_getColumn(grid, i)) ||
          !_isValidUnit(_getBox(grid, i))) {
        return false;
      }
    }
    return true;
  }

  // Helper methods to get units
  static List<int> _getRow(List<List<int>> grid, int row) {
    return grid[row];
  }

  static List<int> _getColumn(List<List<int>> grid, int col) {
    return List.generate(gridSize, (row) => grid[row][col]);
  }

  static List<int> _getBox(List<List<int>> grid, int boxIndex) {
    List<int> box = [];
    int startRow = (boxIndex ~/ 3) * 3;
    int startCol = (boxIndex % 3) * 3;

    for (int i = startRow; i < startRow + 3; i++) {
      for (int j = startCol; j < startCol + 3; j++) {
        box.add(grid[i][j]);
      }
    }
    return box;
  }

  // Validate a unit (row, column, or box)
  static bool _isValidUnit(List<int> unit) {
    Set<int> seen = {};
    for (int num in unit) {
      if (num != 0) {
        if (seen.contains(num)) {
          return false;
        }
        seen.add(num);
      }
    }
    return true;
  }

  // Generate unique puzzle ID
  static String _generatePuzzleId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(10000).toString().padLeft(4, '0');
  }

  // Get difficulty from string
  static Difficulty getDifficultyFromString(String difficultyStr) {
    switch (difficultyStr.toLowerCase()) {
      case 'easy':
        return Difficulty.easy;
      case 'medium':
        return Difficulty.medium;
      case 'hard':
        return Difficulty.hard;
      case 'expert':
        return Difficulty.expert;
      default:
        return Difficulty.medium;
    }
  }

  // Calculate difficulty score for existing puzzle
  static double calculateDifficultyScore(List<List<int>> puzzle) {
    int emptyCount = 0;
    for (List<int> row in puzzle) {
      for (int cell in row) {
        if (cell == 0) emptyCount++;
      }
    }

    // Simple difficulty calculation based on empty cells
    // Can be enhanced with technique analysis
    return (emptyCount / 81.0) * 100;
  }
}