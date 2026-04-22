import 'package:flutter/material.dart';

import '../models/app_user.dart';
import 'create_account_screen.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFF8E7), Color(0xFFF5F7F8)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 120,
                        child: Image.asset(
                          'assets/images/zahlivery_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Delivery platform for customers, hotels/shops, and riders',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                title: 'Customer Portal',
                subtitle: 'Browse menus, place orders, and view delivery updates.',
                icon: Icons.person_outline,
                onTap: () => _openCreate(context, UserRole.customer),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                title: 'Hotel / Shop Portal',
                subtitle: 'Receive orders, update status, and manage products.',
                icon: Icons.storefront_outlined,
                onTap: () => _openCreate(context, UserRole.hotel),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                title: 'Rider Portal',
                subtitle: 'Receive assigned deliveries and mark completion.',
                icon: Icons.two_wheeler_outlined,
                onTap: () => _openCreate(context, UserRole.rider),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('Login'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openCreate(context, UserRole.customer),
                icon: const Icon(Icons.app_registration),
                label: const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCreate(BuildContext context, UserRole role) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateAccountScreen(initialRole: role),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0x1A6DBE00),
                child: Icon(icon, color: const Color(0xFF2E5E00)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
