import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'item_detail_screen.dart';
import '../models/item.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  //diffrent icon based notifiacation
  IconData _iconFor(String type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_outline;
      case 'claimed':
        return Icons.handshake_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'message':
        return const Color(0xFF3F65B0);  //blue coloe
      case 'claimed':
        return const Color(0xFFC8963E); // gold color
      default:
        return Colors.grey;
    }
  }

  //notofication part
  Future<void> _markAllRead(String userId) async {
    final unread = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    for (final doc in unread.docs) {
      doc.reference.update({'read': true});
    }
  }

  Future<void> _handleTap(
      BuildContext context, Map<String, dynamic> data, String docId) async {
    // mark this one as read
    FirebaseFirestore.instance.collection('notifications').doc(docId).update({'read': true});

    final type = data['type'];
    final itemId = data['itemId'];
    if (itemId == null) return;




  // get full details of item
    final itemDoc = await FirebaseFirestore.instance.collection('items').doc(itemId).get();
    if (!itemDoc.exists || !context.mounted) return;
    final item = Item.fromFirestore(itemDoc);

    // for message
    if (type == 'message') {
      final fromUserId = data['fromUserId'];
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            itemId: itemId,
            itemTitle: item.title,
            otherUserId: fromUserId,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(userId),
            child: const Text('Mark all read', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('No notifications yet', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      'New messages and claims will show up here.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }


          // all notifiaction display
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final read = data['read'] ?? false;
              final type = data['type'] ?? '';
              final body = data['body'] ?? '';

              return Container(
                color: read ? Colors.white : const Color(0xFFEEF6F0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _colorFor(type).withOpacity(0.15),
                    child: Icon(_iconFor(type), color: _colorFor(type), size: 20),
                  ),
                  title: Text(
                    type == 'message' ? 'New message' : 'Item claimed',
                    style: TextStyle(fontWeight: read ? FontWeight.normal : FontWeight.bold),
                  ),
                  subtitle: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: read ? null : Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Color(0xFF2F8F5B), shape: BoxShape.circle),
                  ),
                  onTap: () => _handleTap(context, data, docs[index].id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}