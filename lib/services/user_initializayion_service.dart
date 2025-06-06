// Add this to your main.dart or create a separate initialization service

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class UserInitializationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'lobbies',
  );
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize user data when they first sign in
  static Future<void> initializeUserIfNeeded() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      print('🔍 Checking if user data exists for: ${user.uid}');

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        print('📝 Creating user data for new user: ${user.uid}');

        // Create initial user data
        await _firestore.collection('users').doc(user.uid).set({
          'name': user.displayName ?? user.email?.split('@')[0] ?? 'Player',
          'username': user.displayName ?? user.email?.split('@')[0] ?? 'Player',
          'email': user.email ?? '',
          'rating': 1000, // Initial ELO rating
          'gamesPlayed': 0,
          'gamesWon': 0,
          'photoURL': user.photoURL,
          'avatarUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        });

        print('✅ User data created successfully');
      } else {
        print('✅ User data already exists');

        // Update last active timestamp
        await _firestore.collection('users').doc(user.uid).update({
          'lastActive': FieldValue.serverTimestamp(),
        });

        // Check if rating exists, if not add it
        final userData = userDoc.data() as Map<String, dynamic>;
        if (!userData.containsKey('rating')) {
          print('📝 Adding missing rating field');
          await _firestore.collection('users').doc(user.uid).update({
            'rating': 1000,
            'gamesPlayed': 0,
            'gamesWon': 0,
          });
        }
      }
    } catch (e) {
      print('❌ Error initializing user data: $e');
    }
  }

  /// Debug function to check current user data
  static Future<void> debugUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No authenticated user');
      return;
    }

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        print('🔍 User Data for ${user.uid}:');
        print('  Name: ${data['name']}');
        print('  Rating: ${data['rating']}');
        print('  Games Played: ${data['gamesPlayed']}');
        print('  Games Won: ${data['gamesWon']}');
        print('  Email: ${data['email']}');
      } else {
        print('❌ User document does not exist!');
      }
    } catch (e) {
      print('❌ Error fetching user data: $e');
    }
  }

  /// Force update user rating (for testing)
  static Future<void> setUserRating(int newRating) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'rating': newRating,
      });
      print('✅ Updated rating to $newRating for user ${user.uid}');
    } catch (e) {
      print('❌ Error updating rating: $e');
    }
  }
}