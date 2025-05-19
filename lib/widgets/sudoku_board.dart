import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_battle/providers/sudoku_provider.dart';

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

          return GestureDetector(
            onTap: () => sudokuProvider.selectCell(row, col),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54, width: 0.5),
                color: isSelected ? Colors.lightBlueAccent.withOpacity(0.3) : Colors.white,
              ),
              child: Center(
                child: Text(
                  (board[row][col] == null || board[row][col] == 0)
                      ? ''
                      : board[row][col].toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: givenCells[row][col] ? FontWeight.bold : FontWeight.normal,
                    // If the cell is marked as an error, display red text.
                    color: isError
                        ? Colors.red
                        : (givenCells[row][col] ? Colors.black : Colors.blue),
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
