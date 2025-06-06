import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lobby_model.dart';
import 'lobby_screen.dart';
import 'post_game_lobby_screen.dart';

class MultiplayerResultScreen extends StatefulWidget {
  final bool isWin;
  final String time;
  final int solvedBlocks;
  final int totalToSolve;
  final Lobby lobby;
  final String? winnerName;
  final bool isOpponentStillPlaying;
  final bool isFirstPlace; // Add this to distinguish 1st vs 2nd place

  const MultiplayerResultScreen({
    Key? key,
    required this.isWin,
    required this.time,
    required this.solvedBlocks,
    required this.totalToSolve,
    required this.lobby,
    this.winnerName,
    this.isOpponentStillPlaying = false,
    this.isFirstPlace = true, // Default to first place
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

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: Duration(seconds: 30),
      vsync: this,
    );

    _celebrationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    // Start the countdown timer
    _startTimer();

    // Start progress animation
    _progressController.forward();

    // Start celebration animation if won
    if (widget.isWin) {
      _celebrationController.repeat();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _secondsRemaining--;
      });

      if (_secondsRemaining <= 0) {
        timer.cancel();
        _returnToLobby();
      }
    });
  }

  void _returnToLobby() {
    // Navigate to post-game lobby for chat and potential rematch
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PostGameLobbyScreen(
          lobbyId: widget.lobby.id,
          wasGameCompleted: true,
        ),
      ),
    );
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
    return Scaffold(
      backgroundColor: widget.isWin ? Colors.green[50] : Colors.red[50],
      appBar: AppBar(
        title: Text('Game Result'),
        backgroundColor: widget.isWin ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Prevent back button
        actions: [
          TextButton(
            onPressed: _returnToLobby,
            child: Text(
              'Return to Lobby',
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

              // Result title
              Text(
                widget.isWin
                    ? (widget.isFirstPlace ? '🥇 Victory!' : '🥈 Second Place!')
                    : 'Game Over',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: widget.isWin ? Colors.green[700] : Colors.red[700],
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
                      'Returning to lobby in',
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
                      onPressed: _returnToLobby,
                      icon: Icon(Icons.chat),
                      label: Text('Back to Lobby'),
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
                        // Navigate to home screen
                        Navigator.of(context).popUntil((route) => route.isFirst);
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