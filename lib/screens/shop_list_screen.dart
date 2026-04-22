import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import 'shop_menu_screen.dart';

class ShopListScreen extends StatelessWidget {
  const ShopListScreen({super.key, required this.customer});

  final AppUser customer;

  void _openShopMenu(BuildContext context, AppUser shop) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopMenuScreen(
          customer: customer,
          shop: shop,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: UserRole.hotel.value)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('View Shop Menus')),
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
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hotel/shop accounts found yet.\n\nCreate a hotel account first to test ordering and chat.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final shops = docs
              .map((doc) => AppUser.fromMap({...doc.data(), 'uid': doc.id}))
              .toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shops.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final shop = shops[index];
              final shopName = shop.businessName ?? shop.name;
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openShopMenu(context, shop),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Address: ${shop.address ?? '-'}'),
                        Text('Contact: ${shop.phone}'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _openShopMenu(context, shop),
                                child: const Text('View Menu'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _openShopMenu(context, shop),
                                child: const Text('Order Now'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
