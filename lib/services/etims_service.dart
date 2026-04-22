import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/invoice_model.dart';

class EtimsService {
  EtimsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? client,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client();

  static const String _submitUrl =
      'https://etims-api-sbx.kra.go.ke/etims-api/insertTrnsSalesI';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final http.Client _client;

  Future<Map<String, dynamic>> submitInvoice(InvoiceModel invoice) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user found for invoice submission.');
    }

    final payload = _buildEtimsPayload(invoice);
    final invoiceRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('invoices')
        .doc(invoice.invoiceNumber);

    try {
      final response = await _client.post(
        Uri.parse(_submitUrl),
        headers: {
          'Content-Type': 'application/json',
          'tin': invoice.sellerPin,
          'bhfId': '00',
        },
        body: jsonEncode(payload),
      );

      final responseBody = _decodeJson(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await invoiceRef.set({
          'status': InvoiceStatus.submitted,
          'submittedAt': FieldValue.serverTimestamp(),
          'lastSubmissionResponse': responseBody,
          'lastSubmissionError': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return {
          'success': true,
          'statusCode': response.statusCode,
          'payload': payload,
          'response': responseBody,
        };
      }

      final errorMessage =
          _extractErrorMessage(responseBody) ??
          'eTIMS submission failed with status ${response.statusCode}.';
      await _saveSubmissionError(
        invoiceRef: invoiceRef,
        errorMessage: errorMessage,
        statusCode: response.statusCode,
        payload: payload,
        responseBody: responseBody,
      );
      throw EtimsSubmissionException(errorMessage);
    } catch (error) {
      if (error is EtimsSubmissionException) rethrow;

      await _saveSubmissionError(
        invoiceRef: invoiceRef,
        errorMessage: error.toString(),
        payload: payload,
      );
      throw EtimsSubmissionException(error.toString());
    }
  }

  Map<String, dynamic> _buildEtimsPayload(InvoiceModel invoice) {
    return {
      'bhfId': '00',
      'tin': invoice.sellerPin,
      'invoiceNo': invoice.invoiceNumber,
      'saleTypeCd': 'N',
      'salesDt': _formatEtimsDate(invoice.timestamp),
      'custNm': invoice.buyerName,
      'custTin': '',
      'custBhfId': '00',
      'custMblNo': invoice.buyerPhone,
      'remark': invoice.itemDescription,
      'totTaxblAmt': invoice.amount,
      'totTaxAmt': invoice.taxAmount,
      'totAmt': invoice.totalAmount,
      'itemList': [
        {
          'itemSeq': 1,
          'itemCd': invoice.invoiceNumber,
          'itemClsCd': '5800000000',
          'itemNm': invoice.itemDescription,
          'pkgUnitCd': 'NT',
          'pkg': 1,
          'qtyUnitCd': 'U',
          'qty': 1,
          'prc': invoice.amount,
          'splyAmt': invoice.amount,
          'dcRt': 0,
          'dcAmt': 0,
          'taxTyCd': 'A',
          'taxblAmt': invoice.amount,
          'taxAmt': invoice.taxAmount,
          'totAmt': invoice.totalAmount,
        },
      ],
    };
  }

  Future<void> _saveSubmissionError({
    required DocumentReference<Map<String, dynamic>> invoiceRef,
    required String errorMessage,
    int? statusCode,
    Map<String, dynamic>? payload,
    Object? responseBody,
  }) async {
    await invoiceRef.set({
      'status': InvoiceStatus.pending,
      'lastSubmissionError': errorMessage,
      'lastSubmissionStatusCode': statusCode,
      'lastSubmissionPayload': payload,
      'lastSubmissionResponse': responseBody,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Object _decodeJson(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String? _extractErrorMessage(Object responseBody) {
    if (responseBody is Map<String, dynamic>) {
      for (final key in const ['message', 'error', 'remark']) {
        final value = responseBody[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
    }
    if (responseBody is String && responseBody.trim().isNotEmpty) {
      return responseBody;
    }
    return null;
  }

  String _formatEtimsDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }
}

class EtimsSubmissionException implements Exception {
  EtimsSubmissionException(this.message);

  final String message;

  @override
  String toString() => message;
}
