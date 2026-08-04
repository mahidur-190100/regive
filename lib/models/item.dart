import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final String itemId;
  final String ownerId;
  final String title;
  final String description;
  final String? imageUrl;
  final String category;
  final String status; // available, claimed, given
  final double latitude;
  final double longitude;
  final DateTime? createdAt;

  Item({
    required this.itemId,
    required this.ownerId,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.category,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.createdAt,
  });

  factory Item.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final geo = data['location'] as GeoPoint?;
    return Item(
      itemId: doc.id,
      ownerId: data['ownerId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      category: data['category'] ?? 'Other',
      status: data['status'] ?? 'available',
      latitude: geo?.latitude ?? 0.0,
      longitude: geo?.longitude ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}