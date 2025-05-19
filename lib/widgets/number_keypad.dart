import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_battle/providers/sudoku_provider.dart';
import 'package:sudoku_battle/providers/theme_provider.dart';

class NumberKeypad extends StatelessWidget {
  const NumberKeypad({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sudokuProvider = Provider.of<SudokuProvider>(context);
    final counts = sudokuProvider.calculateNumberCounts();
    final screenHeight = MediaQuery.of(context).size.height;
    // Adjust keypad height to about 12% of the screen height
    final keypadHeight = screenHeight * 0.12;
    final theme = Theme.of(context);

    return Container(
      height: keypadHeight,
      child: GridView.count(
        crossAxisCount: 9,
        childAspectRatio: 1,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(9, (index) {
          int number = index + 1;
          return GestureDetector(
            onTap: () => sudokuProvider.handleNumberInput(number),
            child: Container(
              margin: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              // Wrap the Column with a FittedBox to scale the contents down if needed
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Big number in blue
                    Text(
                      number.toString(),
                      style: const TextStyle(
                        fontSize: 32, // Adjust size as needed
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    // Space between the texts
                    const SizedBox(height: 2),
                    // Smaller grey text showing how many are left
                    Text(
                      counts[number].toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
