import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required AppUser profile,
  }) async {
    final credential = await _withRetry(
      () => _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );

    final firebaseUser = credential.user!;
    await _withRetry(() => firebaseUser.getIdToken(true));

    final uid = firebaseUser.uid;
    final user = AppUser(
      uid: uid,
      role: profile.role,
      name: profile.name,
      email: profile.email,
      phone: profile.phone,
      address: profile.address,
      businessName: profile.businessName,
      vehicleType: profile.vehicleType,
      plateNumber: profile.plateNumber,
    );

    try {
      await _withRetry(
        () => _firestore.collection('users').doc(uid).set({
          ...user.toMap(),
          if (profile.role == UserRole.rider) 'available': true,
          'createdAt': FieldValue.serverTimestamp(),
        }),
      );
    } catch (_) {
      await firebaseUser.delete();
      rethrow;
    }
  }

  Stream<AppUser?> userProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return AppUser.fromMap({
        ...data,
        'uid': (data['uid'] as String?)?.trim().isNotEmpty == true
            ? data['uid']
            : snapshot.id,
      });
    });
  }

  static String friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'This email is already used by another account.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'invalid-email':
          return 'Email format is invalid.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Invalid email or password.';
        case 'network-request-failed':
        case 'internal-error':
          return 'Network error. Please check your internet connection and try again.';
        default:
          return error.message ?? 'Authentication error occurred.';
      }
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Permission denied. Please check Firestore rules.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Network error. Please check your internet connection and try again.';
      }
    }
    return error.toString();
  }

  Future<T> _withRetry<T>(Future<T> Function() action) async {
    const delays = [Duration(milliseconds: 300), Duration(milliseconds: 900)];
    Object? lastError;
    for (var attempt = 0; attempt <= delays.length; attempt++) {
      try {
        return await action();
      } catch (error) {
        lastError = error;
        if (!_isRetryable(error) || attempt == delays.length) {
          rethrow;
        }
        await Future.delayed(delays[attempt]);
      }
    }
    throw lastError!;
  }

  bool _isRetryable(Object error) {
    if (error is FirebaseAuthException) {
      return error.code == 'network-request-failed' ||
          error.code == 'internal-error';
    }
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
          error.code == 'deadline-exceeded';
    }
    final message = error.toString().toLowerCase();
    return message.contains('unexpected end of stream') ||
        message.contains('connection reset') ||
        message.contains('timeout');
  }
}
