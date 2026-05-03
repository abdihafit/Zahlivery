import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import 'customer_chat_screen.dart';

class ShopMenuScreen extends StatefulWidget {
  const ShopMenuScreen({super.key, required this.customer, required this.shop});

  final AppUser customer;
  final AppUser shop;

  @override
  State<ShopMenuScreen> createState() => _ShopMenuScreenState();
}

class _ShopMenuScreenState extends State<ShopMenuScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _chatService = ChatService();
  final Map<String, int> _quantities = {};
  bool _placingOrder = false;

  String get _chatId {
    return ChatService.chatIdForUsers(
      _signedInUid ?? widget.customer.uid,
      widget.shop.uid,
    );
  }

  String? get _signedInUid => FirebaseAuth.instance.currentUser?.uid;

  AppUser _currentUserWithUid(String uid) {
    if (uid == widget.customer.uid) return widget.customer;
    return AppUser(
      uid: uid,
      role: widget.customer.role,
      name: widget.customer.name,
      email: widget.customer.email,
      phone: widget.customer.phone,
      address: widget.customer.address,
      businessName: widget.customer.businessName,
      vehicleType: widget.customer.vehicleType,
      plateNumber: widget.customer.plateNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuStream =
        _firestore
            .collection('users')
            .doc(widget.shop.uid)
            .collection('menuItems')
            .where('available', isEqualTo: true)
            .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text(widget.shop.businessName ?? widget.shop.name)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: menuStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          docs.sort((a, b) {
            final aName = (a.data()['name'] as String? ?? '').toLowerCase();
            final bName = (b.data()['name'] as String? ?? '').toLowerCase();
            return aName.compareTo(bName);
          });

          if (docs.isEmpty) {
            final profileImages = <String>[
              if ((widget.shop.bannerImageUrl ?? '').trim().isNotEmpty)
                widget.shop.bannerImageUrl!.trim(),
              ...widget.shop.galleryImageUrls,
            ];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (profileImages.isNotEmpty) ...[
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: profileImages.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: Image.network(
                              profileImages[index],
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, _, _) => Container(
                                    color: const Color(0xFFF1F4EC),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.storefront_outlined,
                                      size: 36,
                                      color: Color(0xFF557A1F),
                                    ),
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.shop.businessName ?? widget.shop.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Category: ${widget.shop.businessCategory ?? 'Business'}',
                        ),
                        Text('Contact: ${widget.shop.phone}'),
                        Text('Address: ${widget.shop.address ?? '-'}'),
                        if ((widget.shop.serviceDescription ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(widget.shop.serviceDescription!),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F8F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'This business has not uploaded a menu yet. You can still contact them through chat to ask about products, bookings, or services.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => CustomerChatScreen(
                                        currentUser: _currentUserWithUid(
                                          _signedInUid ?? widget.customer.uid,
                                        ),
                                        hotelUser: widget.shop,
                                        chatTitle:
                                            widget.shop.businessName ??
                                            widget.shop.name,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Chat Business'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          final selected = _selectedItems(docs);
          final selectedCount = selected.fold<int>(
            0,
            (quantityCount, item) => quantityCount + (item['qty'] as int),
          );
          final total = selected.fold<double>(
            0,
            (runningTotal, item) =>
                runningTotal + ((item['lineTotal'] as num).toDouble()),
          );

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final name = data['name'] as String? ?? 'Item';
                    final description = data['description'] as String? ?? '';
                    final imageUrls = _readImageUrls(data);
                    final imageUrl =
                        imageUrls.isNotEmpty
                            ? imageUrls.first
                            : (data['imageUrl'] as String? ?? '');
                    final price = _toDouble(data['price']);
                    final qty = _quantities[doc.id] ?? 0;

                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap:
                            () => _showMenuItemDetails(
                              itemId: doc.id,
                              name: name,
                              description: description,
                              price: price,
                              imageUrls: imageUrls,
                              fallbackImageUrl: imageUrl,
                            ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMenuImageGallery(
                                imageUrls: imageUrls,
                                fallbackImageUrl: imageUrl,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('KSH ${price.toStringAsFixed(2)}'),
                                        if (description.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        if (imageUrls.length > 1) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '${imageUrls.length} photos available',
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed:
                                        () => _showMenuItemDetails(
                                          itemId: doc.id,
                                          name: name,
                                          description: description,
                                          price: price,
                                          imageUrls: imageUrls,
                                          fallbackImageUrl: imageUrl,
                                        ),
                                    child: const Text('View'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed:
                                        qty == 0
                                            ? null
                                            : () => _changeQty(doc.id, qty - 1),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text(
                                    '$qty',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed:
                                        () => _changeQty(doc.id, qty + 1),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x22000000)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selected items: $selectedCount'),
                        Text('Total: KSH ${total.toStringAsFixed(2)}'),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                selected.isEmpty || _placingOrder
                                    ? null
                                    : () => _placeOrder(selected, total),
                            child: Text(
                              _placingOrder
                                  ? 'Placing...'
                                  : 'Proceed To Chat & Order',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _changeQty(String itemId, int nextQty) {
    setState(() {
      if (nextQty <= 0) {
        _quantities.remove(itemId);
      } else {
        _quantities[itemId] = nextQty;
      }
    });
  }

  Future<void> _showMenuItemDetails({
    required String itemId,
    required String name,
    required String description,
    required double price,
    required List<String> imageUrls,
    required String fallbackImageUrl,
  }) async {
    final galleryImages =
        imageUrls.isNotEmpty
            ? imageUrls
            : (fallbackImageUrl.isEmpty
                ? const <String>[]
                : [fallbackImageUrl]);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        var currentPage = 0;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final qty = _quantities[itemId] ?? 0;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'KSH ${price.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (galleryImages.isEmpty)
                        Container(
                          height: 220,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0x11000000),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.fastfood_outlined, size: 40),
                        )
                      else ...[
                        SizedBox(
                          height: 220,
                          child: PageView.builder(
                            itemCount: galleryImages.length,
                            onPageChanged: (index) {
                              setModalState(() => currentPage = index);
                            },
                            itemBuilder: (context, index) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  galleryImages[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder:
                                      (_, _, _) => Container(
                                        color: const Color(0x11000000),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (galleryImages.length > 1) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(galleryImages.length, (
                              index,
                            ) {
                              final selected = index == currentPage;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: selected ? 18 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color:
                                      selected
                                          ? const Color(0xFF2E5E00)
                                          : const Color(0x33000000),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              );
                            }),
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Menu details',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description.isEmpty
                            ? 'No extra description added for this item yet.'
                            : description,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                qty == 0
                                    ? null
                                    : () {
                                      _changeQty(itemId, qty - 1);
                                      setModalState(() {});
                                    },
                            icon: const Icon(Icons.remove),
                            label: const Text('Remove'),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Selected: $qty',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () {
                              _changeQty(itemId, qty + 1);
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _selectedItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final qty = _quantities[doc.id] ?? 0;
      if (qty <= 0) continue;
      final data = doc.data();
      final price = _toDouble(data['price']);
      result.add({
        'menuItemId': doc.id,
        'name': data['name'] as String? ?? 'Item',
        'price': price,
        'qty': qty,
        'lineTotal': price * qty,
        'imageUrl':
            _readImageUrls(data).isNotEmpty
                ? _readImageUrls(data).first
                : (data['imageUrl'] as String? ?? ''),
        'imageUrls': _readImageUrls(data),
      });
    }
    return result;
  }

  Future<void> _placeOrder(
    List<Map<String, dynamic>> items,
    double total,
  ) async {
    setState(() => _placingOrder = true);
    try {
      final customerUid = _signedInUid ?? widget.customer.uid;
      await _chatService.ensureDirectChat(
        chatId: _chatId,
        firstUser: _currentUserWithUid(customerUid),
        secondUser: widget.shop,
      );

      final orderRef = await _firestore.collection('orders').add({
        'customerId': customerUid,
        'customerName': widget.customer.name,
        'customerPhone': widget.customer.phone,
        'customerAddress': widget.customer.address ?? '',
        'hotelId': widget.shop.uid,
        'hotelName': widget.shop.businessName ?? widget.shop.name,
        'status': 'pending',
        'source': 'menu',
        'paymentStatus': 'awaiting_payment',
        'items': items,
        'totalAmount': total,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final lines = items
          .map(
            (item) =>
                '- ${item['name']} x${item['qty']} (KSH ${(item['lineTotal'] as num).toStringAsFixed(2)})',
          )
          .join('\n');
      final text =
          'Hello, I want to place an order.\n'
          'Order ID: ${orderRef.id}\n'
          '$lines\n'
          'Total: KSH ${total.toStringAsFixed(2)}\n'
          'Please share your payment method.';

      await _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
            'senderId': customerUid,
            'receiverId': widget.shop.uid,
            'senderName': widget.customer.name,
            'senderRole': UserRole.customer.value,
            'receiverRole': widget.shop.role.value,
            'messageType': ChatMessageType.orderSummary.value,
            'orderId': orderRef.id,
            'text': text,
            'messageText': text,
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });
      await _firestore.collection('chats').doc(_chatId).set({
        'lastMessageText': text,
        'lastMessageType': ChatMessageType.orderSummary.value,
        'lastSenderId': customerUid,
        'lastOrderId': orderRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _quantities.clear();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => CustomerChatScreen(
                currentUser: _currentUserWithUid(customerUid),
                hotelUser: widget.shop,
              ),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order created and sent to shop chat.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<String> _readImageUrls(Map<String, dynamic> data) {
    final raw = data['imageUrls'];
    if (raw is List) {
      return raw
          .map((item) => item?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final fallback = data['imageUrl'] as String? ?? '';
    return fallback.isEmpty ? const [] : [fallback];
  }

  Widget _buildMenuImageGallery({
    required List<String> imageUrls,
    required String fallbackImageUrl,
  }) {
    final galleryImages =
        imageUrls.isNotEmpty
            ? imageUrls
            : (fallbackImageUrl.isEmpty
                ? const <String>[]
                : [fallbackImageUrl]);

    if (galleryImages.isEmpty) {
      return Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0x11000000),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.fastfood_outlined, size: 32),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: galleryImages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final imageUrl = galleryImages[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 180,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, _, _) => Container(
                      color: const Color(0x11000000),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
}
