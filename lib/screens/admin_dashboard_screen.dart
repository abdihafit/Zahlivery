import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../widgets/support_contact_card.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final usersStream =
        FirebaseFirestore.instance.collection('users').snapshots();
    final ordersStream =
        FirebaseFirestore.instance.collection('orders').snapshots();
    final chatsStream =
        FirebaseFirestore.instance.collection('chats').snapshots();
    final latestUsersStream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(6)
        .snapshots();
    final latestOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(8)
        .snapshots();
    final latestChatsStream = FirebaseFirestore.instance
        .collection('chats')
        .orderBy('updatedAt', descending: true)
        .limit(8)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.admin_panel_settings)),
              title: Text(user.name.isEmpty ? 'Admin' : user.name),
              subtitle: Text(
                user.email.isEmpty
                    ? 'Live system overview for Zahlivery'
                    : user.email,
              ),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: usersStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              var customers = 0;
              var hotels = 0;
              var riders = 0;
              var admins = 0;
              var availableRiders = 0;

              for (final doc in docs) {
                final data = doc.data();
                switch (data['role'] as String? ?? '') {
                  case 'hotel':
                    hotels++;
                    break;
                  case 'rider':
                    riders++;
                    if ((data['available'] as bool?) ?? false) {
                      availableRiders++;
                    }
                    break;
                  case 'admin':
                    admins++;
                    break;
                  case 'customer':
                  default:
                    customers++;
                    break;
                }
              }

              return _SectionCard(
                title: 'User Overview',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(label: 'Customers', value: '$customers'),
                    _MetricCard(label: 'Hotels', value: '$hotels'),
                    _MetricCard(label: 'Riders', value: '$riders'),
                    _MetricCard(label: 'Available Riders', value: '$availableRiders'),
                    _MetricCard(label: 'Admins', value: '$admins'),
                    _MetricCard(label: 'Total Users', value: '${docs.length}'),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: ordersStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              var pending = 0;
              var active = 0;
              var completed = 0;
              var cancelled = 0;
              var revenue = 0.0;

              for (final doc in docs) {
                final data = doc.data();
                final status = data['status'] as String? ?? 'pending';
                revenue += _toDouble(data['totalAmount']);

                switch (status) {
                  case 'delivered':
                    completed++;
                    break;
                  case 'cancelled':
                    cancelled++;
                    break;
                  case 'pending':
                    pending++;
                    break;
                  default:
                    active++;
                    break;
                }
              }

              return _SectionCard(
                title: 'Order Overview',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(label: 'Total Orders', value: '${docs.length}'),
                    _MetricCard(label: 'Pending', value: '$pending'),
                    _MetricCard(label: 'Active', value: '$active'),
                    _MetricCard(label: 'Delivered', value: '$completed'),
                    _MetricCard(label: 'Cancelled', value: '$cancelled'),
                    _MetricCard(
                      label: 'Order Value',
                      value: 'KSH ${revenue.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: chatsStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              var customerChats = 0;
              var riderChats = 0;

              for (final doc in docs) {
                final roles = (doc.data()['roles'] as List<dynamic>? ?? const [])
                    .map((item) => item.toString())
                    .toList();
                if (roles.contains('customer')) {
                  customerChats++;
                }
                if (roles.contains('rider')) {
                  riderChats++;
                }
              }

              return _SectionCard(
                title: 'Conversation Overview',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(label: 'Total Chats', value: '${docs.length}'),
                    _MetricCard(label: 'Customer Chats', value: '$customerChats'),
                    _MetricCard(label: 'Rider Chats', value: '$riderChats'),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: latestOrdersStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              return _SectionCard(
                title: 'Latest Orders',
                child: docs.isEmpty
                    ? const Text('No orders yet.')
                    : Column(
                        children: docs.map((doc) {
                          final data = doc.data();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(data['customerName'] as String? ?? 'Customer'),
                            subtitle: Text(
                              '${data['hotelName'] as String? ?? 'Hotel'}\n'
                              'Status: ${data['status'] as String? ?? 'pending'}',
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              'KSH ${_toDouble(data['totalAmount']).toStringAsFixed(2)}',
                            ),
                          );
                        }).toList(),
                      ),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: latestChatsStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              return _SectionCard(
                title: 'Recent Chats',
                child: docs.isEmpty
                    ? const Text('No chat activity yet.')
                    : Column(
                        children: docs.map((doc) {
                          final data = doc.data();
                          final participants =
                              (data['participants'] as List<dynamic>? ?? const [])
                                  .length;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.chat_bubble_outline),
                            title: Text(
                              data['lastMessageText'] as String? ??
                                  'Conversation opened',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Participants: $participants - Last sender: ${data['lastSenderId'] as String? ?? '-'}',
                            ),
                          );
                        }).toList(),
                      ),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: latestUsersStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              return _SectionCard(
                title: 'Newest Accounts',
                child: docs.isEmpty
                    ? const Text('No users yet.')
                    : Column(
                        children: docs.map((doc) {
                          final data = doc.data();
                          final role = userRoleFromString(
                            data['role'] as String? ?? 'customer',
                          );
                          final title = role == UserRole.hotel
                              ? (data['businessName'] as String? ?? data['name'] as String? ?? 'Hotel')
                              : (data['name'] as String? ?? 'User');
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_outline),
                            title: Text(title),
                            subtitle: Text(
                              '${role.label} - ${data['phone'] as String? ?? '-'}',
                            ),
                          );
                        }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const SupportContactCard(),
        ],
      ),
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8E7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

