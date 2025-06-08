// widgets/powerup_inventory_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/powerup_model.dart';
import '../providers/powerup_provider.dart';
import '../utils/powerup_utils.dart';
/// Widget to display powerup inventory
class PowerupInventory extends StatelessWidget {
  const PowerupInventory({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PowerupProvider>(
      builder: (context, powerupProvider, child) {
        final powerups = powerupProvider.playerPowerups;

        if (powerups.isEmpty) {
          return SizedBox.shrink();
        }

        return Container(
          height: 80,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              Text(
                'Powerups',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              SizedBox(height: 4),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: powerups.length,
                  itemBuilder: (context, index) {
                    final powerup = powerups[index];
                    return PowerupInventoryItem(
                      powerup: powerup,
                      onTap: () => _usePowerup(context, powerup),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _usePowerup(BuildContext context, PlayerPowerup powerup) async {
    final powerupProvider = context.read<PowerupProvider>();

    // Show confirmation dialog for certain powerups
    if (powerup.type == PowerupType.freezeOpponent ||
        powerup.type == PowerupType.showSolution) {
      final confirmed = await _showUsePowerupDialog(context, powerup.type);
      if (!confirmed) return;
    }

    final success = await powerupProvider.usePowerup(powerup.id, powerup.type);

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to use ${PowerupUtils.getDisplayName(powerup.type)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _showUsePowerupDialog(BuildContext context, PowerupType type) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Use ${PowerupUtils.getDisplayName(type)}?'),
        content: Text(PowerupUtils.getDescription(type)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Use'),
          ),
        ],
      ),
    ) ?? false;
  }
}

/// Individual powerup item in inventory
class PowerupInventoryItem extends StatelessWidget {
  final PlayerPowerup powerup;
  final VoidCallback onTap;

  const PowerupInventoryItem({
    Key? key,
    required this.powerup,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = PowerupUtils.getColor(powerup.type);

    return Container(
      width: 60,
      margin: EdgeInsets.only(right: 8),
      child: Material(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  PowerupUtils.getIcon(powerup.type),
                  style: TextStyle(fontSize: 20),
                ),
                SizedBox(height: 2),
                Text(
                  PowerupUtils.getDisplayName(powerup.type),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}