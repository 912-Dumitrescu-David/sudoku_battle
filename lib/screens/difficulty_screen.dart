import 'package:flutter/material.dart';
import 'sudoku_screen.dart';

class DifficultyScreen extends StatelessWidget {
  const DifficultyScreen({Key? key}) : super(key: key);

  // Define empty cells count for each difficulty.
  int _emptyCellsCount(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return 40; // fewer empty cells = easier puzzle
      case 'Medium':
        return 50;
      case 'Hard':
        return 54;
      default:
        return 50;
    }
  }

  void _startGame(BuildContext context, String difficulty) {
    int emptyCells = _emptyCellsCount(difficulty);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SudokuScreen(
          difficulty: difficulty,
          emptyCells: emptyCells,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Difficulty'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _startGame(context, 'Easy'),
              child: const Text('Easy'),
            ),
            ElevatedButton(
              onPressed: () => _startGame(context, 'Medium'),
              child: const Text('Medium'),
            ),
            ElevatedButton(
              onPressed: () => _startGame(context, 'Hard'),
              child: const Text('Hard'),
            ),
          ],
        ),
      ),
    );
  }
}
