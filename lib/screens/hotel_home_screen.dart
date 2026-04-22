import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/notification_badge.dart';
import '../widgets/support_contact_card.dart';
import 'hotel_chats_screen.dart';
import 'hotel_menu_screen.dart';
import 'hotel_orders_screen.dart';
import 'notification_inbox_screen.dart';

class HotelHomeScreen extends StatelessWidget {
  const HotelHomeScreen({super.key, required this.user});

  final AppUser user;
  static final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    final signedInUid = FirebaseAuth.instance.currentUser?.uid ?? user.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel / Shop Home'),
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
              title: Text(user.businessName ?? user.name),
              subtitle: Text('Contact: ${user.phone}'),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<Map<String, int>>(
            stream: _notificationService.unreadBreakdownStream(signedInUid),
            builder: (context, snapshot) {
              final counts = snapshot.data ?? const {};
              final count =
                  (counts['order'] ?? 0) + (counts['delivery'] ?? 0);
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.receipt_long_outlined),
                  ),
                  title: const Text('Order Inbox'),
                  subtitle: const Text('View and update orders from customers.'),
                  trailing: count > 0
                      ? NotificationBadge(
                          count: count,
                          child: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        )
                      : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HotelOrdersScreen(hotel: user),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.restaurant_menu)),
              title: const Text('Manage Menu'),
              subtitle: const Text('Add menu items, prices, and food photos.'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HotelMenuScreen(hotel: user),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<Map<String, int>>(
            stream: _notificationService.unreadBreakdownStream(signedInUid),
            builder: (context, snapshot) {
              final counts = snapshot.data ?? const {};
              final count = counts['chat'] ?? 0;
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.chat_bubble_outline),
                  ),
                  title: const Text('Chats'),
                  subtitle: const Text('Chat with customers who contacted your shop.'),
                  trailing: count > 0
                      ? NotificationBadge(
                          count: count,
                          child: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        )
                      : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HotelChatsScreen(hotel: user),
                      ),
                    );
                  },
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
}
