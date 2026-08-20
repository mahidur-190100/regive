import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String itemId;
  final String itemTitle;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.itemId,
    required this.itemTitle,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}


// chat id generation
class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  late String _chatId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final myId = FirebaseAuth.instance.currentUser!.uid;
    // Deterministic chat ID: same two users + same item = same chat, always
    final ids = [myId, widget.otherUserId]..sort();
    _chatId = '${widget.itemId}_${ids[0]}_${ids[1]}';
  }



  // send message generation
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // check current user
    final myId = FirebaseAuth.instance.currentUser!.uid;
    setState(() => _isSending = true);
    _messageController.clear();

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);


    // chat document create
    await chatRef.set({
      'itemId': widget.itemId,
      'participantIds': [myId, widget.otherUserId],
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

// add the actual message
    await chatRef.collection('messages').add({
      'senderId': myId,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });


    // Create a notification for the OTHER person
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': widget.otherUserId,
      'type': 'message',
      'body': '${widget.itemTitle}: $text',
      'itemId': widget.itemId,
      'fromUserId': myId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text(widget.itemTitle)),
      body: Column(
        children: [
          Expanded(

            // auto refres and show latest message by descending
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('sentAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Say hello ', style: TextStyle(color: Colors.grey)),
                  );
                }

                // list kora latest msg  dekhabo last e
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == myId;

                    //align kora left e other rigt e current user
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF2F8F5B) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        child: Text(
                          data['text'] ?? '',
                          style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2F8F5B),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                          height: 16, width: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}