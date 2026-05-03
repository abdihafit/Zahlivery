import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/notification_badge.dart';
import '../widgets/support_contact_card.dart';
import 'my_orders_screen.dart';
import 'notification_inbox_screen.dart';
import 'rider_list_screen.dart';
import 'shop_list_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key, required this.user});

  final AppUser user;
  static final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    final signedInUid = FirebaseAuth.instance.currentUser?.uid ?? user.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Home'),
        actions: [
          StreamBuilder<Map<String, int>>(
            stream: _notificationService.unreadBreakdownStream(signedInUid),
            builder: (context, snapshot) {
              final counts = snapshot.data ?? const {};
              final all = counts['all'] ?? 0;
              return IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => NotificationInboxScreen(
                            userId: signedInUid,
                            title: 'Notifications',
                          ),
                    ),
                  );
                },
                icon: NotificationBadge(count: all),
                tooltip: 'Notifications',
              );
            },
          ),
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    child: Icon(Icons.person_outline),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${user.name}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text('Delivery address: ${user.address ?? '-'}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.restaurant_menu_outlined,
            title: 'View Shop Menus',
            subtitle: 'Select a hotel or shop and browse its latest menu.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShopListScreen(customer: user),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.storefront_outlined,
            title: 'Find Shops & Hotels',
            subtitle: 'Explore available stores and restaurants in the app.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShopListScreen(customer: user),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.local_taxi_outlined,
            title: 'Book a Ride',
            subtitle:
                'See available drivers, review their details, and contact one for your trip.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => RiderListScreen(
                        customer: user,
                        screenTitle: 'Book a Ride',
                        introTitle: 'Choose your driver',
                        introSubtitle:
                            'Browse available drivers, check vehicle details, and contact a rider for pickup.',
                        primaryActionLabel: 'Book This Ride',
                      ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          StreamBuilder<Map<String, int>>(
            stream: _notificationService.unreadBreakdownStream(signedInUid),
            builder: (context, snapshot) {
              final counts = snapshot.data ?? const {};
              return _ActionTile(
                icon: Icons.two_wheeler_outlined,
                title: 'Find Riders',
                subtitle:
                    'Chat with an available rider for errands like market or supermarket shopping.',
                notificationCount: counts['chat'] ?? 0,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RiderListScreen(customer: user),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),
          StreamBuilder<Map<String, int>>(
            stream: _notificationService.unreadBreakdownStream(signedInUid),
            builder: (context, snapshot) {
              final counts = snapshot.data ?? const {};
              final orderCount =
                  (counts['order'] ?? 0) + (counts['delivery'] ?? 0);
              return _ActionTile(
                icon: Icons.receipt_long_outlined,
                title: 'My Orders',
                subtitle: 'View active and past order updates.',
                notificationCount: orderCount,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MyOrdersScreen(customer: user),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),
          StreamBuilder<Map<String, int>>(
            stream: _notificationService.unreadBreakdownStream(signedInUid),
            builder: (context, snapshot) {
              final counts = snapshot.data ?? const {};
              return _ActionTile(
                icon: Icons.notifications_active_outlined,
                title: 'Notifications',
                subtitle: 'See chat, order, and delivery updates.',
                notificationCount: counts['all'] ?? 0,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => NotificationInboxScreen(
                            userId: signedInUid,
                            title: 'Notifications',
                          ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          const SupportContactCard(),
          const SizedBox(height: 20),
          const Text(
            'Mock Data Preview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Active order'),
                  SizedBox(height: 8),
                  Text('Store: Green Mart'),
                  Text('Status: Rider assigned'),
                  Text('ETA: 18 mins'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.notificationCount = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0x1A6DBE00),
          child: Icon(icon, color: const Color(0xFF2E5E00)),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing:
            notificationCount > 0
                ? NotificationBadge(
                  count: notificationCount,
                  child: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                )
                : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}
