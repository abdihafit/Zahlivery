import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/notification_service.dart';
import 'hotel_thread_screen.dart';

class HotelChatsScreen extends StatefulWidget {
  const HotelChatsScreen({super.key, required this.hotel});

  final AppUser hotel;

  @override
  State<HotelChatsScreen> createState() => _HotelChatsScreenState();
}

class _HotelChatsScreenState extends State<HotelChatsScreen> {
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _notificationService.markAllRead(uid, types: const {'chat'});
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedInUser = FirebaseAuth.instance.currentUser;
    if (signedInUser == null) {
      return const Scaffold(
        body: Center(child: Text('Session expired. Please sign in again.')),
      );
    }
    final signedInUid = signedInUser.uid;
    final stream =
        FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: signedInUid)
            .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
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
              child: Text(
                'No chats yet. Customer and rider chats will appear here.',
              ),
            );
          }

          docs.sort((a, b) {
            final aTs = a.data()['updatedAt'] as Timestamp?;
            final bTs = b.data()['updatedAt'] as Timestamp?;
            final aMs = aTs?.millisecondsSinceEpoch ?? 0;
            final bMs = bTs?.millisecondsSinceEpoch ?? 0;
            return bMs.compareTo(aMs);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final participants =
                  (data['participants'] as List<dynamic>? ?? []).cast<String>();
              final peerId = participants.firstWhere(
                (id) => id != signedInUid,
                orElse: () => '',
              );
              final peerRole = _peerRoleForChat(data: data, peerId: peerId);
              final peerName = _peerNameForChat(data: data, peerRole: peerRole);

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(peerName),
                  subtitle: Text(peerRole.label),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap:
                      peerId.isEmpty
                          ? null
                          : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => HotelThreadScreen(
                                      hotel: widget.hotel,
                                      chatId: doc.id,
                                      peerId: peerId,
                                      peerName: peerName,
                                      peerRole: peerRole,
                                    ),
                              ),
                            );
                          },
                ),
              );
            },
          );
        },
      ),
    );
  }

  UserRole _peerRoleForChat({
    required Map<String, dynamic> data,
    required String peerId,
  }) {
    if (peerId.isEmpty) return UserRole.customer;
    if ((data['riderId'] as String? ?? '') == peerId) {
      return UserRole.rider;
    }
    if ((data['hotelId'] as String? ?? '') == peerId) {
      return UserRole.hotel;
    }
    if ((data['customerId'] as String? ?? '') == peerId) {
      return UserRole.customer;
    }

    final participants =
        (data['participants'] as List<dynamic>? ?? []).cast<String>();
    final roles = (data['roles'] as List<dynamic>? ?? []).cast<String>();
    final peerIndex = participants.indexOf(peerId);
    if (peerIndex >= 0 && peerIndex < roles.length) {
      return userRoleFromString(roles[peerIndex]);
    }

    return UserRole.customer;
  }

  String _peerNameForChat({
    required Map<String, dynamic> data,
    required UserRole peerRole,
  }) {
    switch (peerRole) {
      case UserRole.customer:
        return (data['customerName'] as String? ?? '').trim().isNotEmpty
            ? data['customerName'] as String
            : 'Customer';
      case UserRole.rider:
        return (data['riderName'] as String? ?? '').trim().isNotEmpty
            ? data['riderName'] as String
            : 'Rider';
      case UserRole.hotel:
        return (data['hotelName'] as String? ?? '').trim().isNotEmpty
            ? data['hotelName'] as String
            : 'Hotel';
      case UserRole.admin:
        return (data['adminName'] as String? ?? '').trim().isNotEmpty
            ? data['adminName'] as String
            : 'Admin';
    }
  }
}
