import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/invoice_model.dart';
import 'etims_service.dart';
import 'invoice_service.dart';

class InvoiceSubmissionService {
  InvoiceSubmissionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    InvoiceService? invoiceService,
    EtimsService? etimsService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _invoiceService = invoiceService ?? InvoiceService(firestore: firestore),
        _etimsService = etimsService ??
            EtimsService(
              firestore: firestore,
              auth: auth,
            );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final InvoiceService _invoiceService;
  final EtimsService _etimsService;

  StreamSubscription<User?>? _authSubscription;
  bool _retrying = false;

  void initialize() {
    _authSubscription ??= _auth.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(retryQueuedInvoices());
      }
    });
  }

  Future<InvoiceSubmissionResult> handleParsedTransaction({
    required Map<String, dynamic> transaction,
    required String sellerPin,
    String buyerName = 'Retail Customer',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user found for invoice submission.');
    }

    final invoice = _invoiceService.generateInvoice(
      transaction,
      sellerPin: sellerPin,
      buyerName: buyerName,
    );
    await _invoiceService.saveInvoice(userId: user.uid, invoice: invoice);

    try {
      final response = await _etimsService.submitInvoice(invoice);
      await _clearQueueItem(user.uid, invoice.invoiceNumber);
      return InvoiceSubmissionResult(
        invoice: invoice,
        submitted: true,
        userMessage: 'Invoice #${invoice.invoiceNumber} submitted to KRA ✓',
        response: response,
      );
    } catch (error) {
      await _enqueueForRetry(
        userId: user.uid,
        invoice: invoice,
        errorMessage: error.toString(),
      );
      return InvoiceSubmissionResult(
        invoice: invoice,
        submitted: false,
        userMessage: 'Invoice saved — will retry when online',
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> retryQueuedInvoices() async {
    final user = _auth.currentUser;
    if (user == null || _retrying) return;

    _retrying = true;
    try {
      final queueSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('invoiceSubmissionQueue')
          .get();

      for (final doc in queueSnapshot.docs) {
        final data = doc.data();
        final invoice = InvoiceModel.fromMap(data['invoice'] as Map<String, dynamic>);
        try {
          await _etimsService.submitInvoice(invoice);
          await doc.reference.delete();
        } catch (error) {
          await doc.reference.set({
            'invoice': invoice.toFirestore(),
            'lastError': error.toString(),
            'retryCount': (data['retryCount'] as int? ?? 0) + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } finally {
      _retrying = false;
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }

  Future<void> _enqueueForRetry({
    required String userId,
    required InvoiceModel invoice,
    required String errorMessage,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('invoiceSubmissionQueue')
        .doc(invoice.invoiceNumber)
        .set({
      'invoice': invoice.toFirestore(),
      'status': 'queued',
      'lastError': errorMessage,
      'retryCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _clearQueueItem(String userId, String invoiceNumber) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('invoiceSubmissionQueue')
        .doc(invoiceNumber)
        .delete();
  }
}

class InvoiceSubmissionResult {
  const InvoiceSubmissionResult({
    required this.invoice,
    required this.submitted,
    required this.userMessage,
    this.response,
    this.errorMessage,
  });

  final InvoiceModel invoice;
  final bool submitted;
  final String userMessage;
  final Map<String, dynamic>? response;
  final String? errorMessage;
}
