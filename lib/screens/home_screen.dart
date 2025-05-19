import 'package:flutter/material.dart';
import 'package:sudoku_battle/screens/profile_screen.dart';
import 'difficulty_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';


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
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName
        : user?.email ?? "player";
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku Battle'),
        // For example, in your HomeScreen's AppBar:
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundImage: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                  ? const Icon(Icons.person)
                  : null,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],

      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Hello, $displayName!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _goToClassicMode(context),
              child: const Text('Classic Mode'),
            ),
          ],
        ),
      ),

    );
  }
}
