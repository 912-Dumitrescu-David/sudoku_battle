import 'package:flutter/material.dart';
import '../models/lobby_model.dart';

class LobbyCard extends StatelessWidget {
  final Lobby lobby;
  final VoidCallback onJoin;

  const LobbyCard({
    Key? key,
    required this.lobby,
    required this.onJoin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onJoin,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              SizedBox(height: 12),
              _buildGameInfo(context),
              SizedBox(height: 12),
              _buildPlayersInfo(context),
              SizedBox(height: 12),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          _getGameModeIcon(),
          color: Theme.of(context).primaryColor,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGameModeDisplayName(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Host: ${lobby.hostPlayerName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        _buildStatusChip(context),
      ],
    );
  }

  Widget _buildGameInfo(BuildContext context) {
    return Row(
      children: [
        _buildInfoChip(
          context,
          icon: Icons.speed,
          label: _getDifficultyDisplayName(),
          color: _getDifficultyColor(),
        ),
        SizedBox(width: 8),
        if (lobby.gameSettings.timeLimit != null)
          _buildInfoChip(
            context,
            icon: Icons.timer,
            label: _formatTimeLimit(),
            color: Colors.orange,
          ),
        if (lobby.gameSettings.allowHints)
          Padding(
            padding: EdgeInsets.only(left: 8),
            child: _buildInfoChip(
              context,
              icon: Icons.lightbulb_outline,
              label: 'Hints',
              color: Colors.blue,
            ),
          ),
      ],
    );
  }

  Widget _buildPlayersInfo(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.people,
          size: 20,
          color: Colors.grey[600],
        ),
        SizedBox(width: 8),
        Text(
          '${lobby.currentPlayers}/${lobby.maxPlayers} players',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        SizedBox(width: 16),
        Expanded(
          child: LinearProgressIndicator(
            value: lobby.currentPlayers / lobby.maxPlayers,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              lobby.currentPlayers == lobby.maxPlayers
                  ? Colors.green
                  : Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final canJoin = lobby.currentPlayers < lobby.maxPlayers &&
        lobby.status == LobbyStatus.waiting;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _formatCreatedTime(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[500],
          ),
        ),
        ElevatedButton(
          onPressed: canJoin ? onJoin : null,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
          child: Text(canJoin ? 'Join' : 'Full'),
        ),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    Color chipColor;
    String statusText;

    switch (lobby.status) {
      case LobbyStatus.waiting:
        chipColor = Colors.green;
        statusText = 'Waiting';
        break;
      case LobbyStatus.starting:
        chipColor = Colors.orange;
        statusText = 'Starting';
        break;
      case LobbyStatus.inProgress:
        chipColor = Colors.blue;
        statusText = 'In Progress';
        break;
      case LobbyStatus.completed:
        chipColor = Colors.grey;
        statusText = 'Completed';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor, width: 1),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoChip(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
      }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getGameModeIcon() {
    switch (lobby.gameMode) {
      case GameMode.classic:
        return Icons.grid_3x3;
      case GameMode.powerup:
        return Icons.flash_on;
      case GameMode.coop:
        return Icons.emoji_events;
    }
  }

  String _getGameModeDisplayName() {
    switch (lobby.gameMode) {
      case GameMode.classic:
        return 'Classic Mode';
      case GameMode.powerup:
        return 'Power-Up Mode';
      case GameMode.coop:
        return 'Co-op Mode';
    }
  }

  String _getDifficultyDisplayName() {
    return lobby.gameSettings.difficulty.toUpperCase();
  }

  Color _getDifficultyColor() {
    switch (lobby.gameSettings.difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      case 'expert':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTimeLimit() {
    if (lobby.gameSettings.timeLimit == null) return 'No limit';

    final minutes = lobby.gameSettings.timeLimit! ~/ 60;
    final seconds = lobby.gameSettings.timeLimit! % 60;

    if (minutes > 0) {
      return '${minutes}m${seconds > 0 ? ' ${seconds}s' : ''}';
    } else {
      return '${seconds}s';
    }
  }

  String _formatCreatedTime() {
    final now = DateTime.now();
    final difference = now.difference(lobby.createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}