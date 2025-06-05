import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_battle/screens/lobby_screen.dart';
import 'package:sudoku_battle/screens/profile_screen.dart';
import '../providers/theme_provider.dart';
import 'difficulty_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName
        : user?.email ?? "player";
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku Battle'),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundImage:
              (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                  ? const Icon(Icons.person)
                  : null,
            ),
            onPressed: () async {
              final shouldRefresh = await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              if (shouldRefresh == true) {
                setState(() {}); // Refresh HomeScreen to show updated info
              }
            },
          ),
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
            Text(
              'Hello, $displayName!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _goToClassicMode(context),
              child: const Text('Classic Mode'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _goToMultiplayer(context);
              },
              child: const Text('Multiplayer'),
            ),
          ],
        ),
      ),
    );
  }

  void _goToClassicMode(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DifficultyScreen()),
    );
  }
  void _goToMultiplayer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LobbyScreen()),
    );
  }
}
