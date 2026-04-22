import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'customer_home_screen.dart';
import 'hotel_home_screen.dart';
import 'onboarding_screen.dart';
import 'rider_home_screen.dart';

class AuthGate extends StatelessWidget {
  AuthGate({super.key});

  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return const OnboardingScreen();
        }

        return StreamBuilder<AppUser?>(
          stream: _authService.userProfileStream(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnapshot.data;
            if (profile == null) {
              return const Scaffold(
                body: Center(
                  child: Text('Account profile not found. Please sign in again.'),
                ),
              );
            }

            switch (profile.role) {
              case UserRole.customer:
                return CustomerHomeScreen(user: profile);
              case UserRole.hotel:
                return HotelHomeScreen(user: profile);
              case UserRole.rider:
                return RiderHomeScreen(user: profile);
              case UserRole.admin:
                return AdminDashboardScreen(user: profile);
            }
          },
        );
      },
    );
  }
}
