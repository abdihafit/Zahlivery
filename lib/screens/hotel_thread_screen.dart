import 'package:flutter/material.dart';

import '../models/app_user.dart';
import 'customer_chat_screen.dart';

class HotelThreadScreen extends StatelessWidget {
  const HotelThreadScreen({
    super.key,
    required this.hotel,
    required this.chatId,
    required this.peerId,
    required this.peerName,
    required this.peerRole,
  });

  final AppUser hotel;
  final String chatId;
  final String peerId;
  final String peerName;
  final UserRole peerRole;

  @override
  Widget build(BuildContext context) {
    return CustomerChatScreen(
      currentUser: hotel,
      peerUser: AppUser(
        uid: peerId,
        role: peerRole,
        name: peerRole == UserRole.hotel ? '' : peerName,
        email: '',
        phone: '',
        businessName: peerRole == UserRole.hotel ? peerName : null,
      ),
      chatId: chatId,
      chatTitle: peerName.isEmpty ? peerRole.label : peerName,
    );
  }
}
