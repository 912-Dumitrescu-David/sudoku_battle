// Add this temporarily to your lobby screen for debugging
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DebugAuthWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Use your custom database
    final firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'lobbies',
    );

    return Card(
      color: Colors.blue.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text('🔍 Debug Info (Custom DB: lobbies)', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                final user = snapshot.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auth Status: ${user != null ? "✅ Signed In" : "❌ Not Signed In"}'),
                    if (user != null) ...[
                      Text('User ID: ${user.uid}'),
                      Text('Email: ${user.email ?? "No email"}'),
                    ],
                  ],
                );
              },
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await firestore
                            .collection('test')
                            .doc('debug-test')
                            .set({
                          'message': 'Test from Flutter to custom DB',
                          'timestamp': FieldValue.serverTimestamp(),
                          'user': FirebaseAuth.instance.currentUser?.uid,
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✅ Custom database write successful!'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        print('Custom database test error: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Custom database error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: Text('Test Custom DB'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        if (FirebaseAuth.instance.currentUser == null) {
                          // Sign in anonymously for testing
                          await FirebaseAuth.instance.signInAnonymously();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✅ Signed in anonymously'), backgroundColor: Colors.green),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✅ Already signed in'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Auth error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: Text('Test Auth'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}