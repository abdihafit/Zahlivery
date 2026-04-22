import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user.dart';
import '../services/notification_service.dart';
import 'customer_chat_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key, required this.customer});

  final AppUser customer;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final _notificationService = NotificationService();

  Future<void> _callPhone(String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: trimmed);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _notificationService.markAllRead(
        uid,
        types: const {'order', 'delivery'},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedInUser = FirebaseAuth.instance.currentUser;
    if (signedInUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Session expired. Please sign in again.'),
        ),
      );
    }
    final signedInUid = signedInUser.uid;

    final stream = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: signedInUid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No orders yet. Create one from Find Shops.'),
            );
          }

          docs.sort((a, b) {
            final aTs = a.data()['createdAt'] as Timestamp?;
            final bTs = b.data()['createdAt'] as Timestamp?;
            final aMs = aTs?.millisecondsSinceEpoch ?? 0;
            final bMs = bTs?.millisecondsSinceEpoch ?? 0;
            return bMs.compareTo(aMs);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final hotelId = data['hotelId'] as String? ?? '';
              final hotelName = data['hotelName'] as String? ?? 'Hotel';
              final status = data['status'] as String? ?? '-';
              final riderId = data['riderId'] as String? ?? '';
              final riderName = data['riderName'] as String? ?? '';
              final riderPhone = data['riderPhone'] as String? ?? '';
              final items = (data['items'] as List<dynamic>? ?? []).length;
              final total = _toDouble(data['totalAmount']);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hotelName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Status: $status'),
                      if (items > 0) Text('Items: $items'),
                      if (total > 0)
                        Text('Total: KSH ${total.toStringAsFixed(2)}'),
                      if (riderName.isNotEmpty) Text('Rider: $riderName'),
                      if (riderPhone.isNotEmpty) ...[
                        Text('Rider Phone: $riderPhone'),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => _callPhone(riderPhone),
                            icon: const Icon(Icons.call_outlined),
                            label: const Text('Call Rider'),
                          ),
                        ),
                      ],
                      Text('Order ID: ${docs[index].id}'),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: hotelId.isEmpty
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CustomerChatScreen(
                                          currentUser: widget.customer,
                                          hotelUser: AppUser(
                                            uid: hotelId,
                                            role: UserRole.hotel,
                                            name: hotelName,
                                            email: '',
                                            phone: '',
                                            businessName: hotelName,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            child: const Text('Chat with Shop'),
                          ),
                          if (riderId.isNotEmpty)
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CustomerChatScreen(
                                      currentUser: widget.customer,
                                      peerUser: AppUser(
                                        uid: riderId,
                                        role: UserRole.rider,
                                        name: riderName.isEmpty
                                            ? 'Rider'
                                            : riderName,
                                        email: '',
                                        phone: riderPhone,
                                      ),
                                      chatTitle: riderName.isEmpty
                                          ? 'Rider'
                                          : riderName,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Chat with Rider'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
