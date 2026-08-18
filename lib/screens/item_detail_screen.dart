import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/item.dart';
import 'chat_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final Item item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _isUpdating = false;

//owner ship check
  bool get _isOwner {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return currentUserId != null && currentUserId == widget.item.ownerId;
  }

  bool _currentUserClaimedIt(Map<String, dynamic> data) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return currentUserId != null && currentUserId == data['claimedBy'];
  }


  //status chnage
  Future<void> _updateStatus(String newStatus, {String? claimedBy}) async {
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.item.itemId)
          .update({
        'status': newStatus,
        'claimedBy': claimedBy,
      });


      if (newStatus == 'claimed') {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': widget.item.ownerId,
          'type': 'claimed',
          'body': '"${widget.item.title}" was claimed!',
          'itemId': widget.item.itemId,
          'fromUserId': FirebaseAuth.instance.currentUser?.uid,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'claimed'
                ? 'Item marked as Claimed!'
                : newStatus == 'given'
                ? 'Item marked as Given Away!'
                : 'Item is now Available again.',
          ),
          backgroundColor: const Color(0xFF2F8F5B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _confirmDelete() async {
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

    if (confirmed != true) return;

    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.item.itemId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing deleted.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title)),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('items')
            .doc(widget.item.itemId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This item no longer exists.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'available';
          final title = data['title'] ?? widget.item.title;
          final description = data['description'] ?? widget.item.description;
          final imageUrl = data['imageUrl'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 220,
                        color: Colors.grey.shade100,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 220,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.image, size: 48, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(status)),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                if (_isOwner) ...[
                  const Text(
                    'You listed this item',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  if (status == 'available')
                    _actionButton(
                      label: 'Mark as Given Away',
                      color: Colors.grey.shade800,
                      onPressed: () => _updateStatus('given'),
                    )
                  else if (status == 'claimed')
                    Column(
                      children: [
                        _actionButton(
                          label: 'Confirm Given Away',
                          color: Colors.grey.shade800,
                          onPressed: () => _updateStatus('given'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Waiting for the claimer to confirm or cancel.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Text(
                          'This item has been given away.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 10),
                        _actionButton(
                          label: 'Undo — Make Available Again',
                          color: const Color(0xFF2F8F5B),
                          onPressed: () => _updateStatus('available', claimedBy: null),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isUpdating ? null : _confirmDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Delete Listing', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ] else ...[
                  if (status == 'available')
                    _actionButton(
                      label: 'Claim This Item',
                      color: Colors.black,
                      onPressed: () => _updateStatus(
                        'claimed',
                        claimedBy: FirebaseAuth.instance.currentUser?.uid,
                      ),
                    )
                  else if (status == 'claimed')
                    _currentUserClaimedIt(data)
                        ? _actionButton(
                      label: 'Unclaim This Item',
                      color: const Color(0xFF3F65B0),
                      onPressed: () => _updateStatus('available', claimedBy: null),
                    )
                        : _disabledNotice('This item has already been claimed by someone.')
                  else
                    _disabledNotice('This item has been given away.'),

                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            itemId: widget.item.itemId,
                            itemTitle: title,
                            otherUserId: widget.item.ownerId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message Owner'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUpdating ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isUpdating
            ? const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        )
            : Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }

  Widget _disabledNotice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
      ),
    );
  }
}