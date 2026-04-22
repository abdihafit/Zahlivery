import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/notification_badge.dart';
import '../widgets/support_contact_card.dart';
import 'customer_chat_screen.dart';
import 'notification_inbox_screen.dart';
import 'rider_chats_screen.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  final _notificationService = NotificationService();

  AppUser _currentRider(String uid) {
    if (uid == widget.user.uid) return widget.user;
    return AppUser(
      uid: uid,
      role: UserRole.rider,
      name: widget.user.name,
      email: widget.user.email,
      phone: widget.user.phone,
      address: widget.user.address,
      vehicleType: widget.user.vehicleType,
      plateNumber: widget.user.plateNumber,
    );
  }

  AppUser _customerFromOrder(Map<String, dynamic> data) {
    return AppUser(
      uid: data['customerId'] as String? ?? '',
      role: UserRole.customer,
      name: data['customerName'] as String? ?? 'Customer',
      email: '',
      phone: data['customerPhone'] as String? ?? '',
      address: data['customerAddress'] as String?,
    );
  }

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
      _notificationService.markAllRead(uid, types: const {'delivery'});
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Home'),
        actions: [
          StreamBuilder<int>(
            stream: _notificationService.unreadCountStream(signedInUid),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NotificationInboxScreen(
                        userId: signedInUid,
                        title: 'Notifications',
                      ),
                    ),
                  );
                },
                icon: NotificationBadge(count: count),
                tooltip: 'Notifications',
              );
            },
          ),
          IconButton(
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text(widget.user.name),
              subtitle: Text('Phone: ${widget.user.phone}'),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(signedInUid)
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final available = (data?['available'] as bool?) ?? false;
              return Card(
                child: SwitchListTile(
                  title: const Text('Available for delivery'),
                  subtitle: Text(
                    available
                        ? 'You will receive new delivery assignments.'
                        : 'You will be hidden from new assignments.',
                  ),
                  value: available,
                  onChanged: (value) async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(signedInUid)
                        .set({'available': value}, SetOptions(merge: true));
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<Map<String, int>>(
            stream: _notificationService.unreadBreakdownStream(signedInUid),
            builder: (context, snapshot) {
              final counts = snapshot.data ?? const {};
              final chatCount = counts['chat'] ?? 0;
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.chat_bubble_outline),
                  ),
                  title: const Text('Chats'),
                  subtitle: const Text(
                    'Talk to customers who contact you for errands or deliveries.',
                  ),
                  trailing: chatCount > 0
                      ? NotificationBadge(
                          count: chatCount,
                          child: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        )
                      : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RiderChatsScreen(
                          rider: _currentRider(signedInUid),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Assigned Orders',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('riderId', isEqualTo: signedInUid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Card(
                  child: ListTile(
                    title: Text('No deliveries yet.'),
                    subtitle:
                        Text('When a hotel assigns you, the order appears here.'),
                  ),
                );
              }
              docs.sort((a, b) {
                final aTs = a.data()['createdAt'] as Timestamp?;
                final bTs = b.data()['createdAt'] as Timestamp?;
                final aMs = aTs?.millisecondsSinceEpoch ?? 0;
                final bMs = bTs?.millisecondsSinceEpoch ?? 0;
                return bMs.compareTo(aMs);
              });
              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final status = data['status'] as String? ?? 'pending';
                  final customerName =
                      data['customerName'] as String? ?? 'Customer';
                  final customerId = data['customerId'] as String? ?? '';
                  final customerPhone =
                      data['customerPhone'] as String? ?? '-';
                  final customerAddress =
                      data['customerAddress'] as String? ?? '-';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text('Phone: $customerPhone'),
                          Text('Address: $customerAddress'),
                          Text('Status: $status'),
                          Text('Order ID: ${doc.id}'),
                          const SizedBox(height: 8),
                          if (customerPhone.trim().isNotEmpty &&
                              customerPhone.trim() != '-')
                            OutlinedButton.icon(
                              onPressed: () => _callPhone(customerPhone),
                              icon: const Icon(Icons.call_outlined),
                              label: const Text('Call Customer'),
                            ),
                          if (customerId.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CustomerChatScreen(
                                      currentUser: _currentRider(signedInUid),
                                      peerUser: _customerFromOrder(data),
                                      chatTitle: customerName,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Chat Customer'),
                            ),
                          ],
                          const SizedBox(height: 6),
                          if (status == 'sent_to_rider')
                            FilledButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('orders')
                                    .doc(doc.id)
                                    .update({
                                  'status': 'delivered',
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                              },
                              child: const Text('Mark Delivered'),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          const SupportContactCard(),
        ],
      ),
    );
  }
}
