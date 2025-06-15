import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sudoku_battle/widgets/powerup_ui_widget.dart';
import '../providers/sudoku_provider.dart';
import '../providers/powerup_provider.dart';
import '../models/powerup_model.dart';
import '../models/lobby_model.dart';
class SudokuBoard extends StatelessWidget {
  const SudokuBoard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<SudokuProvider, PowerupProvider>(
      builder: (context, sudokuProvider, powerupProvider, child) {
        final board = sudokuProvider.board;
        final solution = sudokuProvider.solution;
        final givenCells = sudokuProvider.givenCells;
        final errorCells = sudokuProvider.errorCells;
        final selectedRow = sudokuProvider.selectedRow;
        final selectedCol = sudokuProvider.selectedCol;
        final theme = Theme.of(context);

        final isPowerupMode = sudokuProvider.isPowerupModeEnabled;
        final shouldShowSolution = isPowerupMode && powerupProvider.shouldShowSolution;
        final isFrozen = isPowerupMode && powerupProvider.isFrozen;

        return Stack(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 9,
                ),
                itemCount: 81,
                itemBuilder: (context, index) {
                  int row = index ~/ 9;
                  int col = index % 9;

                  return GestureDetector(
                    onTap: () => sudokuProvider.selectCell(row, col),
                    child: Container(
                      decoration: BoxDecoration(
                        border: _getCellBorder(context, row, col),
                        color: _getCellColor(
                          context,
                          row, // Pass row
                          col, // Pass col
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (shouldShowSolution && (board[row][col] == null || board[row][col] == 0))
                            _buildSolutionCellOverlay(solution[row][col]),

                          Center(
                            child: Text(
                              (board[row][col] == null || board[row][col] == 0)
                                  ? ''
                                  : board[row][col].toString(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: givenCells[row][col] ? FontWeight.bold : FontWeight.normal,
                                color: errorCells[row][col]
                                    ? theme.colorScheme.error
                                    : (givenCells[row][col] ? theme.colorScheme.onSurface : theme.colorScheme.primary),
                              ),
                            ),
                          ),

                          if (isPowerupMode && powerupProvider.hasPowerupAt(row, col))
                            _buildPowerupIndicatorSafe(powerupProvider.getPowerupAt(row, col)!),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (isPowerupMode) ...[
              if (isFrozen) FreezeOverlay(remainingSeconds: powerupProvider.freezeTimeRemaining),
              if (shouldShowSolution) SolutionOverlay(solution: solution, remainingSeconds: powerupProvider.solutionShowTimeRemaining),
            ],
          ],
        );
      },
    );
  }

  Border _getCellBorder(BuildContext context, int row, int col) {
    final theme = Theme.of(context);
    BorderSide bold = BorderSide(color: theme.dividerColor, width: 2);
    BorderSide normal = BorderSide(color: theme.dividerColor, width: 0.5);

    return Border(
      top: row % 3 == 0 ? bold : normal,
      left: col % 3 == 0 ? bold : normal,
      right: (col + 1) % 3 == 0 ? bold : normal,
      bottom: (row + 1) % 3 == 0 ? bold : normal,
    );
  }

  Color _getCellColor(BuildContext context, int row, int col) {
    final sudokuProvider = context.read<SudokuProvider>();
    final theme = Theme.of(context);
    final isSelected = sudokuProvider.selectedRow == row && sudokuProvider.selectedCol == col;
    final isError = sudokuProvider.errorCells[row][col];

    if (isError) {
      return theme.colorScheme.error.withOpacity(0.3);
    }

    if (isSelected) {
      return theme.colorScheme.primary.withOpacity(0.2);
    }

    if (sudokuProvider.isPowerupModeEnabled) {
      Color? powerupColor = sudokuProvider.getPowerupColor(row, col);
      if (powerupColor != null) {
        return powerupColor.withOpacity(0.4);
      }
    }

    if (sudokuProvider.currentGameMode == GameMode.coop) {
      final localPlayerId = FirebaseAuth.instance.currentUser?.uid;
      final cellPlayerId = sudokuProvider.playerCellEntries[row][col];
      if (cellPlayerId != null) {
        return cellPlayerId == localPlayerId
            ? Colors.blue.withOpacity(0.3)
            : Colors.green.withOpacity(0.3);
      }
    }

    return theme.colorScheme.surface;
  }

  Widget _buildPowerupIndicatorSafe(powerupSpawn) {
    Color powerupColor = _getColorForPowerupType(powerupSpawn.type);

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: powerupColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _getIconForPowerupType(powerupSpawn.type),
          style: TextStyle(fontSize: 10),
        ),
      ),
    );
  }

  Widget _buildSolutionCellOverlay(int solutionNumber) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.3),
          border: Border.all(color: Colors.purple, width: 1),
        ),
        child: Center(
          child: Text(
            solutionNumber.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
              shadows: [
                Shadow(
                  color: Colors.white,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getColorForPowerupType(PowerupType type) {
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

  String _getIconForPowerupType(PowerupType type) {
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

  Color? _getPowerupColorSafe(PowerupProvider powerupProvider, int row, int col) {
    final powerup = powerupProvider.getPowerupAt(row, col);
    if (powerup == null) return null;
    return _getColorForPowerupType(powerup.type);
  }}