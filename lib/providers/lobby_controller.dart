import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lobby_model.dart';

class LobbyController {
  final CollectionReference lobbiesCollection =
  FirebaseFirestore.instance.collection('lobbies');


  // Generate a unique 6-char code
  Future<String> generateLobbyCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    String code;
    do {
      code = List.generate(6, (index) => chars[rnd.nextInt(chars.length)]).join();
      final exists = await lobbiesCollection.doc(code).get();
      if (!exists.exists) break;
    } while (true);
    return code;
  }

  // Create a new lobby
  Future<void> createLobby(Lobby lobby) async {
    await lobbiesCollection.doc(lobby.id).set(lobby.toMap());
  }

  // Get a stream of all public, waiting lobbies
  Stream<List<Lobby>> getPublicLobbies() {
    return lobbiesCollection
        .where('type', isEqualTo: 'public')
        .where('status', isEqualTo: 'waiting')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Lobby.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  // Join a lobby by code (returns the lobby if success, null if not found)
  Future<Lobby?> joinLobby(String code, String guestUid, String guestUsername) async {
    final doc = await lobbiesCollection.doc(code).get();
    if (!doc.exists) return null;
    final lobby = Lobby.fromMap(doc.data() as Map<String, dynamic>);

    // Only join if lobby is waiting and no guest yet
    if (lobby.status == 'waiting' && lobby.guestUid == null) {
      await lobbiesCollection.doc(code).update({
        'guestUid': guestUid,
        'guestUsername': guestUsername,
        'status': 'full', // or "started" if you want to auto-start
      });
      return lobby;
    }
    return null;
  }

  // Listen to a lobby by code (for game state, chat, etc)
  Stream<Lobby?> listenToLobby(String code) {
    return lobbiesCollection.doc(code).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return Lobby.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }
}
