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
        builder: (_) => ShopMenuScreen(customer: customer, shop: shop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream =
        FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: UserRole.hotel.value)
            .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Shops, Hotels & Businesses')),
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
                  'No business accounts found yet.\n\nCreate a hotel, shop, or service business account first to show it here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final shops =
              docs
                  .map((doc) => AppUser.fromMap({...doc.data(), 'uid': doc.id}))
                  .toList()
                ..sort((a, b) {
                  final aName = (a.businessName ?? a.name).toLowerCase();
                  final bName = (b.businessName ?? b.name).toLowerCase();
                  return aName.compareTo(bName);
                });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shops.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final shop = shops[index];
              final shopName = shop.businessName ?? shop.name;
              final category = (shop.businessCategory ?? 'Business').trim();
              final description = (shop.serviceDescription ?? '').trim();
              final hasBanner = (shop.bannerImageUrl ?? '').trim().isNotEmpty;
              final hasGallery = shop.galleryImageUrls.isNotEmpty;
              final isServiceBusiness =
                  !category.toLowerCase().contains('hotel') &&
                  !category.toLowerCase().contains('shop') &&
                  !category.toLowerCase().contains('restaurant');
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openShopMenu(context, shop),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasBanner) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 16 / 7,
                              child: Image.network(
                                shop.bannerImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, _, _) => Container(
                                      color: const Color(0xFFF0F4E8),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.storefront_outlined,
                                        size: 34,
                                        color: Color(0xFF557A1F),
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          shopName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _BusinessChip(label: category),
                            if (hasGallery)
                              _BusinessChip(
                                label: '${shop.galleryImageUrls.length} photos',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Address: ${shop.address ?? '-'}'),
                        Text('Contact: ${shop.phone}'),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _openShopMenu(context, shop),
                                child: Text(
                                  isServiceBusiness
                                      ? 'View Business'
                                      : 'View Menu',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _openShopMenu(context, shop),
                                child: Text(
                                  isServiceBusiness
                                      ? 'Contact Now'
                                      : 'Order Now',
                                ),
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

class _BusinessChip extends StatelessWidget {
  const _BusinessChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF3D5E16),
        ),
      ),
    );
  }
}
