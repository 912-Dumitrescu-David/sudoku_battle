import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lobby_model.dart';
import '../providers/lobby_provider.dart';
import '../widgets/chat_widget.dart';
import '../services/lobby_service.dart';
import 'lobby_screen.dart';
import 'ranked_queue_screen.dart';

class PostGameLobbyScreen extends StatefulWidget {
  final String lobbyId;
  final bool wasGameCompleted;
  final bool isRankedGame; // Add this flag

  const PostGameLobbyScreen({
    Key? key,
    required this.lobbyId,
    this.wasGameCompleted = true,
    this.isRankedGame = false, // Default to false (casual)
  }) : super(key: key);

  @override
  State<PostGameLobbyScreen> createState() => _PostGameLobbyScreenState();
}

class _PostGameLobbyScreenState extends State<PostGameLobbyScreen> {
  bool _isChatExpanded = true; // Start with chat expanded for post-game discussion

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Reset the lobby status back to waiting after game
      _resetLobbyStatus();
      // Join the lobby for post-game chat
      context.read<LobbyProvider>().joinLobby(widget.lobbyId);
    });
  }

  Future<void> _resetLobbyStatus() async {
    try {
      // Reset lobby status to waiting so players can start a new game
      await LobbyService.resetLobbyForNewGame(widget.lobbyId);
    } catch (e) {
      print('Error resetting lobby: $e');
      // If lobby reset fails, go to appropriate screen based on game type
      if (widget.isRankedGame) {
        Navigator.pushReplacementNamed(context, '/ranked-queue');
      } else {
        Navigator.pushReplacementNamed(context, '/lobby');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isRankedGame ? 'Ranked Game Complete - Chat' : 'Game Complete - Lobby Chat'),
        backgroundColor: widget.isRankedGame ? Colors.purple : Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.home),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: Consumer<LobbyProvider>(
        builder: (context, lobbyProvider, child) {
          final lobby = lobbyProvider.currentLobby;

          if (lobby == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading lobby...'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (widget.isRankedGame) {
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
                    },
                    child: Text(widget.isRankedGame ? 'Go to Ranked Queue' : 'Go to Lobby Browser'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Game completion banner
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (widget.isRankedGame ? Colors.purple : Colors.green).withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(color: widget.isRankedGame ? Colors.purple : Colors.green),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      widget.isRankedGame ? Icons.emoji_events : Icons.celebration,
                      color: widget.isRankedGame ? Colors.purple : Colors.green,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      widget.isRankedGame ? 'Ranked Game Complete!' : 'Game Complete!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.isRankedGame ? Colors.purple : Colors.green,
                      ),
                    ),
                    Text(
                      widget.isRankedGame
                          ? 'Your rating has been updated based on performance'
                          : 'Chat with your fellow players or start a new game',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Players list
              Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Players in Lobby',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: lobby.playersList.map((player) =>
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(right: 8),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    child: Text(player.name[0].toUpperCase()),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    player.name,
                                    style: TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (player.id == lobby.hostPlayerId)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: widget.isRankedGame ? Colors.purple : Colors.blue,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'HOST',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ).toList(),
                    ),
                  ],
                ),
              ),

              // Chat area (expanded by default for post-game discussion)
              Expanded(
                child: LobbyChat(
                  lobbyId: widget.lobbyId,
                  isExpanded: _isChatExpanded,
                  onToggleExpand: () {
                    setState(() {
                      _isChatExpanded = !_isChatExpanded;
                    });
                  },
                ),
              ),

              // Action buttons
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Other action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              // Leave lobby and navigate based on game type
                              await context.read<LobbyProvider>().leaveLobby();

                              if (widget.isRankedGame) {
                                // Go to ranked queue for ranked games
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => RankedQueueScreen()),
                                      (route) => route.isFirst,
                                );
                              } else {
                                // Go to lobby browser for casual games
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => LobbyScreen()),
                                      (route) => route.isFirst,
                                );
                              }
                            },
                            icon: Icon(widget.isRankedGame ? Icons.emoji_events : Icons.search),
                            label: Text(widget.isRankedGame ? 'Find Ranked Game' : 'Find Casual Game'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              foregroundColor: widget.isRankedGame ? Colors.purple : Colors.blue,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Go to home screen
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                            icon: Icon(Icons.home),
                            label: Text('Home'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startNewGame(Lobby lobby) async {
    try {
      final success = await context.read<LobbyProvider>().startGame();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start new game'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Navigation will be handled by the lobby provider status change
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}