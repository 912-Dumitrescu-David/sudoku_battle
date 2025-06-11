// widgets/sudoku_board.dart - MODIFIED FOR CO-OP
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // CO-OP: Needed for user ID check
import 'package:sudoku_battle/widgets/powerup_ui_widget.dart';
import '../providers/sudoku_provider.dart';
import '../providers/powerup_provider.dart';
import '../models/powerup_model.dart';
import '../models/lobby_model.dart'; // CO-OP: To get GameMode enum

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
                        // CO-OP: Color logic is now inside this method
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

  // CO-OP: Modified this method to handle co-op coloring
  Color _getCellColor(BuildContext context, int row, int col) {
    final sudokuProvider = context.read<SudokuProvider>();
    final theme = Theme.of(context);
    final isSelected = sudokuProvider.selectedRow == row && sudokuProvider.selectedCol == col;
    final isError = sudokuProvider.errorCells[row][col];

    // --- COLORING LOGIC (REORDERED) ---

    // 1. Always show errors in red, this has top priority.
    if (isError) {
      return theme.colorScheme.error.withOpacity(0.3);
    }

    // 2. If it's a co-op game, show player-specific colors
    if (sudokuProvider.currentGameMode == GameMode.coop) {
      final localPlayerId = FirebaseAuth.instance.currentUser?.uid;
      final cellPlayerId = sudokuProvider.playerCellEntries[row][col];
      if (cellPlayerId != null) {
        return cellPlayerId == localPlayerId
            ? Colors.blue.withOpacity(0.3)
            : Colors.green.withOpacity(0.3);
      }
    }

    // 3. If the cell is selected, highlight it.
    if (isSelected) {
      return theme.colorScheme.primary.withOpacity(0.2);
    }

    // 4. Handle powerup coloring
    // ... (powerup coloring logic) ...

    // 5. Default background color
    return theme.colorScheme.surface;
  }


  // ... (the rest of your helper methods for powerups remain the same)
  Widget _buildPowerupIndicatorSafe(powerupSpawn) { /* ... */ return Container(); }
  Widget _buildSolutionCellOverlay(int solutionNumber) { /* ... */ return Container(); }
  Color _getColorForPowerupType(PowerupType type) { /* ... */ return Colors.purple; }
  String _getIconForPowerupType(PowerupType type) { /* ... */ return '⭐'; }
  Color? _getPowerupColorSafe(PowerupProvider powerupProvider, int row, int col) { /* ... */ return null; }
}