import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import 'customer_chat_screen.dart';

class RiderListScreen extends StatelessWidget {
  const RiderListScreen({super.key, required this.customer});

  final AppUser customer;

  @override
  Widget build(BuildContext context) {
    final ridersStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: UserRole.rider.value)
        .where('available', isEqualTo: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Available Riders')),
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
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final rider = AppUser(
                uid: docs[index].id,
                role: UserRole.rider,
                name: data['name'] as String? ?? 'Rider',
                email: data['email'] as String? ?? '',
                phone: data['phone'] as String? ?? '',
                vehicleType: data['vehicleType'] as String?,
                plateNumber: data['plateNumber'] as String?,
              );

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rider.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Phone: ${rider.phone.isEmpty ? '-' : rider.phone}'),
                      if ((rider.vehicleType ?? '').trim().isNotEmpty)
                        Text('Vehicle: ${rider.vehicleType}'),
                      if ((rider.plateNumber ?? '').trim().isNotEmpty)
                        Text('Plate: ${rider.plateNumber}'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CustomerChatScreen(
                                      currentUser: customer,
                                      peerUser: rider,
                                      chatTitle: rider.name,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Chat Rider'),
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
