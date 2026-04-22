import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/invoice_model.dart';

class InvoiceService {
  InvoiceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  InvoiceModel generateInvoice(
    Map<String, dynamic> parsedTransaction, {
    required String sellerPin,
    String buyerName = 'Retail Customer',
  }) {
    return generateInvoiceFromMpesaTransaction(
      sellerPin: sellerPin,
      parsedTransaction: parsedTransaction,
      buyerName: buyerName,
    );
  }

  Future<Map<String, dynamic>> createInvoiceFromMpesaTransaction({
    required String userId,
    required String sellerPin,
    required Map<String, dynamic> parsedTransaction,
    String buyerName = 'Retail Customer',
  }) async {
    final invoice = generateInvoiceFromMpesaTransaction(
      sellerPin: sellerPin,
      parsedTransaction: parsedTransaction,
      buyerName: buyerName,
    );

    await saveInvoice(userId: userId, invoice: invoice);
    return invoice.toSubmissionMap();
  }

  InvoiceModel generateInvoiceFromMpesaTransaction({
    required String sellerPin,
    required Map<String, dynamic> parsedTransaction,
    String buyerName = 'Retail Customer',
  }) {
    final amount = _readAmount(parsedTransaction);
    final taxAmount = _roundCurrency(amount * 0.16);
    final totalAmount = _roundCurrency(amount + taxAmount);
    final timestamp = _readTimestamp(parsedTransaction);
    final invoiceNumber = _generateInvoiceNumber(parsedTransaction, timestamp);

    return InvoiceModel(
      invoiceNumber: invoiceNumber,
      sellerPin: sellerPin,
      buyerName: buyerName,
      buyerPhone: _readString(parsedTransaction, const [
        'buyerPhone',
        'phone',
        'phoneNumber',
        'msisdn',
        'senderPhone',
      ]),
      itemDescription: _readString(parsedTransaction, const [
        'itemDescription',
        'description',
        'billRefNumber',
        'transactionType',
      ], fallback: 'M-Pesa Sale'),
      amount: amount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      timestamp: timestamp,
      status: InvoiceStatus.pending,
    );
  }

  Future<void> saveInvoice({
    required String userId,
    required InvoiceModel invoice,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('invoices')
        .doc(invoice.invoiceNumber)
        .set(invoice.toFirestore());
  }

  Map<String, dynamic> buildSubmissionMap(InvoiceModel invoice) {
    return invoice.toSubmissionMap();
  }

  String _generateInvoiceNumber(
    Map<String, dynamic> parsedTransaction,
    DateTime timestamp,
  ) {
    final transactionId = _readString(parsedTransaction, const [
      'transactionId',
      'mpesaReceiptNumber',
      'receiptNumber',
      'checkoutRequestId',
    ]);
    final suffix = transactionId.isEmpty
        ? timestamp.millisecondsSinceEpoch.toString()
        : transactionId.replaceAll(' ', '').toUpperCase();
    return 'INV-$suffix';
  }

  double _readAmount(Map<String, dynamic> parsedTransaction) {
    final raw = _readFirstValue(parsedTransaction, const [
      'amount',
      'transAmount',
      'transactionAmount',
    ]);
    final amount = _toDouble(raw);
    return _roundCurrency(amount);
  }

  DateTime _readTimestamp(Map<String, dynamic> parsedTransaction) {
    final raw = _readFirstValue(parsedTransaction, const [
      'timestamp',
      'transactionDate',
      'transTime',
      'createdAt',
    ]);

    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;

    final text = raw?.toString() ?? '';
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    if (text.length == 14) {
      final year = int.tryParse(text.substring(0, 4));
      final month = int.tryParse(text.substring(4, 6));
      final day = int.tryParse(text.substring(6, 8));
      final hour = int.tryParse(text.substring(8, 10));
      final minute = int.tryParse(text.substring(10, 12));
      final second = int.tryParse(text.substring(12, 14));
      if ([year, month, day, hour, minute, second].every((v) => v != null)) {
        return DateTime(year!, month!, day!, hour!, minute!, second!);
      }
    }

    return DateTime.now();
  }

  String _readString(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    final value = _readFirstValue(source, keys);
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Object? _readFirstValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      if (source.containsKey(key) && source[key] != null) {
        return source[key];
      }
    }
    return null;
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _roundCurrency(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}
