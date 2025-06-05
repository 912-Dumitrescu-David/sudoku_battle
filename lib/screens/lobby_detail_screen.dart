import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/lobby_model.dart';
import '../providers/lobby_provider.dart';
import '../models/lobby_model.dart';
import '../utils/sudoku_engine.dart';
import 'multiplayer_sudoku_screen.dart';

class LobbyDetailScreen extends StatefulWidget {
  final String lobbyId;

  const LobbyDetailScreen({Key? key, required this.lobbyId}) : super(key: key);

  @override
  State<LobbyDetailScreen> createState() => _LobbyDetailScreenState();
}

class _LobbyDetailScreenState extends State<LobbyDetailScreen> {
  bool _hasNavigatedToGame = false;
  @override
  void initState() {
    super.initState();
    // Join the lobby when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LobbyProvider>().joinLobby(widget.lobbyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return await _showLeaveConfirmation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Lobby'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _showLeaveConfirmation()) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: Consumer<LobbyProvider>(
          builder: (context, lobbyProvider, child) {
            final lobby = lobbyProvider.currentLobby;

            // Check if game is starting and navigate all players
            if (lobby?.status == LobbyStatus.starting) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _navigateToGame(lobby!);
              });
            }

            if (lobbyProvider.isLoading && lobby == null) {
              return Center(child: CircularProgressIndicator());
            }

            if (lobby == null) {
              return _buildLobbyNotFound();
            }

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLobbyHeader(lobby),
                        SizedBox(height: 24),
                        _buildGameSettings(lobby),
                        SizedBox(height: 24),
                        _buildPlayersList(lobby),
                        if (lobby.isPrivate) ...[
                          SizedBox(height: 24),
                          _buildAccessCodeSection(lobby),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildBottomActions(lobby, lobbyProvider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLobbyHeader(Lobby lobby) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getGameModeIcon(lobby.gameMode),
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGameModeDisplayName(lobby.gameMode),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Host: ${lobby.hostPlayerName}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(lobby.status),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people, size: 20, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text('${lobby.currentPlayers}/${lobby.maxPlayers} players'),
                SizedBox(width: 16),
                if (lobby.isPrivate) ...[
                  Icon(Icons.lock, size: 20, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text('Private'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameSettings(Lobby lobby) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12),
            _buildSettingRow('Difficulty', lobby.gameSettings.difficulty.toUpperCase()),
            _buildSettingRow(
                'Time Limit',
                lobby.gameSettings.timeLimit != null
                    ? _formatTimeLimit(lobby.gameSettings.timeLimit!)
                    : 'No limit'
            ),
            _buildSettingRow(
                'Hints',
                lobby.gameSettings.allowHints ? 'Allowed' : 'Disabled'
            ),
            _buildSettingRow(
                'Mistakes',
                lobby.gameSettings.allowMistakes
                    ? 'Max ${lobby.gameSettings.maxMistakes}'
                    : 'Disabled'
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList(Lobby lobby) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Players (${lobby.currentPlayers}/${lobby.maxPlayers})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12),
            ...lobby.playersList.map((player) => _buildPlayerItem(player, lobby)),
            // Show empty slots
            for (int i = lobby.currentPlayers; i < lobby.maxPlayers; i++)
              _buildEmptySlot(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerItem(Player player, Lobby lobby) {
    final isHost = player.id == lobby.hostPlayerId;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHost ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHost ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: player.avatarUrl != null
                ? NetworkImage(player.avatarUrl!)
                : null,
            child: player.avatarUrl == null
                ? Icon(Icons.person, size: 18)
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.name,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (isHost) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'HOST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Rating: ${player.rating}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.circle, color: Colors.green, size: 12), // Online indicator
        ],
      ),
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.withOpacity(0.3),
            child: Icon(Icons.person_add, size: 18, color: Colors.grey),
          ),
          SizedBox(width: 12),
          Text(
            'Waiting for player...',
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessCodeSection(Lobby lobby) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Access Code',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      lobby.accessCode ?? '',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: lobby.accessCode ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Access code copied!')),
                    );
                  },
                  icon: Icon(Icons.copy),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Share this code with friends to let them join',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(Lobby lobby, LobbyProvider lobbyProvider) {
    return Container(
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
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                if (await _leaveLobby()) {
                  Navigator.pop(context);
                }
              },
              child: Text('Leave Lobby'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (lobbyProvider.isHost && lobby.status == LobbyStatus.waiting) ...[
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: lobby.currentPlayers >= 2 ? _startGame : null,
                child: lobbyProvider.isLoading
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text('Start Game'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLobbyNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Lobby not found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          Text('This lobby may have been deleted or expired'),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(LobbyStatus status) {
    Color color;
    String text;

    switch (status) {
      case LobbyStatus.waiting:
        color = Colors.green;
        text = 'Waiting';
        break;
      case LobbyStatus.starting:
        color = Colors.orange;
        text = 'Starting';
        break;
      case LobbyStatus.inProgress:
        color = Colors.blue;
        text = 'In Progress';
        break;
      case LobbyStatus.completed:
        color = Colors.grey;
        text = 'Completed';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<bool> _showLeaveConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave Lobby'),
        content: Text('Are you sure you want to leave this lobby?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Leave'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _leaveLobby() async {
    final success = await context.read<LobbyProvider>().leaveLobby();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to leave lobby'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return success;
  }

  Future<void> _startGame() async {
    print('🎮 Starting game...');
    print('Current user: ${FirebaseAuth.instance.currentUser?.uid}');
    print('Lobby host: ${context.read<LobbyProvider>().currentLobby?.hostPlayerId}');
    print('Player count: ${context.read<LobbyProvider>().currentLobby?.currentPlayers}');

    try {
      final success = await context.read<LobbyProvider>().startGame();
      print('Start game result: $success');

      if (!success && mounted) {
        final error = context.read<LobbyProvider>().error;
        print('❌ Start game failed with error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start game: ${error ?? "Unknown error"}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      print('✅ Game started successfully');
    } catch (e) {
      print('❌ Exception starting game: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    // Don't navigate here - let the status change trigger navigation for all players
  }

  void _navigateToGame(Lobby lobby) {
    // Prevent multiple navigations
    if (_hasNavigatedToGame) return;
    _hasNavigatedToGame = true;

    print('🎮 Navigating to game for lobby: ${lobby.id}');

    // Generate puzzle locally (each player generates the same puzzle using lobby ID as seed)
    Map<String, dynamic> puzzle = _generateDeterministicPuzzle(lobby);

    // Navigate to multiplayer game screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MultiplayerSudokuScreen(
          lobby: lobby,
          puzzle: puzzle,
        ),
      ),
    );
  }

  // Generate the same puzzle for all players using lobby ID as seed
  Map<String, dynamic> _generateDeterministicPuzzle(Lobby lobby) {
    // Use lobby ID to create a deterministic seed
    final lobbyIdHash = lobby.id.hashCode;

    // For now, use a simple deterministic puzzle based on lobby ID
    // This ensures all players get the same puzzle

    // Simple deterministic puzzle (same for all players in this lobby)
    return {
      'puzzle': [
        [5, 3, 0, 0, 7, 0, 0, 0, 0],
        [6, 0, 0, 1, 9, 5, 0, 0, 0],
        [0, 9, 8, 0, 0, 0, 0, 6, 0],
        [8, 0, 0, 0, 6, 0, 0, 0, 3],
        [4, 0, 0, 8, 0, 3, 0, 0, 1],
        [7, 0, 0, 0, 2, 0, 0, 0, 6],
        [0, 6, 0, 0, 0, 0, 2, 8, 0],
        [0, 0, 0, 4, 1, 9, 0, 0, 5],
        [0, 0, 0, 0, 8, 0, 0, 7, 9]
      ],
      'solution': [
        [5, 3, 4, 6, 7, 8, 9, 1, 2],
        [6, 7, 2, 1, 9, 5, 3, 4, 8],
        [1, 9, 8, 3, 4, 2, 5, 6, 7],
        [8, 5, 9, 7, 6, 1, 4, 2, 3],
        [4, 2, 6, 8, 5, 3, 7, 9, 1],
        [7, 1, 3, 9, 2, 4, 8, 5, 6],
        [9, 6, 1, 5, 3, 7, 2, 8, 4],
        [2, 8, 7, 4, 1, 9, 6, 3, 5],
        [3, 4, 5, 2, 8, 6, 1, 7, 9]
      ],
      'difficulty': lobby.gameSettings.difficulty,
      'id': 'lobby-${lobby.id}',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
  }


  IconData _getGameModeIcon(GameMode mode) {
    switch (mode) {
      case GameMode.classic:
        return Icons.grid_3x3;
      case GameMode.powerup:
        return Icons.flash_on;
      case GameMode.tournament:
        return Icons.emoji_events;
    }
  }

  String _getGameModeDisplayName(GameMode mode) {
    switch (mode) {
      case GameMode.classic:
        return 'Classic Mode';
      case GameMode.powerup:
        return 'Power-Up Mode';
      case GameMode.tournament:
        return 'Tournament';
    }
  }

  String _formatTimeLimit(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m${remainingSeconds > 0 ? ' ${remainingSeconds}s' : ''}';
    } else {
      return '${seconds}s';
    }
  }
}