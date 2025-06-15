import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/powerup_model.dart';
import '../providers/powerup_provider.dart';
import '../utils/powerup_utils.dart';

class PowerupEffectsDisplay extends StatelessWidget {
  const PowerupEffectsDisplay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PowerupProvider>(
      builder: (context, powerupProvider, child) {
        final effects = powerupProvider.activeEffects;

        if (effects.isEmpty) {
          return SizedBox.shrink();
        }

        return Container(
          padding: EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: effects.map((effect) => PowerupEffectChip(effect: effect)).toList(),
          ),
        );
      },
    );
  }
}

class PowerupEffectChip extends StatefulWidget {
  final PowerupEffect effect;

  const PowerupEffectChip({
    Key? key,
    required this.effect,
  }) : super(key: key);

  @override
  State<PowerupEffectChip> createState() => _PowerupEffectChipState();
}

class _PowerupEffectChipState extends State<PowerupEffectChip>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = PowerupUtils.getColor(widget.effect.type);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  PowerupUtils.getIcon(widget.effect.type),
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(width: 4),
                Text(
                  _getEffectText(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getEffectText() {
    switch (widget.effect.type) {
      case PowerupType.freezeOpponent:
        final remaining = widget.effect.expiresAt?.difference(DateTime.now()).inSeconds ?? 0;
        return 'Frozen ${remaining}s';
      case PowerupType.showSolution:
        final remaining = widget.effect.expiresAt?.difference(DateTime.now()).inSeconds ?? 0;
        return 'Solution ${remaining}s';
      case PowerupType.bomb:
        return 'Bomb Area';
      case PowerupType.shield:
        return 'Shield';
      default:
        return PowerupUtils.getDisplayName(widget.effect.type);
    }
  }
}