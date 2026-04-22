import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'services/invoice_submission_service.dart';
import 'services/push_notification_service.dart';
import 'screens/auth_gate.dart';

final InvoiceSubmissionService _invoiceSubmissionService =
    InvoiceSubmissionService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await PushNotificationService.instance.initialize();
  _invoiceSubmissionService.initialize();
  runApp(const ZahliveryApp());
}

class ZahliveryApp extends StatelessWidget {
  const ZahliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zahlivery',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6DBE00),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 1,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: AuthGate(),
    );
  }
}
