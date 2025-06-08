// screens/multiplayer_sudoku_screen.dart - FIXED LAYOUT VERSION
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/powerup_model.dart';
import '../providers/sudoku_provider.dart';
import '../providers/powerup_provider.dart';
import '../providers/theme_provider.dart';
import '../models/lobby_model.dart';
import '../widgets/powerup_ui_widget.dart';
import '../widgets/sudoku_board.dart';
import '../widgets/number_keypad.dart';
import '../widgets/mistake_counter.dart';
import '../widgets/correct_counter.dart';
import '../widgets/hint_widget.dart';
import '../widgets/game_timer_widget.dart';
import '../screens/multiplayer_result_screen.dart';
import '../services/game_state_service.dart';
import '../services/powerup_service.dart';
import '../widgets/powerup_bar_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MultiplayerSudokuScreen extends StatefulWidget {
  final Lobby lobby;
  final Map<String, dynamic> puzzle;

  const MultiplayerSudokuScreen({
    Key? key,
    required this.lobby,
    required this.puzzle,
  }) : super(key: key);

  @override
  State<MultiplayerSudokuScreen> createState() => _MultiplayerSudokuScreenState();
}

class _MultiplayerSudokuScreenState extends State<MultiplayerSudokuScreen> {
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _formattedTime = "00:00";
  bool _gameStarted = false;
  bool _gameEnded = false;
  double _lastProgress = 0.0;
  bool _timeUp = false;
  late Offset _hintButtonOffset;

  // Powerup notifications
  List<Widget> _powerupNotifications = [];

