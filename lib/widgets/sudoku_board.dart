import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_battle/providers/sudoku_provider.dart';
import 'package:sudoku_battle/providers/theme_provider.dart';


class SudokuBoard extends StatelessWidget {
  const SudokuBoard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sudokuProvider = Provider.of<SudokuProvider>(context);
    final board = sudokuProvider.board;
    final givenCells = sudokuProvider.givenCells;
    final errorCells = sudokuProvider.errorCells;
    final selectedRow = sudokuProvider.selectedRow;
    final selectedCol = sudokuProvider.selectedCol;
    final theme = Theme.of(context);

    return AspectRatio(
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
          bool isSelected = (row == selectedRow && col == selectedCol);
          bool isError = errorCells[row][col];

          // Bold outline every 3rd cell, thin otherwise
          BorderSide bold = BorderSide(color: theme.dividerColor, width: 2);
          BorderSide normal = BorderSide(color: theme.dividerColor, width: 0.5);

          return GestureDetector(
            onTap: () => sudokuProvider.selectCell(row, col),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: row % 3 == 0 ? bold : normal,
                  left: col % 3 == 0 ? bold : normal,
                  right: (col + 1) % 3 == 0 ? bold : normal,
                  bottom: (row + 1) % 3 == 0 ? bold : normal,
                ),
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.3)
                    : theme.colorScheme.surface,
              ),
              child: Center(
                child: Text(
                  (board[row][col] == null || board[row][col] == 0)
                      ? ''
                      : board[row][col].toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                    givenCells[row][col] ? FontWeight.bold : FontWeight.normal,
                    color: isError
                        ? theme.colorScheme.error
                        : (givenCells[row][col]
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.primary),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}
