import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatWidget extends StatefulWidget {
  final String lobbyId;
  const ChatWidget({required this.lobbyId});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final _controller = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  void _sendMessage() {
    if (_controller.text.trim().isNotEmpty) {
      FirebaseFirestore.instance
          .collection('lobbies')
          .doc(widget.lobbyId)
          .collection('messages')
          .add({
        'senderUid': user?.uid,
        'senderName': user?.displayName ?? "Player",
        'text': _controller.text.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('lobbies')
                .doc(widget.lobbyId)
                .collection('messages')
                .orderBy('timestamp')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return SizedBox();
              final messages = snapshot.data!.docs;
              return ListView(
                children: messages.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['senderName']),
                    subtitle: Text(data['text']),
                  );
                }).toList(),
              );
            },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(hintText: "Type a message..."),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send),
              onPressed: _sendMessage,
            )
          ],
        ),
      ],
    );
  }
}
