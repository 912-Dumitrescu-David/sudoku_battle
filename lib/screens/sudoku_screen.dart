import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_battle/providers/sudoku_provider.dart';
import 'package:sudoku_battle/widgets/sudoku_board.dart';
import 'package:sudoku_battle/widgets/number_keypad.dart';
import 'fail_screen.dart';
import 'win_screen.dart';

class SudokuScreen extends StatelessWidget {
  final String difficulty;
  final int emptyCells;

  const SudokuScreen({
    Key? key,
    required this.difficulty,
    required this.emptyCells,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Generate puzzle when the screen is built.
    final sudokuProvider = Provider.of<SudokuProvider>(context, listen: false);
    sudokuProvider.generatePuzzle(emptyCells: emptyCells);

    return Scaffold(
      appBar: AppBar(
        title: Text('Classic Mode - $difficulty'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Puzzle',
            onPressed: () {
              sudokuProvider.generatePuzzle(emptyCells: emptyCells);
            },
          ),
        ],
      ),
      body: Consumer<SudokuProvider>(
        builder: (context, provider, child) {
          // Check end game conditions.
          if (provider.mistakesCount >= provider.maxMistakes) {
            Future.microtask(() {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const FailScreen()),
              );
            });
          } else if (provider.isSolved) {
            Future.microtask(() {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WinScreen()),
              );
            });
          }

          return Column(
            children: [
              // Mistakes counter display.
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Mistakes: ${provider.mistakesCount} / ${provider.maxMistakes}',
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SudokuBoard(),
                ),
              ),
              const Divider(),
              Expanded(
                flex: 1,
                child: const NumberKeypad(),
              ),
            ],
          );
        },
      ),
    );
  }
}
