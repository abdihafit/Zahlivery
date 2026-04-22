import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/notification_service.dart';

class HotelOrdersScreen extends StatefulWidget {
  const HotelOrdersScreen({super.key, required this.hotel});

  final AppUser hotel;

  @override
  State<HotelOrdersScreen> createState() => _HotelOrdersScreenState();
}

class _HotelOrdersScreenState extends State<HotelOrdersScreen> {
  final _notificationService = NotificationService();

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
        .where('hotelId', isEqualTo: signedInUid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Order Inbox')),
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
              child: Text('No orders yet. Orders from customers will appear here.'),
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
              final doc = docs[index];
              final data = doc.data();
              final status = data['status'] as String? ?? 'pending';
              final customerName = data['customerName'] as String? ?? 'Customer';
              final customerAddress =
                  data['customerAddress'] as String? ?? 'No address provided';
              final riderName = data['riderName'] as String? ?? '';
              final riderPhone = data['riderPhone'] as String? ?? '';
              final items = (data['items'] as List<dynamic>? ?? [])
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
              final totalAmount = _toDouble(data['totalAmount']);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Address: $customerAddress'),
                      Text('Status: $status'),
                      Text('Order ID: ${doc.id}'),
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Items',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        ...items.map((item) {
                          final name = item['name'] as String? ?? 'Item';
                          final qty = item['qty']?.toString() ?? '1';
                          final lineTotal = _toDouble(item['lineTotal']);
                          return Text(
                            '- $name x$qty (KSH ${lineTotal.toStringAsFixed(2)})',
                          );
                        }),
                        const SizedBox(height: 4),
                        Text(
                          'Total: KSH ${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                      if (riderName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Rider: $riderName',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (riderPhone.isNotEmpty) Text('Rider Phone: $riderPhone'),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (status == 'pending')
                            FilledButton(
                              onPressed: () => _updateStatus(
                                context: context,
                                orderId: doc.id,
                                orderData: data,
                                newStatus: 'accepted',
                              ),
                              child: const Text('Accept'),
                            ),
                          if (status == 'accepted')
                            FilledButton(
                              onPressed: () => _updateStatus(
                                context: context,
                                orderId: doc.id,
                                orderData: data,
                                newStatus: 'payment_verified',
                              ),
                              child: const Text('Verify Payment'),
                            ),
                          if (status == 'payment_verified' &&
                              riderName.isNotEmpty)
                            FilledButton(
                              onPressed: () => _updateStatus(
                                context: context,
                                orderId: doc.id,
                                orderData: data,
                                newStatus: 'sent_to_rider',
                              ),
                              child: const Text('Send To Rider'),
                            ),
                          if (status == 'sent_to_rider')
                            FilledButton(
                              onPressed: () => _updateStatus(
                                context: context,
                                orderId: doc.id,
                                orderData: data,
                                newStatus: 'delivered',
                              ),
                              child: const Text('Mark Delivered'),
                            ),
                          if (riderName.isEmpty &&
                              (status == 'accepted' ||
                                  status == 'payment_verified'))
                            OutlinedButton(
                              onPressed: () => _assignRider(
                                context: context,
                                orderId: doc.id,
                                orderData: data,
                              ),
                              child: const Text('Assign Rider'),
                            ),
                          if (status != 'cancelled' && status != 'delivered')
                            OutlinedButton(
                              onPressed: () => _updateStatus(
                                context: context,
                                orderId: doc.id,
                                orderData: data,
                                newStatus: 'cancelled',
                              ),
                              child: const Text('Cancel'),
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

  Future<void> _updateStatus({
    required BuildContext context,
    required String orderId,
    required Map<String, dynamic> orderData,
    required String newStatus,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order updated: $newStatus')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order: $error')),
        );
      }
    }
  }

  Future<void> _assignRider({
    required BuildContext context,
    required String orderId,
    required Map<String, dynamic> orderData,
  }) async {
    final signedInUser = FirebaseAuth.instance.currentUser;
    if (signedInUser == null) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'rider')
                .where('available', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: ${snapshot.error}'),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No available riders right now.'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final riderName = data['name'] as String? ?? 'Rider';
                  final riderPhone = data['phone'] as String? ?? '-';
                  return Card(
                    child: ListTile(
                      title: Text(riderName),
                      subtitle: Text('Phone: $riderPhone'),
                      trailing: const Icon(Icons.check_circle_outline),
                      onTap: () async {
                        await FirebaseFirestore.instance
                            .collection('orders')
                            .doc(orderId)
                            .update({
                          'riderId': doc.id,
                          'riderName': riderName,
                          'riderPhone': riderPhone,
                          'status': 'sent_to_rider',
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(doc.id)
                            .set({'available': false}, SetOptions(merge: true));
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
