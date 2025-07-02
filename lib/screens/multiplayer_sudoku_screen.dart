import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart';
import '../models/powerup_model.dart';
import '../providers/sudoku_provider.dart';
import '../providers/powerup_provider.dart';
import '../providers/lobby_provider.dart';
import '../providers/theme_provider.dart';
import '../models/lobby_model.dart';
import '../services/lobby_service.dart';
import '../widgets/sudoku_board.dart';
import '../widgets/number_keypad.dart';
import '../widgets/mistake_counter.dart';
import '../widgets/correct_counter.dart';
import '../widgets/hint_widget.dart';
import '../widgets/game_timer_widget.dart';
import '../screens/multiplayer_result_screen.dart';
import '../services/game_state_service.dart';
import '../widgets/powerup_bar_widget.dart';
import '../widgets/powerup_overlays_widget.dart';
import '../widgets/bomb_effect_widget.dart';
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

  PowerupEffect? _activeBombEffect;
  bool _isBombExploding = false;
  int _bombCellsDestroyed = 0;
  final Set<String> _processedEffectIds = {};

  Map<String, PlayerGameState> _opponentStates = {};
  StreamSubscription? _gameStatesSubscription;
  StreamSubscription? _coOpMovesSubscription;
  StreamSubscription? _finalResultSubscription;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _gameStarted && !_gameEnded) {
        setState(() {});
      }
    });

    _initializeOpponentStates();
    _listenToGameStates();

    _listenForFinalResult();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGame();
      if (widget.lobby.gameMode == GameMode.coop) {
        _listenForCoOpMoves();
      }
    });
  }

  void _listenForFinalResult() {
    _finalResultSubscription =
        GameStateService.getFinalGameResultStream(widget.lobby.id).listen((resultDoc) {
          if (resultDoc.exists && mounted && !_gameEnded) {
            _gameEnded = true;
            _stopGame();

            final resultData = resultDoc.data() as Map<String, dynamic>;
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser == null) return;

            final sudokuProvider = context.read<SudokuProvider>();

            // Determine the outcome for the current player
            final isWin = resultData['winnerId'] == currentUser.uid;
            final winnerName = resultData['winnerName'];
            final reason = resultData['reason'] as String?;
            final gameMode = resultData['gameMode'] as String?;
            final isRanked = resultData['isRanked'] as bool? ?? false;

            print('🎮 Final result received:');
            print('   Winner: $winnerName');
            print('   Reason: $reason');
            print('   Game Mode: $gameMode');
            print('   Is Ranked: $isRanked');

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => MultiplayerResultScreen(
                  isWin: isWin,
                  time: _formattedTime,
                  solvedBlocks: sudokuProvider.solved,
                  totalToSolve: _calculateTotalToSolve(),
                  lobby: widget.lobby,
                  winnerName: winnerName,
                  reason: reason,
                  playerSolveCounts: widget.lobby.gameMode == GameMode.coop
                      ? sudokuProvider.getPlayerSolveCounts()
                      : null,
                ),
              ),
            );
          }
        });
  }


  void _initializeOpponentStates() {
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
  }

  void _listenToGameStates() {
    _gameStatesSubscription = GameStateService.getGameStates(widget.lobby.id).listen((gameStates) {
      if (mounted) {
        setState(() {
          for (final gameState in gameStates) {
            if (gameState.playerId != FirebaseAuth.instance.currentUser?.uid) {
              _opponentStates[gameState.playerId] = gameState;
            }
          }
        });
      }
    });
  }

  void _listenForCoOpMoves() {
    final sudokuProvider = context.read<SudokuProvider>();
    final localPlayerId = FirebaseAuth.instance.currentUser?.uid;

    _coOpMovesSubscription = LobbyService.getCoOpMoves(widget.lobby.id).listen((moveData) {
      if (moveData['playerId'] != null && moveData['playerId'] != localPlayerId) {
        sudokuProvider.applyMove(
          moveData['row'],
          moveData['col'],
          moveData['number'],
          moveData['playerId'],
        );
      }
    });
  }

  void _initializeGame() {
    final sudokuProvider = Provider.of<SudokuProvider>(context, listen: false);
    final powerupProvider = Provider.of<PowerupProvider>(context, listen: false);

    sudokuProvider.setLobbyId(widget.lobby.id);

    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _hintButtonOffset = Offset(screenWidth * 0.85, 130);
    });

    if (widget.lobby.gameMode == GameMode.powerup) {
      powerupProvider.initialize(widget.lobby.id);
      sudokuProvider.initializePowerups(powerupProvider);
    }
    // This callback is now used for both ranked and casual games
    sudokuProvider.setGameLostCallback(_handleLocalPlayerLoss);


    sudokuProvider.loadPuzzle(
      widget.puzzle,
      gameSettings: widget.lobby.gameSettings,
      gameMode: widget.lobby.gameMode,
      isRanked: widget.lobby.isRanked,
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _gameStarted = true);
        _stopwatch.start();
        if (widget.lobby.gameMode == GameMode.powerup) {
          powerupProvider.startGame();
        }
      }
    });
  }


  @override
  void dispose() {
    _stopwatch.stop();
    _timer.cancel();
    _gameStatesSubscription?.cancel();
    _coOpMovesSubscription?.cancel();
    _finalResultSubscription?.cancel();
    Provider.of<PowerupProvider>(context, listen: false).dispose();
    super.dispose();
  }
  void _stopGame() {
    _stopwatch.stop();
    _timer.cancel();
    if (mounted) {
      setState(() => _gameEnded = true);
    }
  }

  Future<void> _handleCoOpGameEnd(bool isWin, SudokuProvider provider) async {
    if (_gameEnded) return;
    _stopGame();
    final playerSolveCounts = provider.getPlayerSolveCounts();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerResultScreen(
            isWin: isWin,
            time: _formattedTime,
            solvedBlocks: provider.solved,
            totalToSolve: _calculateTotalToSolve(),
            lobby: widget.lobby,
            playerSolveCounts: playerSolveCounts,
          ),
        ),
      );
    }
  }

  void _triggerLoss(String reason) {
    if (_gameEnded) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final opponent = widget.lobby.playersList.firstWhere((p) => p.id != currentUser.uid);

    GameStateService.endMatch(
      lobbyId: widget.lobby.id,
      winnerId: opponent.id,
      loserId: currentUser.uid,
      reason: reason,
      winnerName: opponent.name,
      loserName: currentUser.displayName ?? 'Player',
    );
  }

  void _handleLocalPlayerLoss() {
    _triggerLoss("Mistakes");
  }

  Future<void> _handleGameEnd(bool isWin, SudokuProvider provider, {bool timeUp = false}) async {
    if (_gameEnded) return;

    // ================== BUG FIX IS HERE ==================
    // The call to _stopGame() has been removed from this function.
    // The game will now only be stopped inside the _listenForFinalResult listener,
    // ensuring both players stop and navigate at the same time.
    // _stopGame(); // <-- THIS LINE WAS REMOVED
    // =====================================================

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await GameStateService.updatePlayerGameStatus(
        widget.lobby.id,
        isCompleted: isWin,
        completionTime: _formattedTime,
        solvedCells: provider.solved,
        totalCells: _calculateTotalToSolve(),
        mistakes: provider.mistakesCount
    );

    if (isWin) {
      final opponent = widget.lobby.playersList.firstWhere((p) => p.id != currentUser.uid);

      await GameStateService.endMatch(
        lobbyId: widget.lobby.id,
        winnerId: currentUser.uid,
        loserId: opponent.id,
        reason: timeUp ? "Timeout" : "Completion",
        winnerName: currentUser.displayName ?? 'Player',
        loserName: opponent.name,
      );
    } else {
      _triggerLoss(timeUp ? "Timeout" : "Mistakes");
    }
  }

  Future<void> _handleAbandonGame() async {
    if (_gameEnded) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await GameStateService.handleForfeit(
        lobbyId: widget.lobby.id,
        forfeitingPlayerId: user.uid,
      );
    } catch (e) {
      print('❌ Error handling forfeit: $e');
      await context.read<LobbyProvider>().leaveLobby();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final currentLobby = context.watch<LobbyProvider>().currentLobby;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        final shouldLeave = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Abandon Game?'),
            content: Text(
              widget.lobby.isRanked
                  ? 'If you leave, you will forfeit the match and lose rating points. This action cannot be undone.'
                  : widget.lobby.gameMode == GameMode.coop
                  ? 'If you leave, your teammate will be left alone to finish the puzzle. Are you sure?'
                  : 'If you leave, your opponent will win by forfeit. Are you sure?',
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton(
                child: Text('Abandon'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );

        if (shouldLeave ?? false) {
          _handleAbandonGame();
        }
      },
      child: Consumer2<SudokuProvider, PowerupProvider>(
        builder: (context, sudokuProvider, powerupProvider, child) {

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (widget.lobby.gameMode == GameMode.coop && currentLobby != null) {
              sudokuProvider.updateSharedHints(currentLobby.sharedHintCount);
              sudokuProvider.updateSharedMistakes(currentLobby.sharedMistakeCount);
            }
            if (sudokuProvider.isGameOver && !_gameEnded) {
              if (widget.lobby.gameMode == GameMode.coop) {
                _handleCoOpGameEnd(sudokuProvider.isGameWon ?? false, sudokuProvider);
              } else {
                _handleGameEnd(sudokuProvider.isGameWon ?? false, sudokuProvider);
              }
            }
            _updateMyProgress();
          });

          if (!_gameStarted) {
            return _buildWaitingScreen();
          }

          return Scaffold(
            appBar: AppBar(
              title: Text('${widget.lobby.gameMode.name.toUpperCase()} Sudoku - ${widget.lobby.gameSettings.difficulty.toUpperCase()}'),
              backgroundColor: widget.lobby.gameMode == GameMode.powerup
                  ? Colors.purple
                  : (widget.lobby.gameMode == GameMode.coop ? Colors.teal : Theme.of(context).primaryColor),
              foregroundColor: Colors.white,
              actions: [
                if (widget.lobby.gameMode == GameMode.powerup)
                  IconButton(icon: const Icon(Icons.info_outline), onPressed: _showPowerupInfo),
                IconButton(icon: const Icon(Icons.people), onPressed: _showPlayersList),
              ],
            ),
            body: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWeb = kIsWeb;
                    final progressHeight = 80.0;
                    final statsHeight = 60.0;
                    final powerupBarHeight = widget.lobby.gameMode == GameMode.powerup ? (isWeb ? 100.0 : 80.0) : 0.0;
                    final keypadHeight = isWeb ? 120.0 : 100.0;

                    return Column(
                      children: [
                        if (widget.lobby.gameMode == GameMode.coop)
                          _buildSharedProgress(sudokuProvider)
                        else
                          SizedBox(height: progressHeight, child: Column(children: [_buildOpponentProgress(), _buildMyProgress(sudokuProvider.progress)])),

                        Container(
                          height: statsHeight,
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: FractionallySizedBox(
                            widthFactor: 0.9,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(width: 80, child: FittedBox(fit: BoxFit.scaleDown, child: SudokuMistakesCounter(mistakes: sudokuProvider.mistakesCount, maxMistakes: sudokuProvider.maxMistakes))),
                                GameTimerWidget(timeLimitSeconds: widget.lobby.gameSettings.timeLimit, isGameActive: _gameStarted && !_gameEnded, bonusSeconds: sudokuProvider.bonusTimeAdded, onTimeUp: () => setState(() => _timeUp = true), onTimeUpdate: (timeStr) => setState(() => _formattedTime = timeStr)),
                                SizedBox(width: 80, child: FittedBox(fit: BoxFit.scaleDown, child: SudokuCorrectCounter(solved: sudokuProvider.solved, totalToSolve: _calculateTotalToSolve()))),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SudokuBoard(),
                              ),
                              if (_activeBombEffect != null && !_isBombExploding)
                                Positioned.fill(
                                  child: BombTargetOverlay(
                                    startRow: _activeBombEffect!.data['startRow'] ?? 0,
                                    startCol: _activeBombEffect!.data['startCol'] ?? 0,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (widget.lobby.gameMode == GameMode.powerup)
                          SizedBox(height: powerupBarHeight, child: const PowerupBar()),
                        SizedBox(height: keypadHeight, child: const NumberKeypad()),
                      ],
                    );
                  },
                ),

                if (widget.lobby.gameSettings.allowHints)
                  Positioned(left: _hintButtonOffset.dx, top: _hintButtonOffset.dy, child: Draggable(feedback: _buildHintButton(), childWhenDragging: Opacity(opacity: 0.4, child: _buildHintButton()), onDragEnd: (details) => setState(() => _hintButtonOffset = Offset(details.offset.dx.clamp(0, MediaQuery.of(context).size.width - 60), details.offset.dy.clamp(0, MediaQuery.of(context).size.height - 60))), child: _buildHintButton())),

                if (powerupProvider.isFrozen)
                  FreezeOverlay(
                      key: const ValueKey('freeze_overlay'),
                      remainingSeconds: powerupProvider.freezeTimeRemaining
                  ),
                if (powerupProvider.shouldShowSolution)
                  SolutionOverlay(
                    key: const ValueKey('solution_overlay'),
                    remainingSeconds: powerupProvider.solutionShowTimeRemaining,
                    solution: sudokuProvider.solution,
                  ),
                if (_isBombExploding)
                  BombExplosionOverlay(
                    startRow: _activeBombEffect?.data['startRow'] ?? 0,
                    startCol: _activeBombEffect?.data['startCol'] ?? 0,
                    cellsDestroyed: _bombCellsDestroyed,
                    onComplete: () {},
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPowerupInfo() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.flash_on, color: Colors.purple),
              SizedBox(width: 8),
              Text('Powerup System'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Player-Specific Powerups', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('• 8 powerups are scheduled per game.'),
              const Text('• They spawn every 45-90 seconds.'),
              const Text('• Each player gets a unique, valid spawn location.'),
              const Text('• Powerups only appear in your unsolved cells.'),
              const SizedBox(height: 12),
              const Text('Available Powerups:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...PowerupType.values.map((type) => Text('${type.iconPath} ${type.displayName}')).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ));
  }

  Widget _buildSharedProgress(SudokuProvider sudokuProvider) {
    final totalToSolve = _calculateTotalToSolve();
    final progress = totalToSolve > 0 ? sudokuProvider.solved / totalToSolve : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.teal.withOpacity(0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Shared Progress',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 4),
          Text('${(progress * 100).toInt()}% Complete'),
        ],
      ),
    );
  }

  Widget _buildMyProgress(double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.blue.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.blue, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            flex: 2,
            child: Text('You', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            '${widget.lobby.gameMode.name.toUpperCase()} Game Starting Soon...',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(widget.lobby.gameMode == GameMode.powerup
              ? 'Get ready to collect powerups and solve!'
              : 'Get ready to solve!'),
          if (widget.lobby.gameMode == GameMode.powerup) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '🔮 Player-Specific Powerups',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Powerups will appear in your unsolved cells.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.purple[700]),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildPlayersListWidget(),
        ],
      ),
    );
  }

  Widget _buildOpponentProgress() {
    if (_opponentStates.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _opponentStates.values.map((opponent) => _buildOpponentProgressItem(opponent)).toList(),
      ),
    );
  }

  Widget _buildOpponentProgressItem(PlayerGameState opponent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(
            opponent.isCompleted ? Icons.check_circle : Icons.circle_outlined,
            color: opponent.isCompleted ? Colors.green : Colors.grey,
            size: 12,
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              opponent.playerName,
              style: TextStyle(fontSize: 10, fontWeight: opponent.isCompleted ? FontWeight.normal : FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: opponent.progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(opponent.isCompleted ? Colors.green : Colors.blue),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            opponent.isCompleted ? 'Done!' : '${(opponent.progress * 100).toInt()}%',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersListWidget() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Players in Game', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...widget.lobby.playersList.map((player) =>
                ListTile(
                  leading: CircleAvatar(child: Text(player.name.isNotEmpty ? player.name[0].toUpperCase() : '?')),
                  title: Text(player.name),
                  subtitle: Text('Rating: ${player.rating}'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
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
        title: const Text('Players'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.lobby.playersList.map((player) =>
              ListTile(
                leading: CircleAvatar(child: Text(player.name.isNotEmpty ? player.name[0].toUpperCase() : '?')),
                title: Text(player.name),
                subtitle: Text('Rating: ${player.rating}'),
              )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  int _calculateTotalToSolve() {
    int count = 0;
    if (widget.puzzle['puzzle'] is List) {
      final puzzle = widget.puzzle['puzzle'] as List;
      for (final row in puzzle) {
        if (row is List) {
          for (final cell in row) {
            if (cell == 0) count++;
          }
        }
      }
    }
    return count > 0 ? count : 45;
  }

  void _updateMyProgress() {
    if (_gameEnded || !mounted) return;

    final provider = context.read<SudokuProvider>();
    final totalToSolve = _calculateTotalToSolve();

    final newProgress = (totalToSolve > 0) ? provider.solved / totalToSolve : 0.0;
    if ((newProgress - _lastProgress).abs() > 0.001) { // Check for meaningful change
      _lastProgress = newProgress;
      GameStateService.updatePlayerGameStatus(
        widget.lobby.id,
        isCompleted: false, // It's just a progress update, not completion
        completionTime: _formattedTime,
        solvedCells: provider.solved,
        totalCells: totalToSolve,
        mistakes: provider.mistakesCount,
      );
    }
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
}
