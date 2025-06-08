import 'package:flutter/material.dart';

class SudokuMistakesCounter extends StatelessWidget {
  final int mistakes;
  final int maxMistakes;

  const SudokuMistakesCounter({
    Key? key,
    required this.mistakes,
    required this.maxMistakes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.close, color: Colors.red),
          const SizedBox(width: 4),
          Text(
            '$mistakes / $maxMistakes',
            style: const TextStyle(fontSize: 16, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
