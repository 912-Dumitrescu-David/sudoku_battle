import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_battle/screens/home_screen.dart';
import '../models/lobby_model.dart';
import '../services/ranking_service.dart';
import '../services/game_state_service.dart';
import '../services/lobby_service.dart'; // 🔥 ADD THIS
import '../providers/lobby_provider.dart'; // 🔥 ADD THIS
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

  // Rating change info - FIXED to show current player's changes
  int? _myOldRating;
  int? _myNewRating;
  bool _ratingsUpdated = false;
  bool _hasNavigated = false; // 🔥 Prevent multiple navigations

  @override
  void initState() {
    super.initState();

    print('🎮 MultiplayerResultScreen initState');
    print('   isWin: ${widget.isWin}');
    print('   lobby.isRanked: ${widget.lobby.isRanked}');
    print('   winnerName: ${widget.winnerName}');
    print('   lobbyId: ${widget.lobby.id}');

    _progressController = AnimationController(
      duration: Duration(seconds: 30),
      vsync: this,
    );

    _celebrationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    // 🔥 IMMEDIATELY clean up lobby state to prevent auto-rejoin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanupLobbyState();
    });

    // Start the countdown timer
    _startTimer();

    // Start progress animation
    _progressController.forward();

    // Start celebration animation if won
    if (widget.isWin) {
      _celebrationController.repeat();
    }

    // Update ratings if this is a ranked match
    if (widget.lobby.isRanked) {
      print('✅ This is a ranked match - will update ratings');
      _updateRankedRatings();
    } else {
      print('⚠️ This is NOT a ranked match - skipping rating updates');
    }
  }

  // 🔥 NEW: Clean up lobby state to prevent auto-rejoin issues
  Future<void> _cleanupLobbyState() async {
    try {
      print('🧹 Cleaning up lobby state to prevent auto-rejoin...');

      // Clear current lobby from provider
      final lobbyProvider = context.read<LobbyProvider>();
      await lobbyProvider.leaveLobby();

      print('✅ Lobby state cleaned up');
    } catch (e) {
      print('⚠️ Error cleaning up lobby state: $e');
      // Continue anyway - this is cleanup, not critical
    }
  }

  Future<void> _updateRankedRatings() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user for rating update');
        return;
      }

      print('🏆 Starting ranked rating update...');
      print('Current user: ${currentUser.uid}');
      print('Current user display name: ${currentUser.displayName}');
      print('Local isWin: ${widget.isWin} (this might be wrong!)');
      print('Server isFirstPlace: ${widget.isFirstPlace}');
      print('Winner name: ${widget.winnerName}');
      print('Lobby isRanked: ${widget.lobby.isRanked}');
      print('Players in lobby: ${widget.lobby.playersList.length}');

      // Debug: Print all players
      for (int i = 0; i < widget.lobby.playersList.length; i++) {
        final player = widget.lobby.playersList[i];
        print('Player $i: ${player.name} (${player.id}) - Rating: ${player.rating}');
      }

      // Only update ratings if this is actually a ranked game
      if (!widget.lobby.isRanked) {
        print('⚠️ Skipping rating update - not a ranked game');
        return;
      }

      // 🔥 GET THE ACTUAL SERVER-SIDE WINNER (not local completion status)
      print('🔍 Getting server-side game result to determine actual winner...');
      final serverGameResult = await GameStateService.getGameResult(
          widget.lobby.id,
          currentUser.uid
      );

      final actualIsFirstPlace = serverGameResult['isFirstPlace'] ?? false;
      final actualWinnerName = serverGameResult['winnerName'];

      print('🎯 SERVER TRUTH:');
      print('   Actual winner: $actualWinnerName');
      print('   Current player is first place: $actualIsFirstPlace');
      print('   Local widget.isWin was: ${widget.isWin}');
      print('   Local widget.isFirstPlace was: ${widget.isFirstPlace}');

      final players = widget.lobby.playersList;
      if (players.length != 2) {
        print('❌ Invalid player count: ${players.length}');
        return;
      }

      // Find current player and opponent
      Player? currentPlayer;
      Player? opponent;

      for (final player in players) {
        if (player.id == currentUser.uid) {
          currentPlayer = player;
        } else {
          opponent = player;
        }
      }

      if (currentPlayer == null || opponent == null) {
        print('❌ Could not identify current player or opponent');
        print('Current player found: ${currentPlayer != null}');
        print('Opponent found: ${opponent != null}');
        return;
      }

      print('✅ Players identified:');
      print('Current player: ${currentPlayer.name} (${currentPlayer.id}) - Rating: ${currentPlayer.rating}');
      print('Opponent: ${opponent.name} (${opponent.id}) - Rating: ${opponent.rating}');

      // Store current player's old rating for UI display
      _myOldRating = currentPlayer.rating;

      // 🔥 FIXED: Use server-side result, not local completion status
      String winnerId, loserId;
      int winnerOldRating, loserOldRating;
      String winnerName, loserName;

      if (actualIsFirstPlace) {
        // Current player actually won on server
        winnerId = currentPlayer.id;
        loserId = opponent.id;
        winnerOldRating = currentPlayer.rating;
        loserOldRating = opponent.rating;
        winnerName = currentPlayer.name;
        loserName = opponent.name;
        print('✅ CORRECTED: Current player ACTUALLY WON the game on server');
      } else {
        // Current player actually lost on server
        winnerId = opponent.id;
        loserId = currentPlayer.id;
        winnerOldRating = opponent.rating;
        loserOldRating = currentPlayer.rating;
        winnerName = opponent.name;
        loserName = currentPlayer.name;
        print('❌ CORRECTED: Current player ACTUALLY LOST the game on server');
      }

      print('📊 Rating update details:');
      print('Winner: $winnerName ($winnerId) - Old Rating: $winnerOldRating');
      print('Loser: $loserName ($loserId) - Old Rating: $loserOldRating');

      // Calculate new ratings
      final ratingChanges = RankingService.calculateNewRatings(
        winnerRating: winnerOldRating,
        loserRating: loserOldRating,
      );

      print('📈 New ratings calculated:');
      print('Winner: $winnerOldRating → ${ratingChanges['winner']} (${ratingChanges['winner']! - winnerOldRating > 0 ? '+' : ''}${ratingChanges['winner']! - winnerOldRating})');
      print('Loser: $loserOldRating → ${ratingChanges['loser']} (${ratingChanges['loser']! - loserOldRating > 0 ? '+' : ''}${ratingChanges['loser']! - loserOldRating})');

      // 🔥 FIXED: Store the current player's new rating based on actual server result
      if (actualIsFirstPlace) {
        _myNewRating = ratingChanges['winner']!;
      } else {
        _myNewRating = ratingChanges['loser']!;
      }

      print('🎯 Current player rating change: $_myOldRating → $_myNewRating');
      print('🎯 Rating change amount: ${_myNewRating! - _myOldRating!}');

      // Update ratings in Firestore
      print('💾 Updating Firestore...');
      await RankingService.updatePlayerRatings(
        winnerId: winnerId,
        loserId: loserId,
        winnerOldRating: winnerOldRating,
        loserOldRating: loserOldRating,
      );

      setState(() {
        _ratingsUpdated = true;
      });

      print('✅ Rating update completed successfully!');

    } catch (e, stackTrace) {
      print('❌ Error updating ratings: $e');
      print('Stack trace: $stackTrace');
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
    if (_hasNavigated) return; // 🔥 Prevent multiple navigations
    _hasNavigated = true;

    print('🔄 Returning to lobby/queue from result screen...');

    if (widget.lobby.isRanked) {
      // For ranked matches, go directly to ranked queue (no post-game lobby)
      print('🏆 Ranked match - going to ranked queue');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => RankedQueueScreen()),
            (route) => route.isFirst, // 🔥 Clear entire navigation stack
      );
    } else {
      // For casual matches, go to post-game lobby for chat
      print('🎮 Casual match - going to post-game lobby');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PostGameLobbyScreen(
            lobbyId: widget.lobby.id,
            wasGameCompleted: true,
            isRankedGame: false, // Casual game
          ),
        ),
      );
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
    return WillPopScope(
      // 🔥 Prevent back button from causing navigation issues
      onWillPop: () async {
        _returnToLobby();
        return false;
      },
      child: Scaffold(
        backgroundColor: widget.isWin ? Colors.green[50] : Colors.red[50],
        appBar: AppBar(
          title: Text(widget.lobby.isRanked ? 'Ranked Result' : 'Game Result'),
          backgroundColor: widget.isWin ? Colors.green : Colors.red,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false, // 🔥 Remove back button
          actions: [
            TextButton(
              onPressed: () {
                if (!_hasNavigated) {
                  _returnToLobby();
                }
              },
              child: Text(
                widget.lobby.isRanked ? 'Find New Game' : 'Return to Lobby',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Result icon with animation
                AnimatedBuilder(
                  animation: _celebrationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: widget.isWin
                          ? 1.0 + (_celebrationController.value * 0.1)
                          : 1.0,
                      child: Icon(
                        widget.isWin ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                        color: widget.isWin ? Colors.amber : Colors.red,
                        size: 100,
                      ),
                    );
                  },
                ),

                SizedBox(height: 24),

                // Result title with better ranked messaging
                Text(
                  _getResultTitle(),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: widget.isWin ? Colors.green[700] : Colors.red[700],
                  ),
                ),

                SizedBox(height: 16),

                // Ranked match indicator with result details
                if (widget.lobby.isRanked)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purple),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events, color: Colors.purple, size: 20),
                            SizedBox(width: 4),
                            Text(
                              'Ranked Match Result',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          _getRankedResultMessage(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.purple[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 16),

                // Winner announcement
                if (widget.winnerName != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Text(
                      widget.isFirstPlace
                          ? '👑 ${widget.winnerName} wins!'
                          : '🏆 Winner: ${widget.winnerName}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[800],
                      ),
                    ),
                  ),

                SizedBox(height: 24),

                // Rating changes (for ranked matches) - FIXED
                if (widget.lobby.isRanked && _ratingsUpdated && _myOldRating != null && _myNewRating != null)
                  _buildRatingChanges(),

                SizedBox(height: 16),

                // Game stats
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Your Performance',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 16),
                        _buildStatRow('Time', widget.time, Icons.timer),
                        _buildStatRow(
                          'Progress',
                          '${widget.solvedBlocks} / ${widget.totalToSolve}',
                          Icons.check_circle,
                        ),
                        _buildStatRow(
                          'Completion',
                          '${((widget.solvedBlocks / widget.totalToSolve) * 100).toInt()}%',
                          Icons.trending_up,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Opponent status
                if (widget.isOpponentStillPlaying)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Waiting for opponent to finish...',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 24),

                // Countdown timer
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.lobby.isRanked ? 'Finding new game in' : 'Returning to lobby in',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Theme.of(context).primaryColor,
                            size: 28,
                          ),
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
                      // Progress bar
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
                ),

                SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (!_hasNavigated) {
                            _returnToLobby();
                          }
                        },
                        icon: Icon(widget.lobby.isRanked ? Icons.search : Icons.chat),
                        label: Text(widget.lobby.isRanked ? 'Find New Game' : 'Back to Lobby'),
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
                            // Navigate to home screen - PASS REFRESH FLAG FOR RATING UPDATE
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => HomeScreen()), // Placeholder
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
                ),
              ],
            ),
          ),
        ),
      ),
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

  // 🔥 FIXED: Use current player's rating changes instead of winner's
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
            Text(
              'Rating Update',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      'Previous',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$_myOldRating',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.arrow_forward,
                  color: isPositive ? Colors.green : Colors.red,
                  size: 32,
                ),
                Column(
                  children: [
                    Text(
                      'New Rating',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
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
                '${isPositive ? '+' : ''}$change',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
}