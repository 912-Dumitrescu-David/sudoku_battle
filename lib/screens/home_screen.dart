import 'package:flutter/material.dart';
import 'difficulty_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  void _goToClassicMode(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DifficultyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku Battle'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _goToClassicMode(context),
          child: const Text('Classic Mode'),
        ),
      ),
    );
  }
}
