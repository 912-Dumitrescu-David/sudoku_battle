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
      child: Text(
        'Mistakes: $mistakes / $maxMistakes',
        style: const TextStyle(fontSize: 16, color: Colors.red),
      ),
    );
  }
}
