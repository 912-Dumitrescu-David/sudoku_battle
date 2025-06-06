// Add this widget temporarily to your ranked queue screen for debugging

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/ranking_service.dart';

class DebugRankingWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.yellow.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔧 Debug Tools (Remove in production)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),

            // Current user info
            FutureBuilder<Map<String, dynamic>?>(
              future: _getCurrentUserData(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final data = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User ID: ${FirebaseAuth.instance.currentUser?.uid ?? "None"}'),
                      Text('Rating: ${data['rating'] ?? "Not set"}'),
                      Text('Games: ${data['gamesPlayed'] ?? 0}'),
                    ],
                  );
                }
                return Text('Loading user data...');
              },
            ),

            SizedBox(height: 8),

            // Debug buttons
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _initializeUser(context),
                  child: Text('Init User'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                ElevatedButton(
                  onPressed: () => _checkQueue(context),
                  child: Text('Check Queue'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
                ElevatedButton(
                  onPressed: () => _clearQueue(context),
                  child: Text('Clear Queue'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                ElevatedButton(
                  onPressed: () => _testMatchmaking(context),
                  child: Text('Test Match'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                ),
                ElevatedButton(
                  onPressed: () => _forceMatch(context),
                  child: Text('Force Match'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _getCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final doc = await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'lobbies',
      ).collection('users').doc(user.uid).get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  void _initializeUser(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'lobbies',
      ).collection('users').doc(user.uid).set({
        'name': user.displayName ?? user.email?.split('@')[0] ?? 'Player',
        'username': user.displayName ?? user.email?.split('@')[0] ?? 'Player',
        'email': user.email ?? '',
        'rating': 1000,
        'gamesPlayed': 0,
        'gamesWon': 0,
        'photoURL': user.photoURL,
        'avatarUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ User initialized!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _checkQueue(BuildContext context) async {
    try {
      final snapshot = await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'lobbies',
      ).collection('rankedQueue').get();

      final queueCount = snapshot.docs.length;
      final players = snapshot.docs.map((doc) {
        final data = doc.data();
        return '${data['playerName']} (${data['rating']})';
      }).join(', ');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Queue: $queueCount players - $players'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _clearQueue(BuildContext context) async {
    try {
      final batch = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'lobbies',
      ).batch();

      final snapshot = await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'lobbies',
      ).collection('rankedQueue').get();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Queue cleared!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _testMatchmaking(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      print('🧪 Testing matchmaking for user: ${user.uid}');

      // First, check if user is in queue
      final queueDoc = await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'lobbies',
      ).collection('rankedQueue').doc(user.uid).get();

      if (!queueDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ User not in queue!'), backgroundColor: Colors.orange),
        );
        return;
      }

      print('✅ User is in queue, attempting to find match...');
      final lobbyId = await RankingService.findRankedMatch(user.uid);

      if (lobbyId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Match found: $lobbyId'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⏰ No match found - need another player in queue'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      print('❌ Matchmaking test error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _forceMatch(BuildContext context) async {
    try {
      // Get all players in queue
      final queueSnapshot = await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'lobbies',
      ).collection('rankedQueue').where('isMatched', isEqualTo: false).get();

      if (queueSnapshot.docs.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Need at least 2 players in queue'), backgroundColor: Colors.orange),
        );
        return;
      }

      final player1 = queueSnapshot.docs[0];
      final player2 = queueSnapshot.docs[1];

      print('🔄 Force matching: ${player1.data()['playerName']} vs ${player2.data()['playerName']}');

      final lobbyId = await RankingService.findRankedMatch(player1.id);

      if (lobbyId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Force match created: $lobbyId'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Force match failed'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}