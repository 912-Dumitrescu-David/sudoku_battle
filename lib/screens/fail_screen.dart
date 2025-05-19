import 'package:flutter/material.dart';
import 'home_screen.dart';

class FailScreen extends StatelessWidget {
  const FailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use a red or somber background color if desired
      appBar: AppBar(
        title: const Text('Game Over'),
        backgroundColor: Colors.redAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Too many mistakes!\nBetter luck next time.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navigate back to home (or restart)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
