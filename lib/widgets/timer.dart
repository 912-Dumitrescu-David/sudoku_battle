import 'package:flutter/material.dart';

class SudokuTimerDisplay extends StatelessWidget {
  final String time;

  const SudokuTimerDisplay({
    Key? key,
    required this.time,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            time,
            style: const TextStyle(fontSize: 16, color: Colors.blue),
          ),
        ],
      ),
    );
  }
}
