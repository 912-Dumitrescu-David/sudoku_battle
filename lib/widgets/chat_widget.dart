import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:profanity_filter/profanity_filter.dart';


class LobbyChat extends StatefulWidget {
  final String lobbyId;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  const LobbyChat({
    Key? key,
    required this.lobbyId,
    this.isExpanded = false,
    this.onToggleExpand,
  }) : super(key: key);

  @override
  State<LobbyChat> createState() => _LobbyChatState();
}

class _LobbyChatState extends State<LobbyChat> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isLoading) return;

    setState(() => _isLoading = true);

    final filter = ProfanityFilter();
    final cleanMessage = filter.censor(_controller.text.trim());


    try {
      await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'lobbies',
      )
          .collection('lobbies')
          .doc(widget.lobbyId)
          .collection('messages')
          .add({
        'senderUid': user?.uid,
        'senderName': user?.displayName ?? "Player",
        'text': cleanMessage, // Send the censored (clean) message
        'timestamp': FieldValue.serverTimestamp(),
        'localTimestamp': DateTime.now().millisecondsSinceEpoch,
      });

      _controller.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isExpanded) {
      // Collapsed view - just a header bar
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: InkWell(
          onTap: widget.onToggleExpand,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline,
                    color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'Chat',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                Icon(Icons.keyboard_arrow_up,
                    color: Theme.of(context).primaryColor),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          // Chat header
          Container(
            height: 50,
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.chat_bubble,
                    color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'Lobby Chat',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_down),
                  onPressed: widget.onToggleExpand,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),

          // Messages area
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instanceFor(
                app: Firebase.app(),
                databaseId: 'lobbies',
              )
                  .collection('lobbies')
                  .doc(widget.lobbyId)
                  .collection('messages')
                  .orderBy('localTimestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_outlined,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          'Say hello to your fellow players!',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isMyMessage = data['senderUid'] == user?.uid;
                    final senderName = data['senderName'] ?? 'Player';
                    final messageText = data['text'] ?? '';
                    final timestamp = data['timestamp'] as Timestamp?;

                    return _buildMessageBubble(
                      senderName: senderName,
                      message: messageText,
                      isMyMessage: isMyMessage,
                      timestamp: timestamp,
                    );
                  },
                );
              },
            ),
          ),

          // Message input area
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                    minLines: 1,
                    maxLength: 500,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                      return null; // Hide character counter
                    },
                  ),
                ),
                SizedBox(width: 8),
                Material(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _isLoading ? null : _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      child: _isLoading
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                          : Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String senderName,
    required String message,
    required bool isMyMessage,
    Timestamp? timestamp,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: isMyMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 12,
              child: Text(
                senderName[0].toUpperCase(),
                style: TextStyle(fontSize: 10),
              ),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMyMessage
                    ? Theme.of(context).primaryColor
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMyMessage)
                    Text(
                      senderName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  Text(
                    message,
                    style: TextStyle(
                      color: isMyMessage ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (timestamp != null)
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMyMessage
                            ? Colors.white70
                            : Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isMyMessage) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 12,
              child: Text(
                senderName[0].toUpperCase(),
                style: TextStyle(fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}