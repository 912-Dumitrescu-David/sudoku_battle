import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sudoku_battle/models/lobby_model.dart';

class LobbyWaitingScreen extends StatelessWidget {
  final String lobbyId;

  const LobbyWaitingScreen({Key? key, required this.lobbyId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userUid = currentUser?.uid ?? "";

    return Scaffold(
      appBar: AppBar(title: const Text('Lobby Waiting Room')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('lobbies').doc(lobbyId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data();
          if (data == null) {
            return Center(child: Text('Lobby does not exist.'));
          }

          final lobby = Lobby.fromMap(data as Map<String, dynamic>);
          final bool isHost = lobby.hostUid == userUid;
          final bool guestConnected = lobby.guestUid != null && lobby.guestUid!.isNotEmpty;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Lobby ID: ${lobby.id}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text('You: ${isHost ? lobby.hostUsername : (lobby.guestUsername ?? "")}', style: TextStyle(fontSize: 18)),
                SizedBox(height: 16),
                guestConnected
                    ? Text('Opponent: ${isHost ? (lobby.guestUsername ?? "") : lobby.hostUsername}', style: TextStyle(fontSize: 18, color: Colors.blue))
                    : Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Waiting for another player to join...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
                SizedBox(height: 32),
                if (isHost && guestConnected)
                  ElevatedButton(
                    onPressed: () {
                      // Implement: start the game (update status to "started" etc.)
                    },
                    child: Text('Start Game'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
