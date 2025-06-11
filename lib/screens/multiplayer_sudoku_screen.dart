// screens/multiplayer_sudoku_screen.dart - (No changes from previous version, provided for completeness)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart';
import '../models/powerup_model.dart';
import '../providers/sudoku_provider.dart';
import '../providers/powerup_provider.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGame();
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

  void _initializeGame() {
    final sudokuProvider = Provider.of<SudokuProvider>(context, listen: false);
    final powerupProvider = Provider.of<PowerupProvider>(context, listen: false);

    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _hintButtonOffset = Offset(screenWidth * 0.85, 130);
    });

    if (widget.lobby.gameMode == GameMode.powerup) {
      powerupProvider.initialize(widget.lobby.id);
      sudokuProvider.initializePowerups(powerupProvider);
    }

    sudokuProvider.loadPuzzle(
      widget.puzzle,
      gameSettings: widget.lobby.gameSettings,
      gameMode: widget.lobby.gameMode,
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

  void _handleNewBombEffect(PowerupEffect bombEffect) {
    if (!mounted || _isBombExploding) return;

    final sudokuProvider = Provider.of<SudokuProvider>(context, listen: false);
    final powerupProvider = Provider.of<PowerupProvider>(context, listen: false);

    setState(() {
      _activeBombEffect = bombEffect;
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted || _activeBombEffect?.id != bombEffect.id) return;

      final cellsDestroyed = sudokuProvider.applyBombEffect(bombEffect.data);

      setState(() {
        _isBombExploding = true;
        _bombCellsDestroyed = cellsDestroyed;
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        powerupProvider.markBombEffectAsHandled(bombEffect.id);
        setState(() {
          _activeBombEffect = null;
          _isBombExploding = false;
          _bombCellsDestroyed = 0;
        });
      });
    });
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _timer.cancel();
    _gameStatesSubscription?.cancel();
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

  @override
  Widget build(BuildContext context) {
    return Consumer2<SudokuProvider, PowerupProvider>(
      builder: (context, sudokuProvider, powerupProvider, child) {

        if (widget.lobby.gameMode == GameMode.powerup) {
          final bombEffect = powerupProvider.activeEffects.firstWhereOrNull(
                (e) => e.type == PowerupType.bomb && e.isActive,
          );

          if (bombEffect != null && !_processedEffectIds.contains(bombEffect.id)) {
            _processedEffectIds.add(bombEffect.id);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _handleNewBombEffect(bombEffect);
              }
            });
          }
        }

        if (!_gameStarted) {
          return _buildWaitingScreen();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.lobby.gameMode.name.toUpperCase()} Sudoku - ${widget.lobby.gameSettings.difficulty.toUpperCase()}'),
            backgroundColor: widget.lobby.gameMode == GameMode.powerup ? Colors.purple : Theme.of(context).primaryColor,
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
                  final screenHeight = constraints.maxHeight;
                  final progressHeight = 80.0;
                  final statsHeight = 60.0;
                  final powerupBarHeight = widget.lobby.gameMode == GameMode.powerup ? (isWeb ? 100.0 : 80.0) : 0.0;
                  final keypadHeight = isWeb ? 120.0 : 100.0;
                  final availableHeightForBoard = screenHeight - progressHeight - statsHeight - powerupBarHeight - keypadHeight - (AppBar().preferredSize.height) - MediaQuery.of(context).padding.top;

                  return Column(
                    children: [
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
                            Padding(
                              padding: const EdgeInsets.all(8.0),
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
                        SizedBox(height: powerupBarHeight, child: PowerupBar()),
                      SizedBox(height: keypadHeight, child: const NumberKeypad()),
                    ],
                  );
                },
              ),

              if (widget.lobby.gameSettings.allowHints)
                Positioned(left: _hintButtonOffset.dx, top: _hintButtonOffset.dy, child: Draggable(feedback: _buildHintButton(), childWhenDragging: Opacity(opacity: 0.4, child: _buildHintButton()), onDragEnd: (details) => setState(() => _hintButtonOffset = Offset(details.offset.dx.clamp(0, MediaQuery.of(context).size.width - 60), details.offset.dy.clamp(0, MediaQuery.of(context).size.height - 60))), child: _buildHintButton())),

              if (powerupProvider.isFrozen)
                FreezeOverlay(remainingSeconds: powerupProvider.freezeTimeRemaining),
              if (powerupProvider.shouldShowSolution)
                SolutionOverlay(
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
    );
  }

  void _checkEndGameConditions(SudokuProvider sudokuProvider) {
    if (_gameEnded) return;

    if ((sudokuProvider.maxMistakes > 0) && (sudokuProvider.mistakesCount >= sudokuProvider.maxMistakes)) {
      Future.microtask(() => _handleGameEnd(false, sudokuProvider));
    } else if (sudokuProvider.isSolved) {
      Future.microtask(() => _handleGameEnd(true, sudokuProvider));
    } else if (_timeUp) {
      Future.microtask(() => _handleGameEnd(false, sudokuProvider, timeUp: true));
    }
  }

  Future<void> _handleGameEnd(bool isWin, SudokuProvider provider, {bool timeUp = false}) async {
    if (_gameEnded) return;
    _stopGame();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await GameStateService.updatePlayerGameStatus(widget.lobby.id, isCompleted: isWin, completionTime: _formattedTime, solvedCells: provider.solved, totalCells: _calculateTotalToSolve(), mistakes: provider.mistakesCount);
    await Future.delayed(const Duration(milliseconds: 500));

    final gameResult = await GameStateService.getGameResult(widget.lobby.id, currentUser.uid);
    final opponentStillPlaying = _opponentStates.values.any((state) => !state.isCompleted && state.playerId != currentUser.uid);

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MultiplayerResultScreen(isWin: isWin, time: _formattedTime, solvedBlocks: provider.solved, totalToSolve: _calculateTotalToSolve(), lobby: widget.lobby, winnerName: gameResult['winnerName'], isOpponentStillPlaying: opponentStillPlaying, isFirstPlace: gameResult['isFirstPlace'] ?? isWin)));
    }
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

  void _updateMyProgress(SudokuProvider provider) {
    GameStateService.updatePlayerGameStatus(
      widget.lobby.id,
      isCompleted: false,
      completionTime: _formattedTime,
      solvedCells: provider.solved,
      totalCells: _calculateTotalToSolve(),
      mistakes: provider.mistakesCount,
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
            '${widget.lobby.gameMode == GameMode.powerup ? "Powerup " : ""}Game Starting Soon...',
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