// widgets/powerup_bar_widget.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/powerup_model.dart';
import '../providers/powerup_provider.dart';

class PowerupBar extends StatelessWidget {
  const PowerupBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PowerupProvider>(
      builder: (context, powerupProvider, child) {
        final playerPowerups = powerupProvider.playerPowerups;
        final screenHeight = MediaQuery.of(context).size.height;
        final barHeight = screenHeight * 0.08;

        return Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            border: Border(
              top: BorderSide(color: Colors.purple.withOpacity(0.3), width: 1),
            ),
          ),
          child: Column(
            children: [
              // Title bar
              Container(
                height: 20,
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flash_on, size: 12, color: Colors.purple),
                    SizedBox(width: 4),
                    Text(
                      'Powerups',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ),
              // Powerup grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 8,
                  childAspectRatio: 1,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  children: PowerupType.values.map((type) {
                    final count = _getPowerupCount(playerPowerups, type);
                    final isAvailable = count > 0;

                    return GestureDetector(
                      onTap: isAvailable ? () => _usePowerup(context, type, powerupProvider) : null,
                      child: Container(
                        margin: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? _getPowerupColor(type).withOpacity(0.3)
                              : Colors.grey.withOpacity(0.1),
                          border: Border.all(
                            color: isAvailable
                                ? _getPowerupColor(type)
                                : Colors.grey.withOpacity(0.3),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Powerup icon
                              Text(
                                _getPowerupIcon(type),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isAvailable ? null : Colors.grey,
                                ),
                              ),
                              // Count badge
                              if (count > 0)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _getPowerupColor(type),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _getPowerupCount(List<PlayerPowerup> powerups, PowerupType type) {
    return powerups.where((p) => p.type == type && !p.isUsed).length;
  }

  void _usePowerup(BuildContext context, PowerupType type, PowerupProvider powerupProvider) {
    PlayerPowerup? powerup;
    try {
      powerup = powerupProvider.playerPowerups
          .where((p) => p.type == type && !p.isUsed)
          .first;
    } catch (e) {
      return;
    }

    if (powerup != null) {
      if (type == PowerupType.freezeOpponent ||
          type == PowerupType.showSolution ||
          type == PowerupType.bomb) {
        _showUsePowerupDialog(context, type, () {
          powerupProvider.usePowerup(powerup!.id, type);
        });
      } else {
        powerupProvider.usePowerup(powerup.id, type);
      }
    }
  }

  Future<void> _showUsePowerupDialog(BuildContext context, PowerupType type, VoidCallback onConfirm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Use ${_getPowerupDisplayName(type)}?'),
        content: Text(_getPowerupDescription(type)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Use'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getPowerupColor(type),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onConfirm();
    }
  }

  Color _getPowerupColor(PowerupType type) {
    switch (type) {
      case PowerupType.revealTwoCells:
        return Color(0xFF4CAF50); // Green
      case PowerupType.freezeOpponent:
        return Color(0xFF2196F3); // Blue
      case PowerupType.extraHints:
        return Color(0xFFFF9800); // Orange
      case PowerupType.clearMistakes:
        return Color(0xFF9C27B0); // Purple
      case PowerupType.timeBonus:
        return Color(0xFFF44336); // Red
      case PowerupType.showSolution:
        return Color(0xFF607D8B); // Blue Grey
      case PowerupType.shield:
        return Color(0xFF795548); // Brown
      case PowerupType.bomb:
        return Color(0xFFFF5722); // Deep Orange
    }
  }

  String _getPowerupIcon(PowerupType type) {
    switch (type) {
      case PowerupType.revealTwoCells:
        return '🔍';
      case PowerupType.freezeOpponent:
        return '❄️';
      case PowerupType.extraHints:
        return '💡';
      case PowerupType.clearMistakes:
        return '🧹';
      case PowerupType.timeBonus:
        return '⏰';
      case PowerupType.showSolution:
        return '👁️';
      case PowerupType.shield:
        return '🛡️';
      case PowerupType.bomb:
        return '💣';
    }
  }

  String _getPowerupDisplayName(PowerupType type) {
    switch (type) {
      case PowerupType.revealTwoCells:
        return 'Reveal 2 Cells';
      case PowerupType.freezeOpponent:
        return 'Freeze Opponent';
      case PowerupType.extraHints:
        return 'Extra Hints';
      case PowerupType.clearMistakes:
        return 'Clear Mistakes';
      case PowerupType.timeBonus:
        return 'Time Bonus';
      case PowerupType.showSolution:
        return 'Show Solution';
      case PowerupType.shield:
        return 'Shield';
      case PowerupType.bomb:
        return 'Bomb';
    }
  }

  String _getPowerupDescription(PowerupType type) {
    switch (type) {
      case PowerupType.revealTwoCells:
        return 'Reveals the solution for two random empty cells';
      case PowerupType.freezeOpponent:
        return 'Freezes opponent for 10 seconds';
      case PowerupType.extraHints:
        return 'Gives you 2 additional hints';
      case PowerupType.clearMistakes:
        return 'Removes all your current mistakes and errors';
      case PowerupType.timeBonus:
        return 'Adds 60 seconds to the timer';
      case PowerupType.showSolution:
        return 'Shows the complete solution for 3 seconds';
      case PowerupType.shield:
        return 'Protects from the next opponent powerup';
      case PowerupType.bomb:
        return 'Clears a 3x3 area of opponent\'s completed cells';
    }
  }
}