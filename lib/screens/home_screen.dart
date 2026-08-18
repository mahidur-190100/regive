import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../models/item.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'add_item_screen.dart';
import 'item_detail_screen.dart';
import 'my_listings_screen.dart';
import 'chat_list_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;
  bool _loadingLocation = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final double _maxDistanceMiles = 50;
  bool _nearbyOnly = false;

  final List<String> _categories = [
    'All',
    'Furniture',
    'Electronics',
    'Clothing',
    'Books',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final position = await LocationService.getCurrentLocation();
    setState(() {
      _currentPosition = position;
      _loadingLocation = false;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('ReGive'),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    tooltip: 'Notifications',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Messages',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatListScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'My Listings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyListingsScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _logout,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.black, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Nearby'),
                    avatar: Icon(
                      Icons.location_on,
                      size: 16,
                      color: _nearbyOnly ? Colors.white : const Color(0xFF3F65B0),
                    ),
                    selected: _nearbyOnly,
                    onSelected: (value) => setState(() => _nearbyOnly = value),
                    selectedColor: const Color(0xFF3F65B0),
                    labelStyle: TextStyle(
                      color: _nearbyOnly ? Colors.white : const Color(0xFF3F65B0),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF3F65B0).withOpacity(0.08),
                    side: BorderSide(color: const Color(0xFF3F65B0).withOpacity(0.4)),
                  ),
                ),
                ..._categories.map((cat) {
                  final isSelected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      selectedColor: Colors.black,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontSize: 12,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (!_loadingLocation && _currentPosition == null)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Location permission not granted — distance info unavailable.',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _loadingLocation
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _loadLocation,
              child: StreamBuilder<QuerySnapshot>(


                //availabale items shown
                stream: FirebaseFirestore.instance
                    .collection('items')
                    .where('status', isEqualTo: 'available')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Text('Error: ${snapshot.error}'),
                          ),
                        ),
                      ],
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                //search part
                  var items = snapshot.data!.docs
                      .map((doc) => Item.fromFirestore(doc))
                      .toList();

                  if (_selectedCategory != 'All') {
                    items = items
                        .where((i) => i.category == _selectedCategory)
                        .toList();
                  }

                  if (_searchQuery.isNotEmpty) {
                    items = items
                        .where((i) =>
                    i.title.toLowerCase().contains(_searchQuery) ||
                        i.description.toLowerCase().contains(_searchQuery))
                        .toList();
                  }


                //nearby items
                  List<MapEntry<Item, double>> itemsWithDistance = [];
                  if (_currentPosition != null) {
                    itemsWithDistance = items.map((item) {
                      final dist = LocationService.distanceInMiles(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                        item.latitude,
                        item.longitude,
                      );
                      return MapEntry(item, dist);
                    }).toList();

                    if (_nearbyOnly) {
                      itemsWithDistance = itemsWithDistance
                          .where((entry) => entry.value <= _maxDistanceMiles)
                          .toList();
                      itemsWithDistance.sort((a, b) => a.value.compareTo(b.value));
                    }
                  } else {
                    itemsWithDistance =
                        items.map((item) => MapEntry(item, -1.0)).toList();
                  }

                  if (itemsWithDistance.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inventory_2_outlined,
                                      size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    _nearbyOnly
                                        ? 'No items found nearby'
                                        : 'No items listed yet',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _nearbyOnly
                                        ? 'Try turning off "Nearby" to see all listings.'
                                        : 'Be the first to list something!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: itemsWithDistance.length,
                    itemBuilder: (context, index) {
                      final item = itemsWithDistance[index].key;
                      final distance = itemsWithDistance[index].value;
                      return _ItemCard(item: item, distanceMiles: distance);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddItemScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Item item;
  final double distanceMiles;

  const _ItemCard({required this.item, required this.distanceMiles});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: item.imageUrl != null
                    ? CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey, size: 28),
                    ),
                  ),
                )
                    : Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.image, color: Colors.grey, size: 32),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    distanceMiles >= 0
                        ? '${distanceMiles.toStringAsFixed(1)} mi away'
                        : 'Distance unavailable',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}