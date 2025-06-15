import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lobby_model.dart';
import '../providers/lobby_provider.dart';
import '../services/lobby_service.dart';
import '../utils/sudoku_engine.dart';
import '../widgets/lobby_card.dart';
import '../widgets/create_lobby_dialog.dart';
import '../widgets/join_private_lobby_dialog.dart';
import 'lobby_detail_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({Key? key}) : super(key: key);

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  GameMode? _selectedGameMode;
  String? _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LobbyProvider>().initialize();
      _checkForExistingLobby();

    });
  }

  Future<void> _checkForExistingLobby() async {
    final lobbyProvider = context.read<LobbyProvider>();
    final existingLobby = await lobbyProvider.getCurrentUserLobby();

    if (existingLobby != null && mounted) {
      Navigator.pushNamed(context, '/lobby-detail', arguments: existingLobby.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Multiplayer Lobbies'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              context.read<LobbyProvider>().refreshLobbies();
            },
          ),
        ],
      ),
      body: Consumer<LobbyProvider>(
        builder: (context, lobbyProvider, child) {
          if (lobbyProvider.error != null) {
            return _buildErrorWidget(lobbyProvider.error!);
          }

          return Column(
            children: [
              _buildFilterSection(),
              _buildActionButtons(),
              Expanded(
                child: _buildLobbyList(lobbyProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Lobbies',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<GameMode>(
                  decoration: InputDecoration(
                    labelText: 'Game Mode',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedGameMode,
                  items: [
                    DropdownMenuItem(value: null, child: Text('All Modes')),
                    ...GameMode.values.map((mode) => DropdownMenuItem(
                      value: mode,
                      child: Text(_getGameModeDisplayName(mode)),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGameMode = value;
                    });
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedDifficulty,
                  items: [
                    DropdownMenuItem(value: null, child: Text('All Difficulties')),
                    DropdownMenuItem(value: 'easy', child: Text('Easy')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'hard', child: Text('Hard')),
                    DropdownMenuItem(value: 'expert', child: Text('Expert')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedDifficulty = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showCreateLobbyDialog(),
                  icon: Icon(Icons.add),
                  label: Text('Create Lobby'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showJoinPrivateLobbyDialog(),
                  icon: Icon(Icons.lock),
                  label: Text('Join Private'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Temporary test button
        ],
      ),
    );
  }

  Future<void> _testSudokuEngine() async {
    try {
      print('🧪 Testing SudokuEngine...');

      // Test each difficulty
      for (final difficulty in [Difficulty.easy, Difficulty.medium, Difficulty.hard, Difficulty.expert]) {
        print('Testing difficulty: $difficulty');

        final puzzleData = SudokuEngine.generatePuzzle(difficulty);
        print('✅ Generated puzzle for $difficulty');
        print('Keys: ${puzzleData.keys}');
        print('Puzzle type: ${puzzleData['puzzle'].runtimeType}');
        print('Solution type: ${puzzleData['solution'].runtimeType}');

        if (puzzleData['puzzle'] is List && puzzleData['solution'] is List) {
          final puzzle = puzzleData['puzzle'] as List;
          final solution = puzzleData['solution'] as List;
          print('Puzzle size: ${puzzle.length}x${puzzle.isNotEmpty ? puzzle[0].length : 0}');
          print('Solution size: ${solution.length}x${solution.isNotEmpty ? solution[0].length : 0}');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ SudokuEngine test completed! Check console.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ SudokuEngine test failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ SudokuEngine test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildLobbyList(LobbyProvider lobbyProvider) {
    final filteredLobbies = lobbyProvider.getFilteredLobbies(
      gameMode: _selectedGameMode,
      difficulty: _selectedDifficulty,
      hasSpace: true,
    );

    if (lobbyProvider.isLoading && filteredLobbies.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    if (filteredLobbies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No lobbies found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Text(
              'Create a new lobby or adjust your filters',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<LobbyProvider>().refreshLobbies();
      },
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: filteredLobbies.length,
        itemBuilder: (context, index) {
          final lobby = filteredLobbies[index];
          return LobbyCard(
            lobby: lobby,
            onJoin: () => _joinLobby(lobby),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          SizedBox(height: 16),
          Text(
            'Error',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<LobbyProvider>().refreshLobbies();
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showCreateLobbyDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateLobbyDialog(
        onCreated: (lobbyId) {
          Navigator.pop(context);
          _navigateToLobbyDetail(lobbyId);
        },
      ),
    );
  }

  void _showJoinPrivateLobbyDialog() {
    showDialog(
      context: context,
      builder: (context) => JoinPrivateLobbyDialog(
        onJoined: (lobbyId) async {
          print('🔗 Dialog onJoined called with lobby ID: $lobbyId');
          Navigator.pop(context);

          await Future.delayed(Duration(milliseconds: 300));

          if (mounted) {
            print('🔗 Navigating to lobby detail: $lobbyId');
            _navigateToLobbyDetail(lobbyId);
          }
        },
      ),
    );
  }

  void _navigateToLobbyDetail(String lobbyId) {
    print('🏠 Navigating to lobby detail screen for: $lobbyId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LobbyDetailScreen(lobbyId: lobbyId),
      ),
    );
  }

  Future<void> _joinLobby(Lobby lobby) async {
    final lobbyProvider = context.read<LobbyProvider>();

    if (!lobbyProvider.canJoinLobby(lobby)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot join this lobby')),
      );
      return;
    }

    final success = await lobbyProvider.joinPublicLobby(lobby.id);

    if (success && mounted) {
      _navigateToLobbyDetail(lobby.id);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lobbyProvider.error ?? 'Failed to join lobby'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getGameModeDisplayName(GameMode mode) {
    switch (mode) {
      case GameMode.classic:
        return 'Classic';
      case GameMode.powerup:
        return 'Power-Up';
      case GameMode.coop:
        return 'Co-op';
    }
  }
}