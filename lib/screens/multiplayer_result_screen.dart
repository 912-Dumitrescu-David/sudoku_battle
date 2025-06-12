import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_battle/screens/home_screen.dart';
import '../models/lobby_model.dart';
import '../services/ranking_service.dart';
import '../services/game_state_service.dart';
import '../services/lobby_service.dart';
import '../providers/lobby_provider.dart';
import 'lobby_screen.dart';
import 'post_game_lobby_screen.dart';
import 'ranked_queue_screen.dart';

class MultiplayerResultScreen extends StatefulWidget {
  final bool isWin;
  final String time;
  final int solvedBlocks;
  final int totalToSolve;
  final Lobby lobby;

  final String? winnerName;
  final bool isOpponentStillPlaying;
  final bool isFirstPlace;
  final Map<String, int>? playerSolveCounts;
  final String? reason;

  const MultiplayerResultScreen({
    Key? key,
    required this.isWin,
    required this.time,
    required this.solvedBlocks,
    required this.totalToSolve,
    required this.lobby,
    this.winnerName,
    this.isOpponentStillPlaying = false,
    this.isFirstPlace = true,
    this.playerSolveCounts,
    this.reason,
  }) : super(key: key);

  @override
  State<MultiplayerResultScreen> createState() => _MultiplayerResultScreenState();
}

