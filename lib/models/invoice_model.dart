import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceModel {
  const InvoiceModel({
    required this.invoiceNumber,
    required this.sellerPin,
    this.buyerName = 'Retail Customer',
    required this.buyerPhone,
    required this.itemDescription,
    required this.amount,
    required this.taxAmount,
    required this.totalAmount,
    required this.timestamp,
    this.status = InvoiceStatus.pending,
  });

  final String invoiceNumber;
  final String sellerPin;
  final String buyerName;
  final String buyerPhone;
  final String itemDescription;
  final double amount;
  final double taxAmount;
  final double totalAmount;
  final DateTime timestamp;
  final String status;

  Map<String, dynamic> toFirestore() {
    return {
      'invoiceNumber': invoiceNumber,
      'sellerPin': sellerPin,
      'buyerName': buyerName,
      'buyerPhone': buyerPhone,
      'itemDescription': itemDescription,
      'amount': amount,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
    };
  }

  Map<String, dynamic> toSubmissionMap() {
    return {
      'invoiceNumber': invoiceNumber,
      'sellerPin': sellerPin,
      'buyerName': buyerName,
      'buyerPhone': buyerPhone,
      'itemDescription': itemDescription,
      'amount': amount,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    final rawTimestamp = map['timestamp'];
    return InvoiceModel(
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      sellerPin: map['sellerPin'] as String? ?? '',
      buyerName: map['buyerName'] as String? ?? 'Retail Customer',
      buyerPhone: map['buyerPhone'] as String? ?? '',
      itemDescription: map['itemDescription'] as String? ?? '',
      amount: _toDouble(map['amount']),
      taxAmount: _toDouble(map['taxAmount']),
      totalAmount: _toDouble(map['totalAmount']),
      timestamp: rawTimestamp is Timestamp
          ? rawTimestamp.toDate()
          : DateTime.tryParse(rawTimestamp?.toString() ?? '') ?? DateTime.now(),
      status: map['status'] as String? ?? InvoiceStatus.pending,
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class InvoiceStatus {
  static const pending = 'pending';
  static const submitted = 'submitted';
  static const accepted = 'accepted';
}
