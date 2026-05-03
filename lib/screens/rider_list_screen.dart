import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import 'customer_chat_screen.dart';

class RiderListScreen extends StatelessWidget {
  const RiderListScreen({
    super.key,
    required this.customer,
    this.screenTitle = 'Available Riders',
    this.introTitle = 'Available riders',
    this.introSubtitle = 'Choose a rider to view details and start chatting.',
    this.primaryActionLabel = 'Chat Rider',
  });

  final AppUser customer;
  final String screenTitle;
  final String introTitle;
  final String introSubtitle;
  final String primaryActionLabel;

  @override
  Widget build(BuildContext context) {
    final ridersStream =
        FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: UserRole.rider.value)
            .where('available', isEqualTo: true)
            .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text(screenTitle)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ridersStream,
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No riders are available right now.\nTry again shortly.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Card(
                  color: const Color(0xFFF7FBEF),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0x1A6DBE00),
                              child: Icon(
                                Icons.local_taxi_outlined,
                                color: Color(0xFF2E5E00),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    introTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(introSubtitle),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _InfoChip(
                              icon: Icons.badge_outlined,
                              label: 'Driver name',
                            ),
                            _InfoChip(
                              icon: Icons.phone_outlined,
                              label: 'Phone number',
                            ),
                            _InfoChip(
                              icon: Icons.directions_car_outlined,
                              label: 'Vehicle details',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              final riderIndex = index - 1;
              final data = docs[riderIndex].data();
              final rider = AppUser(
                uid: docs[riderIndex].id,
                role: UserRole.rider,
                name: data['name'] as String? ?? 'Rider',
                email: data['email'] as String? ?? '',
                phone: data['phone'] as String? ?? '',
                vehicleType: data['vehicleType'] as String?,
                plateNumber: data['plateNumber'] as String?,
              );

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rider.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x1A2E7D32),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Available',
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: rider.phone.isEmpty ? '-' : rider.phone,
                      ),
                      if ((rider.vehicleType ?? '').trim().isNotEmpty)
                        _DetailRow(
                          icon: Icons.directions_car_outlined,
                          label: 'Vehicle',
                          value: rider.vehicleType!,
                        ),
                      if ((rider.plateNumber ?? '').trim().isNotEmpty)
                        _DetailRow(
                          icon: Icons.confirmation_number_outlined,
                          label: 'Plate',
                          value: rider.plateNumber!,
                        ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Driver details are pulled from the rider profile, so you can update them later from the rider section.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => CustomerChatScreen(
                                          currentUser: customer,
                                          peerUser: rider,
                                          chatTitle: rider.name,
                                        ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.local_taxi_outlined),
                              label: Text(primaryActionLabel),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => CustomerChatScreen(
                                          currentUser: customer,
                                          peerUser: rider,
                                          chatTitle: rider.name,
                                        ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Chat Driver'),
                            ),
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
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD9E5C3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2E5E00)),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
