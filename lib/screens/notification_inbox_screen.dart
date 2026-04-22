import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';

class NotificationInboxScreen extends StatelessWidget {
  NotificationInboxScreen({
    super.key,
    required this.userId,
    required this.title,
  }) : _notificationService = NotificationService();

  final String userId;
  final String title;
  final NotificationService _notificationService;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => _notificationService.markAllRead(userId),
            child: const Text('Mark all read'),
          ),
        ],
      ),
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
              child: Text('No notifications yet. New activity will appear here.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final title = data['title'] as String? ?? 'Notification';
              final body = data['body'] as String? ?? '';
              final type = data['type'] as String? ?? 'order';
              final isRead = data['isRead'] as bool? ?? false;
              final createdAt = data['createdAt'] as Timestamp?;

              return Card(
                color: isRead ? Colors.white : const Color(0xFFF2F9E8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _iconBackground(type),
                    child: Icon(_iconForType(type), color: _iconColor(type)),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(body),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _formatTimestamp(createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  onTap: isRead
                      ? null
                      : () => _notificationService.markAllRead(
                            userId,
                            chatId: data['chatId'] as String?,
                            orderId: data['orderId'] as String?,
                            types: {type},
                          ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'delivery':
        return Icons.delivery_dining_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Color _iconBackground(String type) {
    switch (type) {
      case 'chat':
        return const Color(0x1A1976D2);
      case 'delivery':
        return const Color(0x1AD97706);
      default:
        return const Color(0x1A6DBE00);
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'chat':
        return const Color(0xFF1976D2);
      case 'delivery':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF2E5E00);
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final date = timestamp.toDate();
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day}/${date.month}/${date.year} $hour:$minute $period';
  }
}
