import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('🔄 Loading rating changes for ranked match result');

      final userDoc = await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'lobbies',
      ).collection('users').doc(user.uid).get();

      if (userDoc.exists && mounted) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final newRating = userData['rating'] ?? 1000;

        final oldRating = await _getPreviousRating(userData);

        setState(() {
          _myNewRating = newRating;
          _myOldRating = oldRating;
          _ratingsUpdated = true;
        });

        final change = newRating - oldRating;
        print('✅ Rating update: $oldRating → $newRating (${change >= 0 ? '+' : ''}$change)');
        print('   Reason: ${widget.reason ?? 'Normal completion'}');
      }
    } catch (e) {
      print('❌ Error loading rating changes: $e');

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instanceFor(
            app: Firebase.app(),
            databaseId: 'lobbies',
          ).collection('users').doc(user.uid).get(const GetOptions(source: Source.cache));

          if (userDoc.exists && mounted) {
            final currentRating = userDoc.data()?['rating'] ?? 1000;
            setState(() {
              _myNewRating = currentRating;
              _myOldRating = currentRating;
              _ratingsUpdated = true;
            });
          }
        }
      } catch (cacheError) {
        print('Cache error: $cacheError');
      }
    }
  }

  Future<int> _getPreviousRating(Map<String, dynamic> userData) async {
    try {
      if (userData.containsKey('previousRating')) {
        return userData['previousRating'] ?? 1000;
      }
      for (final player in widget.lobby.playersList) {
        if (player.id == FirebaseAuth.instance.currentUser?.uid) {
          return player.rating;
        }
      }

      final currentRating = userData['rating'] ?? 1000;
      return currentRating;

    } catch (e) {
      print('Error getting previous rating: $e');
      return userData['rating'] ?? 1000;
    }
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LobbyScreen()),
            (route) => route.isFirst,
      );
    }
  }

  // Enhanced title with clear reason indication
  String _getTitle() {
    if (widget.reason == 'Forfeit') {
      return widget.isWin ? '🏃 Opponent Forfeited!' : '🏃 You Forfeited';
    }
    if (widget.reason == 'Mistakes') {
      return widget.isWin ? '❌ Opponent Made Too Many Mistakes!' : '❌ Too Many Mistakes!';
    }
    if (widget.reason == 'Timeout') {
      return widget.isWin ? '⏰ Opponent Ran Out of Time!' : '⏰ Time\'s Up!';
    }
    // Default outcome for normal completion
    return widget.isWin ? '🏆 Victory!' : '😔 Defeat';
  }

  // Enhanced subtitle with detailed explanation
  String _getSubtitle() {
    final opponentName = widget.winnerName ?? 'Your opponent';

    if (widget.reason == 'Forfeit') {
      if (widget.isWin) {
        return 'You won because $opponentName left the game early. Victory by forfeit!';
      } else {
        return 'You left the game early. Better luck next time!';
      }
    }

    if (widget.reason == 'Mistakes') {
      if (widget.isWin) {
        return '$opponentName made too many mistakes and was eliminated. You won by being more careful!';
      } else {
        return 'You made too many mistakes and were eliminated. Focus on accuracy next time!';
      }
    }

    if (widget.reason == 'Timeout') {
      if (widget.isWin) {
        return '$opponentName ran out of time. You won by being faster!';
      } else {
        return 'You ran out of time. Try to solve faster next time!';
      }
    }

    // Normal completion
    if (widget.isWin) {
      return 'Congratulations! You solved the puzzle first and won the match!';
    } else {
      return '$opponentName solved the puzzle first. Great effort though!';
    }
  }

  // Get appropriate icon based on reason
  IconData _getResultIcon() {
    if (widget.reason == 'Forfeit') {
      return widget.isWin ? Icons.directions_run : Icons.exit_to_app;
    }
    if (widget.reason == 'Mistakes') {
      return widget.isWin ? Icons.error_outline : Icons.cancel;
    }
    if (widget.reason == 'Timeout') {
      return widget.isWin ? Icons.timer : Icons.timer_off;
    }
    // Normal completion
    return widget.isWin ? Icons.emoji_events : Icons.sentiment_dissatisfied;
  }

  Color _getResultColor() {
    if (widget.isWin) {
      if (widget.reason == 'Forfeit') return Colors.orange;
      if (widget.reason == 'Mistakes') return Colors.amber;
      if (widget.reason == 'Timeout') return Colors.blue;
      return Colors.green; // Normal win
    } else {
      if (widget.reason == 'Forfeit') return Colors.red[700]!;
      if (widget.reason == 'Mistakes') return Colors.red[600]!;
      if (widget.reason == 'Timeout') return Colors.red[500]!;
      return Colors.grey[600]!; // Normal loss
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
    final resultColor = _getResultColor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Result'),
        automaticallyImplyLeading: false,
        backgroundColor: resultColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Enhanced result header with reason
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: resultColor, width: 2),
              ),
              child: Column(
                children: [
                  // Result icon with animation
                  AnimatedBuilder(
                    animation: _celebrationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: widget.isWin ? (1.0 + _celebrationController.value * 0.1) : 1.0,
                        child: Icon(
                          _getResultIcon(),
                          size: 80,
                          color: resultColor,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 16),

                  // Main title
                  Text(
                    _getTitle(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: resultColor,
                    ),
                  ),
                  SizedBox(height: 8),

                  // Detailed subtitle
                  Text(
                    _getSubtitle(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Match statistics
            _buildMatchStats(theme),

            SizedBox(height: 24),

            // Rating changes (for ranked games)
            if (widget.lobby.isRanked) ...[
              _buildRatingChanges(),
              SizedBox(height: 24),
            ],

            // Co-op specific stats
            if (widget.lobby.gameMode == GameMode.coop && widget.playerSolveCounts != null) ...[
              _buildCoOpStats(),
              SizedBox(height: 24),
            ],

            // Navigation countdown
            _buildCountdownTimer(),

            SizedBox(height: 24),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchStats(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: theme.primaryColor),
                SizedBox(width: 8),
                Text(
                  'Match Statistics',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),

            _buildStatRow('Final Time', widget.time, Icons.timer),
            _buildStatRow('Cells Solved', '${widget.solvedBlocks} / ${widget.totalToSolve}', Icons.grid_on),
            _buildStatRow('Completion', '${((widget.solvedBlocks / widget.totalToSolve) * 100).toInt()}%', Icons.trending_up),

            // Reason-specific stats
            if (widget.reason != null) ...[
              Divider(height: 24),
              _buildStatRow('Game Ended', _getReasonDisplayText(), _getReasonIcon()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoOpStats() {
    if (widget.playerSolveCounts == null) return SizedBox.shrink();

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.group, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Team Contribution',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),

            ...widget.lobby.playersList.map((player) {
              final solveCount = widget.playerSolveCounts![player.id] ?? 0;
              return _buildStatRow(player.name, '$solveCount cells', Icons.person);
            }).toList(),

            Divider(height: 24),
            _buildStatRow('Total Time', widget.time, Icons.timer),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingChanges() {
    if (!widget.lobby.isRanked) return SizedBox.shrink();

    if (_myOldRating == null || _myNewRating == null) {
      return Card(
        elevation: 4,
        color: Colors.purple[50],
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Loading Rating Update...',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Calculating your new rating based on match performance',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final change = _myNewRating! - _myOldRating!;
    final isPositive = change > 0;

    return Card(
      elevation: 4,
      color: isPositive ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  'Ranked Rating Update',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            // Show reason-specific message
            if (widget.reason != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getRatingReasonColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _getRatingReasonColor()),
                ),
                child: Text(
                  _getRatingReasonText(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getRatingReasonColor(),
                  ),
                ),
              ),
            ],

            SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text('Previous', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    Text('$_myOldRating', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                Icon(Icons.arrow_forward, color: isPositive ? Colors.green : Colors.red, size: 32),
                Column(
                  children: [
                    Text('New Rating', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    Text(
                      '$_myNewRating',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: (isPositive ? Colors.green : Colors.red).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${isPositive ? '+' : ''}$change points',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),

            SizedBox(height: 8),
            Text(
              'Rating calculated by ELO system based on match performance',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getRatingReasonColor() {
    switch (widget.reason) {
      case 'Forfeit':
        return Colors.orange;
      case 'Mistakes':
        return Colors.red;
      case 'Timeout':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  String _getRatingReasonText() {
    if (widget.isWin) {
      switch (widget.reason) {
        case 'Forfeit':
          return 'Win by Forfeit';
        case 'Mistakes':
          return 'Win by Opponent Mistakes';
        case 'Timeout':
          return 'Win by Timeout';
        default:
          return 'Normal Victory';
      }
    } else {
      switch (widget.reason) {
        case 'Forfeit':
          return 'Loss by Forfeit';
        case 'Mistakes':
          return 'Loss by Mistakes';
        case 'Timeout':
          return 'Loss by Timeout';
        default:
          return 'Normal Defeat';
      }
    }
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
          Text(
            widget.lobby.isRanked ? 'Finding new ranked game in' : 'Returning to lobby browser in',
            style: TextStyle(fontSize: 16, color: Theme.of(context).primaryColor),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time, color: Theme.of(context).primaryColor, size: 28),
              SizedBox(width: 8),
              Text(
                '${_secondsRemaining}s',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.grey[300],
            ),
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1.0 - _progressController.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
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
            onPressed: () {
              if (!_hasNavigated) _returnToLobby();
            },
            icon: Icon(widget.lobby.isRanked ? Icons.emoji_events : Icons.search),
            label: Text(widget.lobby.isRanked ? 'Find Ranked Game' : 'Find Casual Game'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
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
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  String _getReasonDisplayText() {
    switch (widget.reason) {
      case 'Forfeit':
        return widget.isWin ? 'Opponent forfeited' : 'You forfeited';
      case 'Mistakes':
        return widget.isWin ? 'Opponent\'s mistakes' : 'Too many mistakes';
      case 'Timeout':
        return widget.isWin ? 'Opponent timed out' : 'Time limit reached';
      default:
        return 'Puzzle completed';
    }
  }

  IconData _getReasonIcon() {
    switch (widget.reason) {
      case 'Forfeit':
        return Icons.exit_to_app;
      case 'Mistakes':
        return Icons.error;
      case 'Timeout':
        return Icons.timer_off;
      default:
        return Icons.check_circle;
    }
  }
}