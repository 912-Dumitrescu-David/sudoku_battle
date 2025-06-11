import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lobby_provider.dart';
import '../models/lobby_model.dart';

class CreateLobbyDialog extends StatefulWidget {
  final Function(String lobbyId) onCreated;

  const CreateLobbyDialog({
    Key? key,
    required this.onCreated,
  }) : super(key: key);

  @override
  State<CreateLobbyDialog> createState() => _CreateLobbyDialogState();
}

class _CreateLobbyDialogState extends State<CreateLobbyDialog> {
  final _formKey = GlobalKey<FormState>();

  GameMode _selectedGameMode = GameMode.classic;
  String _selectedDifficulty = 'medium';
  bool _isPrivate = false;
  int _maxPlayers = 2;
  bool _allowHints = true;
  bool _allowMistakes = true;
  int _maxMistakes = 3;
  int? _timeLimit; // in seconds

  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create New Lobby'),
      content: Container(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGameModeSection(),
                SizedBox(height: 16),
                _buildGameSettings(),
                SizedBox(height: 16),
                _buildLobbySettings(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createLobby,
          child: _isCreating
              ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text('Create'),
        ),
      ],
    );
  }

  Widget _buildGameModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game Mode',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: 8),
        ...GameMode.values.map((mode) => RadioListTile<GameMode>(
          title: Text(_getGameModeDisplayName(mode)),
          subtitle: Text(_getGameModeDescription(mode)),
          value: mode,
          groupValue: _selectedGameMode,
          onChanged: (value) {
            setState(() {
              _selectedGameMode = value!;
            });
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
        )),
      ],
    );
  }

  Widget _buildGameSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game Settings',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Difficulty',
            border: OutlineInputBorder(),
          ),
          value: _selectedDifficulty,
          items: [
            DropdownMenuItem(value: 'easy', child: Text('Easy')),
            DropdownMenuItem(value: 'medium', child: Text('Medium')),
            DropdownMenuItem(value: 'hard', child: Text('Hard')),
            DropdownMenuItem(value: 'expert', child: Text('Expert')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedDifficulty = value!;
            });
          },
        ),
        SizedBox(height: 12),
        _buildTimeLimitSelector(),
        SizedBox(height: 12),
        CheckboxListTile(
          title: Text('Allow Hints'),
          value: _allowHints,
          onChanged: (value) {
            setState(() {
              _allowHints = value!;
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        CheckboxListTile(
          title: Text('Allow Mistakes'),
          subtitle: _allowMistakes ? Text('Max: $_maxMistakes mistakes') : null,
          value: _allowMistakes,
          onChanged: (value) {
            setState(() {
              _allowMistakes = value!;
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (_allowMistakes) _buildMaxMistakesSelector(),
      ],
    );
  }

  Widget _buildTimeLimitSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time Limit'),
        RadioListTile<int?>(
          title: Text('No time limit'),
          value: null,
          groupValue: _timeLimit,
          onChanged: (value) {
            setState(() {
              _timeLimit = value;
            });
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<int?>(
          title: Text('5 minutes'),
          value: 300,
          groupValue: _timeLimit,
          onChanged: (value) {
            setState(() {
              _timeLimit = value;
            });
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<int?>(
          title: Text('10 minutes'),
          value: 600,
          groupValue: _timeLimit,
          onChanged: (value) {
            setState(() {
              _timeLimit = value;
            });
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<int?>(
          title: Text('15 minutes'),
          value: 900,
          groupValue: _timeLimit,
          onChanged: (value) {
            setState(() {
              _timeLimit = value;
            });
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildMaxMistakesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Maximum Mistakes'),
        Slider(
          value: _maxMistakes.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: _maxMistakes.toString(),
          onChanged: (value) {
            setState(() {
              _maxMistakes = value.round();
            });
          },
        ),
      ],
    );
  }

  Widget _buildLobbySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lobby Settings',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<int>(
          decoration: InputDecoration(
            labelText: 'Maximum Players',
            border: OutlineInputBorder(),
          ),
          value: _maxPlayers,
          items: [
            DropdownMenuItem(value: 2, child: Text('2 Players')),
            DropdownMenuItem(value: 4, child: Text('4 Players')),
            DropdownMenuItem(value: 6, child: Text('6 Players')),
            DropdownMenuItem(value: 8, child: Text('8 Players')),
          ],
          onChanged: (value) {
            setState(() {
              _maxPlayers = value!;
            });
          },
        ),
        SizedBox(height: 12),
        SwitchListTile(
          title: Text('Private Lobby'),
          subtitle: Text(_isPrivate
              ? 'Players need access code to join'
              : 'Anyone can join this lobby'),
          value: _isPrivate,
          onChanged: (value) {
            setState(() {
              _isPrivate = value;
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Future<void> _createLobby() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    final request = LobbyCreationRequest(
      gameMode: _selectedGameMode,
      isPrivate: _isPrivate,
      maxPlayers: _maxPlayers,
      gameSettings: GameSettings(
        timeLimit: _timeLimit,
        allowHints: _allowHints,
        allowMistakes: _allowMistakes,
        maxMistakes: _maxMistakes,
        difficulty: _selectedDifficulty,
      ),
    );

    final lobbyProvider = context.read<LobbyProvider>();
    final lobbyId = await lobbyProvider.createLobby(request);

    setState(() {
      _isCreating = false;
    });

    if (lobbyId != null && mounted) {
      widget.onCreated(lobbyId);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lobbyProvider.error ?? 'Failed to create lobby'),
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

  String _getGameModeDescription(GameMode mode) {
    switch (mode) {
      case GameMode.classic:
        return 'Traditional Sudoku race';
      case GameMode.powerup:
        return 'Sudoku with special abilities';
      case GameMode.coop:
        return 'Collaborative Sudoku solving';
    }
  }
}