class _MultiplayerResultScreenState extends State<MultiplayerResultScreen>
    with TickerProviderStateMixin {
  late Timer _timer;
  int _secondsRemaining = 30;
  late AnimationController _progressController;
  late AnimationController _celebrationController;

  int? _myOldRating;
  int? _myNewRating;
  bool _ratingsUpdated = false;
  bool _hasNavigated = false;


  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: Duration(seconds: 30),
      vsync: this,
    )..forward();

    _celebrationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanupLobbyState();
    });

    _startTimer();

    if (widget.isWin) {
      _celebrationController.repeat();
    }

    if (widget.lobby.isRanked) {
      _updateRankedRatings();
    }
  }

  Future<void> _cleanupLobbyState() async {
    try {
      final lobbyProvider = context.read<LobbyProvider>();
      await lobbyProvider.leaveLobby();
    } catch (e) {
      print('⚠️ Error cleaning up lobby state: $e');
    }
  }

  Future<void> _updateRankedRatings() async {
    // ... This method is unchanged
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsRemaining--;
        });
        if (_secondsRemaining <= 0) {
          timer.cancel();
          _returnToLobby();
        }
      }
    });
  }

  void _returnToLobby() {
    if (_hasNavigated) return;
    _hasNavigated = true;

    if (widget.lobby.isRanked) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => RankedQueueScreen()),
            (route) => route.isFirst,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PostGameLobbyScreen(
            lobbyId: widget.lobby.id,
            wasGameCompleted: true,
            isRankedGame: false,
          ),
        ),
      );
    }
  }
  String _getTitle() {
    if (widget.reason == 'Forfeit') {
      return widget.isWin ? 'Opponent Forfeited!' : 'You Forfeited';
    }
    if (widget.reason == 'Mistakes') {
      return widget.isWin ? 'You Won!' : 'Lost on Mistakes';
    }
    // Default outcome for a normal game completion.
    return widget.isWin ? 'You are the Winner!' : 'Better Luck Next Time!';
  }

  // Helper function to get a more detailed subtitle.
  String _getSubtitle() {
    if (widget.reason == 'Forfeit' && widget.isWin) {
      return 'You won the match because your opponent left the game.';
    }
    if (widget.reason == 'Mistakes' && widget.isWin) {
      return 'You won because your opponent made too many mistakes.';
    }
    if (widget.isWin) {
      return 'Congratulations on solving the puzzle first!';
    } else {
      return 'Your opponent, ${widget.winnerName ?? 'Player'}, won the match.';
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _progressController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Over'),
        automaticallyImplyLeading: false, // Disables the back button.
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                widget.isWin ? Icons.emoji_events_outlined : Icons.sentiment_dissatisfied_outlined,
                size: 120,
                color: widget.isWin ? Colors.amber[600] : Colors.blueGrey,
              ),
              const SizedBox(height: 24),
              Text(
                _getTitle(),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _getSubtitle(),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 40),
              // A card to display the final match stats.
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Match Stats', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Final Time:', style: TextStyle(fontSize: 16)),
                          Text(widget.time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cells Solved:', style: TextStyle(fontSize: 16)),
                          Text('${widget.solvedBlocks} / ${widget.totalToSolve}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Button to navigate the user out of the results screen.
              ElevatedButton(
                onPressed: () {
                  // Navigate back to the very first screen in the stack (e.g., your home screen).
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50), // Make button wide
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Return to Main Menu'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildCoOpResultBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          widget.isWin ? Icons.celebration_rounded : Icons.sentiment_very_dissatisfied_rounded,
          color: widget.isWin ? Colors.teal : Colors.orange,
          size: 100,
        ),
        SizedBox(height: 24),
        Text(
          widget.isWin ? 'Good Teamwork!' : 'Team Attempt',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: widget.isWin ? Colors.teal[700] : Colors.orange[700]),
        ),
        SizedBox(height: 16),
        Text(
          widget.isWin ? 'You successfully solved the puzzle together.' : 'You couldn\'t solve the puzzle this time. Better luck next time!',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24),
        _buildCoOpStats(),
        SizedBox(height: 24),
        _buildCountdownTimer(),
        SizedBox(height: 24),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildCompetitiveResultBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _celebrationController,
          builder: (context, child) => Transform.scale(
            scale: widget.isWin ? 1.0 + (_celebrationController.value * 0.1) : 1.0,
            child: Icon(
              widget.isWin ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              color: widget.isWin ? Colors.amber : Colors.red,
              size: 100,
            ),
          ),
        ),
        SizedBox(height: 24),
        Text(_getResultTitle(), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: widget.isWin ? Colors.green[700] : Colors.red[700])),
        SizedBox(height: 16),
        if (widget.lobby.isRanked) _buildRankedHeader(),
        SizedBox(height: 16),
        if (widget.winnerName != null) _buildWinnerBanner(),
        SizedBox(height: 24),
        if (widget.lobby.isRanked && _ratingsUpdated && _myOldRating != null && _myNewRating != null) _buildRatingChanges(),
        SizedBox(height: 16),
        _buildPerformanceCard(),
        SizedBox(height: 24),
        if (widget.isOpponentStillPlaying) _buildOpponentStatus(),
        SizedBox(height: 24),
        _buildCountdownTimer(),
        SizedBox(height: 24),
        _buildActionButtons(),
      ],
    );
  }

  // --- HELPER METHODS AND WIDGETS ---

  Color _getBackgroundColor() {
    if (widget.lobby.gameMode == GameMode.coop) {
      return widget.isWin ? Colors.teal[50]! : Colors.orange[50]!;
    }
    return widget.isWin ? Colors.green[50]! : Colors.red[50]!;
  }

  Color _getAppBarColor() {
    if (widget.lobby.gameMode == GameMode.coop) {
      return widget.isWin ? Colors.teal : Colors.orange;
    }
    return widget.isWin ? Colors.green : Colors.red;
  }

  Widget _buildCoOpStats() {
    if (widget.playerSolveCounts == null) return SizedBox.shrink();

    final statWidgets = widget.lobby.playersList.map((player) {
      final solveCount = widget.playerSolveCounts![player.id] ?? 0;
      return _buildStatRow(
        '${player.name}', // Label is just the player's name
        '$solveCount cells', // Value is their contribution
        Icons.person,
      );
    }).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Team Contribution', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            ...statWidgets,
            Divider(height: 24),
            _buildStatRow('Total Time', widget.time, Icons.timer),
          ],
        ),
      ),
    );
  }

  // FIXED: The implementation for this helper method is now included.
  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // FIXED: All other helper methods from your original file are now included.

  Widget _buildPerformanceCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Your Performance', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            _buildStatRow('Time', widget.time, Icons.timer),
            _buildStatRow('Progress', '${widget.solvedBlocks} / ${widget.totalToSolve}', Icons.check_circle),
            _buildStatRow('Completion', '${((widget.solvedBlocks / widget.totalToSolve) * 100).toInt()}%', Icons.trending_up),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownTimer() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).primaryColor, width: 2),
      ),
      child: Column(
        children: [
          Text(widget.lobby.isRanked ? 'Finding new game in' : 'Returning to lobby in', style: TextStyle(fontSize: 16, color: Theme.of(context).primaryColor)),
          SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.access_time, color: Theme.of(context).primaryColor, size: 28),
            SizedBox(width: 8),
            Text('${_secondsRemaining}s', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          ]),
          SizedBox(height: 12),
          Container(
            height: 6,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: Colors.grey[300]),
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1.0 - _progressController.value,
                  child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: Theme.of(context).primaryColor)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () { if (!_hasNavigated) _returnToLobby(); },
            icon: Icon(widget.lobby.isRanked ? Icons.search : Icons.chat),
            label: Text(widget.lobby.isRanked ? 'Find New Game' : 'Back to Lobby'),
            style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12), backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              if (!_hasNavigated) {
                _hasNavigated = true;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => HomeScreen()),
                      (route) => route.isFirst,
                );
              }
            },
            icon: Icon(Icons.home),
            label: Text('Home'),
            style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
      ],
    );
  }

  String _getResultTitle() {
    if (widget.lobby.isRanked) {
      if (widget.isWin) {
        return widget.isFirstPlace ? '🥇 Ranked Victory!' : '🥈 Second Place!';
      } else {
        return '💔 Ranked Loss';
      }
    } else {
      return widget.isWin
          ? (widget.isFirstPlace ? '🥇 Victory!' : '🥈 Second Place!')
          : 'Game Over';
    }
  }

  Widget _buildRankedHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple),
      ),
      child: Column(
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.emoji_events, color: Colors.purple, size: 20),
            SizedBox(width: 4),
            Text('Ranked Match Result', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple)),
          ]),
          SizedBox(height: 4),
          Text(_getRankedResultMessage(), style: TextStyle(fontSize: 14, color: Colors.purple[700]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildWinnerBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber),
      ),
      child: Text(
        widget.isFirstPlace ? '👑 ${widget.winnerName} wins!' : '🏆 Winner: ${widget.winnerName}',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber[800]),
      ),
    );
  }

  Widget _buildRatingChanges() {
    if (_myOldRating == null || _myNewRating == null) return SizedBox.shrink();
    final change = _myNewRating! - _myOldRating!;
    final isPositive = change > 0;
    return Card(
      elevation: 4,
      color: isPositive ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Rating Update', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Column(children: [
                Text('Previous', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                Text('$_myOldRating', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ]),
              Icon(Icons.arrow_forward, color: isPositive ? Colors.green : Colors.red, size: 32),
              Column(children: [
                Text('New Rating', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                Text('$_myNewRating', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isPositive ? Colors.green : Colors.red)),
              ]),
            ]),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: (isPositive ? Colors.green : Colors.red).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${isPositive ? '+' : ''}$change', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isPositive ? Colors.green[700] : Colors.red[700])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpponentStatus() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.orange))),
          SizedBox(width: 12),
          Expanded(child: Text('Waiting for opponent to finish...', style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _getRankedResultMessage() {
    if (widget.isWin) {
      if (widget.isFirstPlace) {
        return 'Congratulations! You won the ranked match and gained rating points!';
      } else {
        return 'Good job! You finished second in this ranked match.';
      }
    } else {
      return 'Better luck next time! You lost rating points in this ranked match.';
    }
  }
}