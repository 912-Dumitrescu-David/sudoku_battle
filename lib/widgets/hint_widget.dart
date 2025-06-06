import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sudoku_provider.dart';

class SudokuHintWidget extends StatelessWidget {
  const SudokuHintWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SudokuProvider>(
      builder: (context, provider, child) {
        final canUseHint = provider.canUseHint();
        final hintsRemaining = provider.hintsRemaining;
        final hasSelectedCell = provider.selectedRow != null && provider.selectedCol != null;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Hint button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: canUseHint ? () => provider.useHint() : null,
                  icon: Icon(
                    Icons.lightbulb,
                    color: canUseHint ? Colors.amber : Colors.grey,
                  ),
                  label: Text(
                    canUseHint ? 'Use Hint' : hasSelectedCell ? 'No Hints Left' : 'Select Cell First',
                    style: TextStyle(
                      color: canUseHint ? Colors.white : Colors.grey,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canUseHint ? Colors.amber[600] : Colors.grey[300],
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              SizedBox(width: 12),

              // Hints remaining indicator
              Expanded(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '$hintsRemaining',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: 12),

              // Cell selection status
              Expanded(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: hasSelectedCell
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasSelectedCell
                          ? Colors.green.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasSelectedCell ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 16,
                        color: hasSelectedCell ? Colors.green : Colors.grey,
                      ),
                      SizedBox(width: 4),
                      Text(
                        hasSelectedCell ? 'Ready' : 'Select',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: hasSelectedCell ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}