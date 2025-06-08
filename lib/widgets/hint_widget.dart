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

        return Positioned(
          bottom: 16,
          right: 16,
          child: GestureDetector(
            onTap: canUseHint ? () => provider.useHint() : null,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: canUseHint ? Colors.amber[600] : Colors.grey[300],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lightbulb,
                    size: 20,
                    color: canUseHint ? Colors.white : Colors.grey[600],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$hintsRemaining',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: canUseHint ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
