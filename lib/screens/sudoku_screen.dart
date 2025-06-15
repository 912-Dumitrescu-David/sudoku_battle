// screens/sudoku_screen.dart - UPDATED VERSION with consistent layout
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_battle/providers/sudoku_provider.dart';
import 'package:sudoku_battle/screens/result_screen.dart';
import 'package:sudoku_battle/widgets/sudoku_board.dart';
import 'package:sudoku_battle/widgets/number_keypad.dart';
import 'package:sudoku_battle/models/lobby_model.dart';

import '../providers/theme_provider.dart';

import 'package:sudoku_battle/widgets/mistake_counter.dart';
import 'package:sudoku_battle/widgets/timer.dart';
import 'package:sudoku_battle/widgets/correct_counter.dart';
import 'package:sudoku_battle/widgets/hint_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SudokuScreen extends StatefulWidget {
  final String difficulty;
  final int emptyCells;
  final bool allowHints;
  final bool allowMistakes;
  final int maxMistakes;

  const SudokuScreen({
    Key? key,
    required this.difficulty,
    required this.emptyCells,
    this.allowHints = true,
    this.allowMistakes = true,
    this.maxMistakes = 3,
  }) : super(key: key);

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _formattedTime = "00:00";
  late Offset _hintButtonOffset;

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
      // Initialize hint button position
      final screenWidth = MediaQuery.of(context).size.width;
      setState(() {
        _hintButtonOffset = Offset(screenWidth * 0.85, 130);
      });

      // Create game settings using the parameters passed from difficulty screen
      final gameSettings = GameSettings(
        timeLimit: null,
        // No time limit for classic mode
        allowHints: widget.allowHints,
        allowMistakes: widget.allowMistakes,
        maxMistakes: widget.maxMistakes,
        difficulty: widget.difficulty.toLowerCase(),
      );

      // 🔥 FIXED: Pass GameMode.classic to ensure no powerups in single player
      Provider.of<SudokuProvider>(context, listen: false)
          .generatePuzzle(
        emptyCells: widget.emptyCells,
        gameSettings: gameSettings,
        gameMode: GameMode.classic, // 🔥 Explicitly set to classic mode
      );
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

  void _resetGame() {
    final sudokuProvider = Provider.of<SudokuProvider>(context, listen: false);

    // Create game settings using the current widget parameters
    final gameSettings = GameSettings(
      timeLimit: null,
      allowHints: widget.allowHints,
      allowMistakes: widget.allowMistakes,
      maxMistakes: widget.maxMistakes,
      difficulty: widget.difficulty.toLowerCase(),
    );

    // 🔥 FIXED: Pass GameMode.classic to ensure no powerups
    sudokuProvider.generatePuzzle(
      emptyCells: widget.emptyCells,
      gameSettings: gameSettings,
      gameMode: GameMode.classic, // 🔥 Explicitly set to classic mode
    );

    _stopwatch.reset();
    _stopwatch.start();
    sudokuProvider.resetMistakes();
    sudokuProvider.resetSolvedCells();
    sudokuProvider.resetHints();
  }

  Widget _buildHintButton() {
    return Consumer<SudokuProvider>(
      builder: (context, provider, child) {
        final canUseHint = provider.canUseHint();
        final hintsRemaining = provider.hintsRemaining;

        return GestureDetector(
          onTap: canUseHint ? () => provider.useHint() : null,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: canUseHint ? Colors.amber[600] : Colors.grey[300],
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(2, 2)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lightbulb, size: 20, color: canUseHint ? Colors.white : Colors.grey[600]),
                const SizedBox(height: 4),
                Text(
                  '$hintsRemaining',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: canUseHint ? Colors.white : Colors.grey[700]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Classic Mode - ${widget.difficulty}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Puzzle',
            onPressed: _resetGame,
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
          // 🔥 FIXED: Debug check to ensure powerups are disabled
          print('🔍 Single player mode - Powerups enabled: ${provider
              .isPowerupModeEnabled}');

          // Check end game conditions.
          if (provider.mistakesCount >= provider.maxMistakes) {
            Future.microtask(() {
              _stopGame();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ResultScreen(
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
                    builder: (_) =>
                        ResultScreen(
                            isWin: true,
                            time: _formattedTime,
                            solvedBlocks: provider.solved,
                            totalToSolve: widget.emptyCells)),
              );
            });
          }

          return Stack(
            children: [
              // Main content
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWeb = kIsWeb;
                  final statsHeight = 60.0;
                  final keypadHeight = isWeb ? 120.0 : 100.0;

                  return Column(
                    children: [
                      // Game stats row (same as multiplayer)
                      Container(
                        height: statsHeight,
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: FractionallySizedBox(
                          widthFactor: 0.9,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Mistakes counter
                              SizedBox(
                                width: 80,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SudokuMistakesCounter(
                                    mistakes: provider.mistakesCount,
                                    maxMistakes: provider.maxMistakes,
                                  ),
                                ),
                              ),

                              // Timer in the center
                              SudokuTimerDisplay(
                                time: _formattedTime,
                              ),

                              // Correct counter
                              SizedBox(
                                width: 80,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SudokuCorrectCounter(
                                    solved: provider.solved,
                                    totalToSolve: widget.emptyCells,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Sudoku board (expanded to fill available space)
                      Expanded(
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SudokuBoard(),
                        ),
                      ),

                      // Divider
                      const Divider(),

                      // Number keypad
                      SizedBox(
                        height: keypadHeight,
                        child: const NumberKeypad(),
                      ),
                    ],
                  );
                },
              ),

              // Floating hint button (only show if hints are enabled)
              if (widget.allowHints && provider.hintsRemaining > 0)
                Positioned(
                  left: _hintButtonOffset.dx,
                  top: _hintButtonOffset.dy,
                  child: Draggable(
                    feedback: _buildHintButton(),
                    childWhenDragging: Opacity(
                      opacity: 0.4,
                      child: _buildHintButton(),
                    ),
                    onDragEnd: (details) {
                      setState(() {
                        _hintButtonOffset = Offset(
                          details.offset.dx.clamp(0, MediaQuery.of(context).size.width - 60),
                          details.offset.dy.clamp(0, MediaQuery.of(context).size.height - 60),
                        );
                      });
                    },
                    child: _buildHintButton(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}