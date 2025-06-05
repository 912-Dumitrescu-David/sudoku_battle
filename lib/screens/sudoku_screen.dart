import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_battle/providers/sudoku_provider.dart';
import 'package:sudoku_battle/screens/result_screen.dart';
import 'package:sudoku_battle/widgets/sudoku_board.dart';
import 'package:sudoku_battle/widgets/number_keypad.dart';

import '../providers/theme_provider.dart';

import 'package:sudoku_battle/widgets/mistake_counter.dart';
import 'package:sudoku_battle/widgets/timer.dart';
import 'package:sudoku_battle/widgets/correct_counter.dart';

class SudokuScreen extends StatefulWidget {
  final String difficulty;
  final int emptyCells;

  const SudokuScreen({
    Key? key,
    required this.difficulty,
    required this.emptyCells,
  }) : super(key: key);

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _formattedTime = "00:00";

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        final elapsed = _stopwatch.elapsed;
        final minutes =
            elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
        final seconds =
            elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
        _formattedTime = '$minutes:$seconds';
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SudokuProvider>(context, listen: false)
          .generatePuzzle(emptyCells: widget.emptyCells);
    });
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _timer.cancel();
    super.dispose();
  }

  void _stopGame() {
    _stopwatch.stop();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final sudokuProvider = Provider.of<SudokuProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text('Classic Mode - ${widget.difficulty}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Puzzle',
            onPressed: () {
              sudokuProvider.generatePuzzle(emptyCells: widget.emptyCells);
              _stopwatch.reset();
              sudokuProvider.resetMistakes();
              sudokuProvider.resetSolvedCells();
            },
          ),
          IconButton(
            icon: Icon(Icons.brightness_6),
            tooltip: 'Toggle theme',
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
        ],
      ),
      body: Consumer<SudokuProvider>(
        builder: (context, provider, child) {
          // Check end game conditions.
          if (provider.mistakesCount >= provider.maxMistakes) {
            Future.microtask(() {
              _stopGame();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => ResultScreen(
                        isWin: false,
                        time: _formattedTime,
                        solvedBlocks: provider.solved,
                        totalToSolve: widget.emptyCells)),
              );
            });
          } else if (provider.isSolved) {
            Future.microtask(() {
              _stopGame();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => ResultScreen(
                        isWin: true,
                        time: _formattedTime,
                        solvedBlocks: provider.solved,
                        totalToSolve: widget.emptyCells)),
              );
            });
          }

          return Column(
            children: [
              SudokuMistakesCounter(
                mistakes: provider.mistakesCount,
                maxMistakes: provider.maxMistakes,
              ),
              SudokuTimerDisplay(
                time: _formattedTime,
              ),
              SudokuCorrectCounter(
                solved: provider.solved,
                totalToSolve: widget.emptyCells,
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
