import 'package:flutter/material.dart';

class SudokuCorrectCounter extends StatelessWidget {
  final int solved;
  final int totalToSolve;

  const SudokuCorrectCounter({
    Key? key,
    required this.solved,
    required this.totalToSolve,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            '$solved / $totalToSolve',
            style: const TextStyle(fontSize: 16, color: Colors.green),
          ),
        ],
      ),
    );
  }
}
