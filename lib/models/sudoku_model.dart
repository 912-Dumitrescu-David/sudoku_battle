class SudokuPuzzleModel {
  final List<List<int?>> puzzleBoard;
  final List<List<int>> solutionBoard;
  final List<List<bool>> givenCells;

  SudokuPuzzleModel({
    required this.puzzleBoard,
    required this.solutionBoard,
    required this.givenCells,
  });
}
