import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {

    // check current user
    final myId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),

      // chat crated in fireabse
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participantIds', arrayContains: myId)

        // recent text er jonne decendong order
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('No conversations yet', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      'Messages you send or receive will show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }


          //show all chats
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final data = chats[index].data() as Map<String, dynamic>;
              final participants = List<String>.from(data['participantIds'] ?? []);
              final otherUserId = participants.firstWhere((id) => id != myId, orElse: () => '');
              final lastMessage = data['lastMessage'] ?? '';
              final itemId = data['itemId'] ?? '';

              return FutureBuilder<DocumentSnapshot>(

                // irems access koi
                future: FirebaseFirestore.instance.collection('items').doc(itemId).get(),
                builder: (context, itemSnapshot) {
                  String itemTitle = 'Item';
                  if (itemSnapshot.hasData && itemSnapshot.data!.exists) {
                    final itemData = itemSnapshot.data!.data() as Map<String, dynamic>;
                    itemTitle = itemData['title'] ?? 'Item';
                  }
                // display all of my chats
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF2F8F5B),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(itemTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            itemId: itemId,
                            itemTitle: itemTitle,
                            otherUserId: otherUserId,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}