  // Opponent tracking
  Map<String, PlayerGameState> _opponentStates = {};
  StreamSubscription? _gameStatesSubscription;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_gameStarted && !_gameEnded) {
        setState(() {
          final elapsed = _stopwatch.elapsed;
          final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
          final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
          _formattedTime = '$minutes:$seconds';
        });
      }
    });

    // Initialize opponent states
    for (final player in widget.lobby.playersList) {
      if (player.id != FirebaseAuth.instance.currentUser?.uid) {
        _opponentStates[player.id] = PlayerGameState(
          playerId: player.id,
          playerName: player.name,
          isCompleted: false,
          completionTime: '00:00',
          solvedCells: 0,
          totalCells: _calculateTotalToSolve(),
          mistakes: 0,
          finishedAt: 0,
          progress: 0.0,
        );
      }
    }

    // Listen to game states
    _gameStatesSubscription = GameStateService.getGameStates(widget.lobby.id).listen((gameStates) {
      setState(() {
        for (final gameState in gameStates) {
          if (gameState.playerId != FirebaseAuth.instance.currentUser?.uid) {
            _opponentStates[gameState.playerId] = gameState;
          }
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sudokuProvider = Provider.of<SudokuProvider>(context, listen: false);
      final powerupProvider = Provider.of<PowerupProvider>(context, listen: false);

      final screenWidth = MediaQuery.of(context).size.width;
      setState(() {
        // Position the hint button near the right side, ~80% of screen width
        _hintButtonOffset = Offset(screenWidth * 0.85, 130);
      });

      // 🔥 FIXED: Initialize powerup system ONLY for powerup game mode
      if (widget.lobby.gameMode == GameMode.powerup) {
        print('🔮 Initializing powerups for powerup mode');
        powerupProvider.initialize(widget.lobby.id);
        sudokuProvider.initializePowerups(powerupProvider);

        // 🔥 FIXED: Set up the callback for powerup effects
        powerupProvider.setSudokuProviderCallback((effectType) {
          _applyPowerupEffectToSudoku(effectType, sudokuProvider);
        });
      } else {
        print('⚠️ Classic mode - powerups disabled');
      }

      // 🔥 FIXED: Load the puzzle with game mode information
      sudokuProvider.loadPuzzle(
        widget.puzzle,
        gameSettings: widget.lobby.gameSettings,
        gameMode: widget.lobby.gameMode, // Pass the game mode
      );

      // Start the game after a short delay
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _gameStarted = true;
          });
          _stopwatch.start();
        }
      });
    });
  }

  // 🔥 NEW: Apply powerup effects to SudokuProvider
  void _applyPowerupEffectToSudoku(String effectType, SudokuProvider sudokuProvider) {
    print('⚡ Applying powerup effect: $effectType');

    switch (effectType) {
      case 'revealTwoCells':
        sudokuProvider.applyRevealCellPowerup();
        break;
      case 'extraHints':
        sudokuProvider.applyExtraHintsPowerup();
        break;
      case 'clearMistakes':
        sudokuProvider.applyClearErrorsPowerup();
        break;
      case 'timeBonus':
        sudokuProvider.applyTimeBonusPowerup();
        break;
      default:
        print('⚠️ Unknown powerup effect type: $effectType');
    }
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _timer.cancel();
    _gameStatesSubscription?.cancel();
    super.dispose();
  }

  void _stopGame() {
    _stopwatch.stop();
    _timer.cancel();
    setState(() {
      _gameEnded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SudokuProvider, PowerupProvider>(
      builder: (context, sudokuProvider, powerupProvider, child) {
        // Update progress tracking
        if (sudokuProvider.progress != _lastProgress) {
          _lastProgress = sudokuProvider.progress;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateMyProgress(sudokuProvider.progress);
          });
        }

        // Check end game conditions
        if (!_gameEnded) {
          if (sudokuProvider.mistakesCount >= sudokuProvider.maxMistakes) {
            Future.microtask(() async {
              _stopGame();
              await _handleGameEnd(false, sudokuProvider);
            });
          } else if (sudokuProvider.isSolved) {
            Future.microtask(() async {
              _stopGame();
              await _handleGameEnd(true, sudokuProvider);
            });
          } else if (_timeUp) {
            Future.microtask(() async {
              _stopGame();
              await _handleGameEnd(false, sudokuProvider, timeUp: true);
            });
          }
        }

        if (!_gameStarted) {
          return _buildWaitingScreen();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.lobby.gameMode == GameMode.powerup ? "Powerup" : "Multiplayer"} Sudoku - ${widget.lobby.gameSettings.difficulty.toUpperCase()}'),
            backgroundColor: widget.lobby.gameMode == GameMode.powerup ? Colors.purple : Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(Icons.people),
                onPressed: _showPlayersList,
              ),
            ],
          ),
          body: Stack(
            children: [
              // 🔥 FIXED: Better layout structure for web and mobile
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWeb = kIsWeb;
                  final screenHeight = constraints.maxHeight;

                  // Calculate heights based on platform
                  final progressHeight = 80.0;
                  final statsHeight = 60.0;
                  final powerupBarHeight = widget.lobby.gameMode == GameMode.powerup ?
                  (isWeb ? 100.0 : 80.0) : 0.0;
                  final keypadHeight = isWeb ? 120.0 : 100.0;

                  final availableHeight = screenHeight - progressHeight - statsHeight - powerupBarHeight - keypadHeight;

                  return Column(
                    children: [
                      // Progress section
                      SizedBox(
                        height: progressHeight,
                        child: Column(
                          children: [
                            _buildOpponentProgress(),
                            _buildMyProgress(sudokuProvider.progress),
                          ],
                        ),
                      ),

                      // Stats section
                      Container(
                        height: statsHeight,
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: FractionallySizedBox(
                          widthFactor: 0.9,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: 80,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SudokuMistakesCounter(
                                    mistakes: sudokuProvider.mistakesCount,
                                    maxMistakes: sudokuProvider.maxMistakes,
                                  ),
                                ),
                              ),
                              GameTimerWidget(
                                timeLimitSeconds: widget.lobby.gameSettings.timeLimit,
                                isGameActive: _gameStarted && !_gameEnded,
                                bonusSeconds: sudokuProvider.bonusTimeAdded,
                                onTimeUp: () => setState(() => _timeUp = true),
                                onTimeUpdate: (timeStr) => setState(() => _formattedTime = timeStr),
                              ),
                              SizedBox(
                                width: 80,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SudokuCorrectCounter(
                                    solved: sudokuProvider.solved,
                                    totalToSolve: _calculateTotalToSolve(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Sudoku board
                      Container(
                        height: availableHeight,
                        padding: const EdgeInsets.all(8.0),
                        child: SudokuBoard(),
                      ),

                      // 🔥 FIXED: Powerup bar with proper spacing
                      if (widget.lobby.gameMode == GameMode.powerup)
                        Container(
                          height: powerupBarHeight,
                          child: PowerupBar(),
                        ),

                      // 🔥 FIXED: Number keypad with consistent height
                      Container(
                        height: keypadHeight,
                        child: const NumberKeypad(),
                      ),
                    ],
                  );
                },
              ),

              // 🔥 FIXED: Hint button only if hints are enabled
              if (widget.lobby.gameSettings.allowHints)
                Positioned(
                  left: _hintButtonOffset.dx,
                  top: _hintButtonOffset.dy,
                  child: Draggable(
                    feedback: _buildHintButton(),
                    childWhenDragging: Opacity(opacity: 0.4, child: _buildHintButton()),
                    onDragEnd: (details) {
                      setState(() {
                        _hintButtonOffset = details.offset;
                      });
                    },
                    child: _buildHintButton(),
                  ),
                ),
              ..._powerupNotifications,
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleGameEnd(bool isWin, SudokuProvider provider, {bool timeUp = false}) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    print('🏁 Game ended! Win: $isWin, TimeUp: $timeUp');
    print('🎮 Lobby is ranked: ${widget.lobby.isRanked}');
    print('👤 Current user: ${currentUser?.displayName ?? currentUser?.uid}');

    // Update game state
    await GameStateService.updatePlayerGameStatus(
      widget.lobby.id,
      isCompleted: isWin,
      completionTime: _formattedTime,
      solvedCells: provider.solved,
      totalCells: _calculateTotalToSolve(),
      mistakes: provider.mistakesCount,
    );

    if (isWin) {
      // Small delay for Firestore transaction
      await Future.delayed(Duration(milliseconds: 500));

      // Get game result to determine placement and winner info
      final gameResult = await GameStateService.getGameResult(
          widget.lobby.id,
          currentUser?.uid ?? ''
      );

      print('🏆 Game Result: ${gameResult}');

      final opponentStillPlaying = _opponentStates.values
          .any((state) => !state.isCompleted);

      // For ranked games, we want to know who actually won
      String? actualWinnerName;
      bool isFirstPlace = true;

      if (widget.lobby.isRanked) {
        // In ranked games, determine the actual winner
        if (gameResult['isFirstPlace'] == true) {
          actualWinnerName = currentUser?.displayName ?? 'You';
          isFirstPlace = true;
          print('🥇 You got FIRST PLACE in ranked match!');
        } else {
          actualWinnerName = gameResult['winnerName'];
          isFirstPlace = false;
          print('🥈 You got SECOND PLACE in ranked match. Winner: $actualWinnerName');
        }
      } else {
        // Casual games
        actualWinnerName = gameResult['winnerName'] ?? currentUser?.displayName ?? 'You';
        isFirstPlace = gameResult['isFirstPlace'] ?? true;
      }

      print('🏆 Navigating to result screen with:');
      print('   isWin: true');
      print('   isFirstPlace: $isFirstPlace');
      print('   winnerName: $actualWinnerName');
      print('   lobby.isRanked: ${widget.lobby.isRanked}');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerResultScreen(
            isWin: true,
            time: _formattedTime,
            solvedBlocks: provider.solved,
            totalToSolve: _calculateTotalToSolve(),
            lobby: widget.lobby,
            winnerName: actualWinnerName,
            isOpponentStillPlaying: opponentStillPlaying,
            isFirstPlace: isFirstPlace,
          ),
        ),
      );
    } else {
      // Loss or time up
      final opponentStillPlaying = _opponentStates.values
          .any((state) => !state.isCompleted);

      // For losses, we need to determine who actually won
      String? actualWinnerName;

      if (widget.lobby.isRanked && !opponentStillPlaying) {
        // Check who won the ranked match
        final gameResult = await GameStateService.getGameResult(
            widget.lobby.id,
            currentUser?.uid ?? ''
        );
        actualWinnerName = gameResult['winnerName'];
        print('💔 You LOST the ranked match. Winner: $actualWinnerName');
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerResultScreen(
            isWin: false,
            time: _formattedTime,
            solvedBlocks: provider.solved,
            totalToSolve: _calculateTotalToSolve(),
            lobby: widget.lobby,
            winnerName: actualWinnerName,
            isOpponentStillPlaying: opponentStillPlaying,
            isFirstPlace: false,
          ),
        ),
      );
    }
  }

  Widget _buildMyProgress(double progress) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.blue.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.person, color: Colors.blue, size: 16),
          SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              'You',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          SizedBox(width: 8),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _updateMyProgress(double progress) {
    GameStateService.updatePlayerGameStatus(
      widget.lobby.id,
      isCompleted: false,
      completionTime: _formattedTime,
      solvedCells: Provider.of<SudokuProvider>(context, listen: false).solved,
      totalCells: _calculateTotalToSolve(),
      mistakes: Provider.of<SudokuProvider>(context, listen: false).mistakesCount,
    );
  }

  Widget _buildWaitingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            '${widget.lobby.gameMode == GameMode.powerup ? "Powerup " : ""}Game Starting Soon...',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(widget.lobby.gameMode == GameMode.powerup
              ? 'Get ready to collect powerups and solve!'
              : 'Get ready to solve!'),
          SizedBox(height: 20),
          _buildPlayersList(),
        ],
      ),
    );
  }

  Widget _buildOpponentProgress() {
    if (_opponentStates.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._opponentStates.values.map((opponent) =>
              _buildOpponentProgressItem(opponent)),
        ],
      ),
    );
  }

  Widget _buildOpponentProgressItem(PlayerGameState opponent) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(
            opponent.isCompleted ? Icons.check_circle : Icons.circle,
            color: opponent.isCompleted ? Colors.green : Colors.blue,
            size: 12,
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              opponent.playerName,
              style: TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: opponent.progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                opponent.isCompleted ? Colors.green : Colors.blue,
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(
            opponent.isCompleted
                ? 'Done!'
                : '${(opponent.progress * 100).toInt()}%',
            style: TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Players in Game',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ...widget.lobby.playersList.map((player) =>
                ListTile(
                  leading: CircleAvatar(
                    child: Text(player.name[0].toUpperCase()),
                  ),
                  title: Text(player.name),
                  subtitle: Text('Rating: ${player.rating}'),
                  trailing: Icon(Icons.check_circle, color: Colors.green),
                )),
          ],
        ),
      ),
    );
  }

  void _showPlayersList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Players'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.lobby.playersList.map((player) =>
              ListTile(
                leading: CircleAvatar(
                  child: Text(player.name[0].toUpperCase()),
                ),
                title: Text(player.name),
                subtitle: Text('Rating: ${player.rating}'),
              )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  int _calculateTotalToSolve() {
    int count = 0;
    final puzzle = widget.puzzle['puzzle'] as List<List<int>>;
    for (final row in puzzle) {
      for (final cell in row) {
        if (cell == 0) count++;
      }
    }
    return count;
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lightbulb,
                  size: 20,
                  color: canUseHint ? Colors.white : Colors.grey[600],
                ),
                SizedBox(height: 4),
                Text(
                  '$hintsRemaining',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: canUseHint ? Colors.white : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}