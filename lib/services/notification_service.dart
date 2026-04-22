import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _notificationsRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications');
  }

  Stream<int> unreadCountStream(String userId) {
    return _notificationsRef(userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<Map<String, int>> unreadBreakdownStream(String userId) {
    return _notificationsRef(userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      var chats = 0;
      var orders = 0;
      var deliveries = 0;

      for (final doc in snapshot.docs) {
        final type = doc.data()['type'] as String? ?? '';
        switch (type) {
          case 'chat':
            chats++;
            break;
          case 'delivery':
            deliveries++;
            break;
          default:
            orders++;
            break;
        }
      }

      return {
        'all': snapshot.docs.length,
        'chat': chats,
        'order': orders,
        'delivery': deliveries,
      };
    });
  }

  Future<void> createNotification({
    required String recipientId,
    required String senderId,
    required String type,
    required String title,
    required String body,
    String? chatId,
    String? orderId,
  }) async {
    if (recipientId.trim().isEmpty || recipientId == senderId) {
      return;
    }

    await _notificationsRef(recipientId).add({
      'recipientId': recipientId,
      'senderId': senderId,
      'type': type,
      'title': title,
      'body': body,
      'chatId': chatId,
      'orderId': orderId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> notifyChatMessage({
    required String recipientId,
    required String senderId,
    required String senderName,
    required String chatId,
    String? orderId,
    required String text,
  }) async {
    final preview = text.trim().replaceAll('\n', ' ');
    await createNotification(
      recipientId: recipientId,
      senderId: senderId,
      type: 'chat',
      title: 'New chat message',
      body: '$senderName: ${_limit(preview, 80)}',
      chatId: chatId,
      orderId: orderId,
    );
  }

  Future<void> notifyOrderCreated({
    required String hotelId,
    required String customerId,
    required String customerName,
    required String hotelName,
    required String orderId,
  }) async {
    await createNotification(
      recipientId: hotelId,
      senderId: customerId,
      type: 'order',
      title: 'New order received',
      body: '$customerName placed a new order for $hotelName.',
      orderId: orderId,
    );
  }

  Future<void> notifyOrderStatusChanged({
    required String recipientId,
    required String senderId,
    required String orderId,
    required String title,
    required String body,
    bool delivery = false,
  }) async {
    await createNotification(
      recipientId: recipientId,
      senderId: senderId,
      type: delivery ? 'delivery' : 'order',
      title: title,
      body: body,
      orderId: orderId,
    );
  }

  Future<void> markAllRead(
    String userId, {
    Set<String>? types,
    String? chatId,
    String? orderId,
  }) async {
    final unread = await _notificationsRef(userId)
        .where('isRead', isEqualTo: false)
        .get();

    if (unread.docs.isEmpty) return;

    final batch = _firestore.batch();
    var hasChanges = false;

    for (final doc in unread.docs) {
      final data = doc.data();
      final type = data['type'] as String? ?? '';
      final docChatId = data['chatId'] as String? ?? '';
      final docOrderId = data['orderId'] as String? ?? '';

      final matchesType = types == null || types.contains(type);
      final matchesChat = chatId == null || docChatId == chatId;
      final matchesOrder = orderId == null || docOrderId == orderId;

      if (matchesType && matchesChat && matchesOrder) {
        hasChanges = true;
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
    }

    if (hasChanges) {
      await batch.commit();
    }
  }

  String _limit(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 1)}...';
  }
}
