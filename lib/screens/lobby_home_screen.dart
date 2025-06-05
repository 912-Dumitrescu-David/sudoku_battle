import 'package:flutter/material.dart';
import 'package:sudoku_battle/screens/public_lobby_screen.dart';
import 'create_lobby_screen.dart';
import 'join_private_lobby_screen.dart';

class LobbyHomeScreen extends StatelessWidget {
  const LobbyHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Multiplayer Lobby")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CreateLobbyScreen(isPublic: true)),
                  );
                },
                child: const Text("Create Public Lobby"),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CreateLobbyScreen(isPublic: false)),
                  );
                },
                child: const Text("Create Private Lobby"),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => JoinPrivateLobbyScreen()),
                  );
                },
                child: const Text("Join Private Lobby"),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => PublicLobbyScreen()),
                  );
                },
                child: const Text("See All Public Games"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

