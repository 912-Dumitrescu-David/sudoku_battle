import 'package:flutter/material.dart';
import 'home_screen.dart';

class WinScreen extends StatelessWidget {
  const WinScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use a pleasant background color if desired
      appBar: AppBar(
        title: const Text('You Win!'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Congratulations, you solved the puzzle!',
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
