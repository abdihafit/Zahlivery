import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/chat_message.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static String chatIdForUsers(String firstUserId, String secondUserId) {
    return firstUserId.compareTo(secondUserId) < 0
        ? '${firstUserId}_$secondUserId'
        : '${secondUserId}_$firstUserId';
  }

  Future<void> ensureDirectChat({
    required String chatId,
    required AppUser firstUser,
    required AppUser secondUser,
    Map<String, dynamic>? extraData,
  }) async {
    await _firestore.collection('chats').doc(chatId).set({
      ..._chatMetadata(firstUser: firstUser, secondUser: secondUser),
      ...?extraData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendDirectMessage({
    required String chatId,
    required AppUser sender,
    required AppUser receiver,
    required String text,
    String? orderId,
    Map<String, dynamic>? extraChatData,
  }) async {
    await sendMessage(
      chatId: chatId,
      sender: sender,
      receiver: receiver,
      messageType: ChatMessageType.text,
      text: text,
      orderId: orderId,
      extraChatData: extraChatData,
    );
  }

  Future<void> sendMessage({
    required String chatId,
    required AppUser sender,
    required AppUser receiver,
    required ChatMessageType messageType,
    String text = '',
    String? orderId,
    num? amount,
    String? tillNumber,
    String? phoneNumber,
    ChatPaymentStatus? paymentStatus,
    Map<String, dynamic>? extraMessageData,
    Map<String, dynamic>? extraChatData,
  }) async {
    await ensureDirectChat(
      chatId: chatId,
      firstUser: sender,
      secondUser: receiver,
      extraData: extraChatData,
    );

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(
          _messageData(
            sender: sender,
            receiver: receiver,
            messageType: messageType,
            text: text,
            orderId: orderId,
            amount: amount,
            tillNumber: tillNumber,
            phoneNumber: phoneNumber,
            paymentStatus: paymentStatus,
            extraMessageData: extraMessageData,
          ),
        );

    await _firestore.collection('chats').doc(chatId).set({
      ..._chatMetadata(firstUser: sender, secondUser: receiver),
      ...?extraChatData,
      'lastMessageText': text,
      'lastMessageType': messageType.value,
      'lastSenderId': sender.uid,
      if (orderId != null && orderId.trim().isNotEmpty) 'lastOrderId': orderId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Map<String, dynamic> _messageData({
    required AppUser sender,
    required AppUser receiver,
    required ChatMessageType messageType,
    required String text,
    String? orderId,
    num? amount,
    String? tillNumber,
    String? phoneNumber,
    ChatPaymentStatus? paymentStatus,
    Map<String, dynamic>? extraMessageData,
  }) {
    final trimmedText = text.trim();
    final trimmedTillNumber = tillNumber?.trim() ?? '';
    final trimmedPhoneNumber = phoneNumber?.trim() ?? '';

    return {
      'senderId': sender.uid,
      'receiverId': receiver.uid,
      'senderName': _displayName(sender),
      'senderRole': sender.role.value,
      'receiverRole': receiver.role.value,
      'messageType': messageType.value,
      'text': trimmedText,
      'messageText': trimmedText,
      if (orderId != null && orderId.trim().isNotEmpty) 'orderId': orderId,
      if (amount != null) 'amount': amount,
      if (trimmedTillNumber.isNotEmpty) 'tillNumber': trimmedTillNumber,
      if (trimmedPhoneNumber.isNotEmpty) 'phoneNumber': trimmedPhoneNumber,
      if (paymentStatus != null) 'paymentStatus': paymentStatus.value,
      ...?extraMessageData,
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _chatMetadata({
    required AppUser firstUser,
    required AppUser secondUser,
  }) {
    final orderedParticipants = [firstUser, secondUser]
      ..sort((a, b) => a.uid.compareTo(b.uid));

    return {
      'participants': orderedParticipants.map((user) => user.uid).toList(),
      'roles': orderedParticipants.map((user) => user.role.value).toList(),
      '${firstUser.role.value}Id': firstUser.uid,
      '${firstUser.role.value}Name': _displayName(firstUser),
      '${secondUser.role.value}Id': secondUser.uid,
      '${secondUser.role.value}Name': _displayName(secondUser),
    };
  }

  static String displayNameForUser(AppUser user) => _displayName(user);

  static String _displayName(AppUser user) {
    if (user.role == UserRole.hotel) {
      final hotelName = (user.businessName ?? user.name).trim();
      return hotelName.isEmpty ? user.role.label : hotelName;
    }

    final name = user.name.trim();
    return name.isEmpty ? user.role.label : name;
  }
}
