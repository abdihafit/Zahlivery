enum ChatMessageType {
  text,
  orderSummary,
  paymentInfo,
  paymentConfirmation,
  stkRequest,
}

extension ChatMessageTypeX on ChatMessageType {
  String get value {
    switch (this) {
      case ChatMessageType.text:
        return 'text';
      case ChatMessageType.orderSummary:
        return 'order_summary';
      case ChatMessageType.paymentInfo:
        return 'payment_info';
      case ChatMessageType.paymentConfirmation:
        return 'payment_confirmation';
      case ChatMessageType.stkRequest:
        return 'stk_request';
    }
  }
}

enum ChatPaymentStatus { pending, pendingConfirmation, confirmed }

extension ChatPaymentStatusX on ChatPaymentStatus {
  String get value {
    switch (this) {
      case ChatPaymentStatus.pending:
        return 'pending';
      case ChatPaymentStatus.pendingConfirmation:
        return 'pending_confirmation';
      case ChatPaymentStatus.confirmed:
        return 'confirmed';
    }
  }
}
