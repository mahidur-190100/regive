import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item.dart';
import 'item_detail_screen.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Listings'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'My Items'),
              Tab(text: 'Claimed by Me'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MyOwnedItemsTab(),
            _MyClaimedItemsTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------- Shared helpers ----------------

Color _statusColor(String status) {
  switch (status) {
    case 'available':
      return const Color(0xFF2F8F5B);
    case 'claimed':
      return const Color(0xFFC8963E);
    case 'given':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'available':
      return 'Available';
    case 'claimed':
      return 'Claimed';
    case 'given':
      return 'Given Away';
    default:
      return status;
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Listing?'),
      content: const Text(
        'This will permanently remove this item from the database. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return confirmed == true;
}

Widget _itemLeadingImage(Item item) {
  return item.imageUrl != null
      ? ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: Image.network(
      item.imageUrl!,
      width: 50,
      height: 50,
      fit: BoxFit.cover,
    ),
  )
      : Container(
    width: 50,
    height: 50,
    color: Colors.grey.shade200,
    child: const Icon(Icons.image, color: Colors.grey),
  );
}

// ---------------- Tab 1: Items I own (listed by me) ----------------

class _MyOwnedItemsTab extends StatelessWidget {
  const _MyOwnedItemsTab();

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .where('ownerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items =
        snapshot.data!.docs.map((doc) => Item.fromFirestore(doc)).toList();

        if (items.isEmpty) {
          return const Center(
            child: Text(
              "You haven't listed any items yet.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Dismissible(
              key: Key(item.itemId),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmDelete(context),
              onDismissed: (_) async {
                await FirebaseFirestore.instance
                    .collection('items')
                    .doc(item.itemId)
                    .delete();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"${item.title}" deleted.')),
                  );
                }
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: _itemLeadingImage(item),
                  title: Text(item.title),
                  subtitle: Text(
                    _statusLabel(item.status),
                    style: TextStyle(
                      color: _statusColor(item.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------- Tab 2: Items I've claimed from other users ----------------

class _MyClaimedItemsTab extends StatelessWidget {
  const _MyClaimedItemsTab();

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .where('claimedBy', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items =
        snapshot.data!.docs.map((doc) => Item.fromFirestore(doc)).toList();

        if (items.isEmpty) {
          return const Center(
            child: Text(
              "You haven't claimed any items yet.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: _itemLeadingImage(item),
                title: Text(item.title),
                subtitle: Text(
                  _statusLabel(item.status),
                  style: TextStyle(
                    color: _statusColor(item.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                // Tapping goes to detail screen, where the "Unclaim" button
                // is already correctly shown only to the user who claimed it.
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}