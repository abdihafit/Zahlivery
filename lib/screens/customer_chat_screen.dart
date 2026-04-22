import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';

class CustomerChatScreen extends StatefulWidget {
  const CustomerChatScreen({
    super.key,
    required this.currentUser,
    this.hotelUser,
    this.peerUser,
    this.chatId,
    this.chatTitle,
  }) : assert(
         hotelUser != null || peerUser != null,
         'Either hotelUser or peerUser must be provided.',
       );

  final AppUser currentUser;
  final AppUser? hotelUser;
  final AppUser? peerUser;
  final String? chatId;
  final String? chatTitle;

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final _messageController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _notificationService = NotificationService();
  final _chatService = ChatService();

  bool _sending = false;

  AppUser get _peerUser => widget.peerUser ?? widget.hotelUser!;

  String get _chatId {
    return widget.chatId ??
        ChatService.chatIdForUsers(widget.currentUser.uid, _peerUser.uid);
  }

  @override
  void initState() {
    super.initState();
    _ensureChat();
    _markChatNotificationsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _ensureChat() async {
    await _chatService.ensureDirectChat(
      chatId: _chatId,
      firstUser: widget.currentUser,
      secondUser: _peerUser,
    );
  }

  Future<void> _markChatNotificationsRead() async {
    await _notificationService.markAllRead(
      widget.currentUser.uid,
      types: const {'chat'},
      chatId: _chatId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.chatTitle ?? ChatService.displayNameForUser(_peerUser),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  _firestore
                      .collection('chats')
                      .doc(_chatId)
                      .collection('messages')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation.'),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final mine = data['senderId'] == widget.currentUser.uid;
                    final text =
                        data['text'] as String? ??
                        data['messageText'] as String? ??
                        '';
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              mine
                                  ? const Color(
                                    0xFF6DBE00,
                                  ).withValues(alpha: 0.18)
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(text),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type message...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await _chatService.sendDirectMessage(
        chatId: _chatId,
        sender: widget.currentUser,
        receiver: _peerUser,
        text: text,
      );
      _messageController.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
