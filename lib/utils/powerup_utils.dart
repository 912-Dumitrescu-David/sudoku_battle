import 'package:flutter/material.dart';
import '../models/powerup_model.dart';

class PowerupUtils {
  static Color getColor(PowerupType type) {
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
      default:
        return Color(0xFF9C27B0); // Purple fallback
    }
  }

  static String getIcon(PowerupType type) {
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
      default:
        return '⭐';
    }
  }

  static String getDisplayName(PowerupType type) {
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
      default:
        return 'Unknown Powerup';
    }
  }

  static String getDescription(PowerupType type) {
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
      default:
        return 'Unknown powerup effect';
    }
  }

  static String getColorHex(PowerupType type) {
    switch (type) {
      case PowerupType.revealTwoCells:
        return '#4CAF50';
      case PowerupType.freezeOpponent:
        return '#2196F3';
      case PowerupType.extraHints:
        return '#FF9800';
      case PowerupType.clearMistakes:
        return '#9C27B0';
      case PowerupType.timeBonus:
        return '#F44336';
      case PowerupType.showSolution:
        return '#607D8B';
      case PowerupType.shield:
        return '#795548';
      case PowerupType.bomb:
        return '#FF5722';
      default:
        return '#9C27B0';
    }
  }
}