import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/sudoku_provider.dart';
import '../providers/theme_provider.dart';
import '../models/lobby_model.dart';
import '../widgets/sudoku_board.dart';
import '../widgets/number_keypad.dart';
import '../widgets/mistake_counter.dart';
import '../widgets/correct_counter.dart';
import '../widgets/hint_widget.dart';
import '../widgets/game_timer_widget.dart';
import '../screens/multiplayer_result_screen.dart';
import '../services/game_state_service.dart';

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
      // Load the puzzle with game settings
      Provider.of<SudokuProvider>(context, listen: false).loadPuzzle(
        widget.puzzle,
        gameSettings: widget.lobby.gameSettings,
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Multiplayer Sudoku - ${widget.lobby.gameSettings.difficulty.toUpperCase()}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.people),
            onPressed: _showPlayersList,
          ),
        ],
      ),
      body: Consumer<SudokuProvider>(
        builder: (context, provider, child) {
          // Update progress tracking
          if (provider.progress != _lastProgress) {
            _lastProgress = provider.progress;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateMyProgress(provider.progress);
            });
          }

          // Check end game conditions
          if (!_gameEnded) {
            if (provider.mistakesCount >= provider.maxMistakes) {
              Future.microtask(() async {
                _stopGame();
                await _handleGameEnd(false, provider);
              });
            } else if (provider.isSolved) {
              Future.microtask(() async {
                _stopGame();
                await _handleGameEnd(true, provider);
              });
            } else if (_timeUp) {
              Future.microtask(() async {
                _stopGame();
                await _handleGameEnd(false, provider, timeUp: true);
              });
            }
          }

          if (!_gameStarted) {
            return _buildWaitingScreen();
          }

          return Column(
            children: [
              _buildOpponentProgress(),
              _buildMyProgress(provider.progress),

              // Game timer with lobby settings
              GameTimerWidget(
                timeLimitSeconds: widget.lobby.gameSettings.timeLimit,
                isGameActive: _gameStarted && !_gameEnded,
                onTimeUp: () {
                  setState(() {
                    _timeUp = true;
                  });
                },
                onTimeUpdate: (timeStr) {
                  setState(() {
                    _formattedTime = timeStr;
                  });
                },
              ),

              SudokuMistakesCounter(
                mistakes: provider.mistakesCount,
                maxMistakes: provider.maxMistakes,
              ),

              SudokuCorrectCounter(
                solved: provider.solved,
                totalToSolve: _calculateTotalToSolve(),
              ),

              // Hint widget (only if hints are enabled)
              if (widget.lobby.gameSettings.allowHints)
                SudokuHintWidget(),

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

  Future<void> _handleGameEnd(bool isWin, SudokuProvider provider, {bool timeUp = false}) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    print('🏁 Game ended! Win: $isWin, TimeUp: $timeUp');

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

      // Get game result to determine placement
      final gameResult = await GameStateService.getGameResult(
          widget.lobby.id,
          currentUser?.uid ?? ''
      );

      print('🏆 Game Result: ${gameResult}');

      final opponentStillPlaying = _opponentStates.values
          .any((state) => !state.isCompleted);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerResultScreen(
            isWin: true,
            time: _formattedTime,
            solvedBlocks: provider.solved,
            totalToSolve: _calculateTotalToSolve(),
            lobby: widget.lobby,
            winnerName: gameResult['winnerName'] ?? currentUser?.displayName ?? 'You',
            isOpponentStillPlaying: opponentStillPlaying,
            isFirstPlace: gameResult['isFirstPlace'] ?? true,
          ),
        ),
      );
    } else {
      // Loss or time up
      final opponentStillPlaying = _opponentStates.values
          .any((state) => !state.isCompleted);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerResultScreen(
            isWin: false,
            time: _formattedTime,
            solvedBlocks: provider.solved,
            totalToSolve: _calculateTotalToSolve(),
            lobby: widget.lobby,
            winnerName: null,
            isOpponentStillPlaying: opponentStillPlaying,
          ),
        ),
      );
    }
  }

  Widget _buildMyProgress(double progress) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.person, color: Colors.blue, size: 16),
          SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              'You',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
            'Game Starting Soon...',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text('Get ready to solve!'),
          SizedBox(height: 20),
          _buildPlayersList(),
        ],
      ),
    );
  }

  Widget _buildOpponentProgress() {
    if (_opponentStates.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Opponent Progress',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          ..._opponentStates.values.map((opponent) =>
              _buildOpponentProgressItem(opponent)),
        ],
      ),
    );
  }

  Widget _buildOpponentProgressItem(PlayerGameState opponent) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
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
              style: TextStyle(fontSize: 12),
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
            style: TextStyle(fontSize: 12),
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
}

class CountdownDialog extends StatefulWidget {
  final VoidCallback onCountdownComplete;

  const CountdownDialog({Key? key, required this.onCountdownComplete}) : super(key: key);

  @override
  State<CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<CountdownDialog> {
  int _countdown = 3;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
      });

      if (_countdown <= 0) {
        timer.cancel();
        widget.onCountdownComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Game Starting in',
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 20),
          Text(
            _countdown.toString(),
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}