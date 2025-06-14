import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

class ResultScreen extends StatelessWidget {
  final bool isWin;
  final String time;
  final int solvedBlocks;
  final int totalToSolve;

  const ResultScreen({
    super.key,
    required this.isWin,
    required this.time,
    required this.solvedBlocks,
    required this.totalToSolve,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isWin ? 'Congratulations!' : 'Game Over'),
        backgroundColor: isWin ? Colors.green : Colors.red,
        actions: [
          IconButton(
            icon: Icon(Icons.brightness_6),
            tooltip: 'Toggle theme',
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isWin ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              color: isWin ? Colors.green : Colors.red,
              size: 72,
            ),
            SizedBox(height: 16),
            Text(
              isWin ? 'You Win!' : 'Try Again!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isWin ? Colors.green : Colors.red,
              ),
            ),
            SizedBox(height: 16),
            Text('Time: $time', style: TextStyle(fontSize: 20)),
            SizedBox(height: 12),
            Text(
              'Progress: $solvedBlocks / $totalToSolve',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
