import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key, required this.initialRole});

  final UserRole initialRole;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessController = TextEditingController();
  final _businessCategoryController = TextEditingController();
  final _businessDescriptionController = TextEditingController();
  final _bannerUrlController = TextEditingController();
  final _galleryUrlsController = TextEditingController();
  final _addressController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _plateController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  UserRole _role = UserRole.customer;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _businessController.dispose();
    _businessCategoryController.dispose();
    _businessDescriptionController.dispose();
    _bannerUrlController.dispose();
    _galleryUrlsController.dispose();
    _addressController.dispose();
    _vehicleController.dispose();
    _plateController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Create ${_role.label} Account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your account now. The role profile will be saved for portal routing.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Customer'),
                    selected: _role == UserRole.customer,
                    onSelected:
                        (_) => setState(() => _role = UserRole.customer),
                  ),
                  ChoiceChip(
                    label: const Text('Hotel / Shop / Business'),
                    selected: _role == UserRole.hotel,
                    onSelected: (_) => setState(() => _role = UserRole.hotel),
                  ),
                  ChoiceChip(
                    label: const Text('Rider'),
                    selected: _role == UserRole.rider,
                    onSelected: (_) => setState(() => _role = UserRole.rider),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildRoleFields(),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Required';
                  if (value.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Required';
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? 'Creating...' : 'Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleFields() {
    if (_role == UserRole.hotel) {
      return Column(
        children: [
          _field(_businessController, 'Business name'),
          const SizedBox(height: 12),
          _field(
            _businessCategoryController,
            'Business type (Hotel, Cosmetics, Salon, Plumbing...)',
          ),
          const SizedBox(height: 12),
          _field(_nameController, 'Contact person'),
          const SizedBox(height: 12),
          _field(_phoneController, 'Phone number'),
          const SizedBox(height: 12),
          _field(_emailController, 'Email address'),
          const SizedBox(height: 12),
          _field(_addressController, 'Business address'),
          const SizedBox(height: 12),
          _field(
            _businessDescriptionController,
            'What do you offer?',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          _field(
            _bannerUrlController,
            'Banner image URL (optional)',
            required: false,
          ),
          const SizedBox(height: 12),
          _field(
            _galleryUrlsController,
            'Photo URLs separated by commas (optional)',
            required: false,
            maxLines: 2,
          ),
        ],
      );
    }

    if (_role == UserRole.rider) {
      return Column(
        children: [
          _field(_nameController, 'Full name'),
          const SizedBox(height: 12),
          _field(_phoneController, 'Phone number'),
          const SizedBox(height: 12),
          _field(_emailController, 'Email address'),
          const SizedBox(height: 12),
          _field(_vehicleController, 'Vehicle type (Bike, Scooter...)'),
          const SizedBox(height: 12),
          _field(_plateController, 'Plate number'),
        ],
      );
    }

    return Column(
      children: [
        _field(_nameController, 'Full name'),
        const SizedBox(height: 12),
        _field(_phoneController, 'Phone number'),
        const SizedBox(height: 12),
        _field(_emailController, 'Email address'),
        const SizedBox(height: 12),
        _field(_addressController, 'Delivery address'),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Required';
        }
        return null;
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _emailController.text.trim();
      final galleryUrls =
          _galleryUrlsController.text
              .split(',')
              .map((url) => url.trim())
              .where((url) => url.isNotEmpty)
              .toList();
      final profile = AppUser(
        uid: '',
        role: _role,
        name: _nameController.text.trim(),
        email: email,
        phone: _phoneController.text.trim(),
        address:
            _role == UserRole.customer || _role == UserRole.hotel
                ? _addressController.text.trim()
                : null,
        businessName:
            _role == UserRole.hotel ? _businessController.text.trim() : null,
        businessCategory:
            _role == UserRole.hotel
                ? _businessCategoryController.text.trim()
                : null,
        serviceDescription:
            _role == UserRole.hotel
                ? _businessDescriptionController.text.trim()
                : null,
        bannerImageUrl:
            _role == UserRole.hotel ? _bannerUrlController.text.trim() : null,
        galleryImageUrls: _role == UserRole.hotel ? galleryUrls : const [],
        vehicleType:
            _role == UserRole.rider ? _vehicleController.text.trim() : null,
        plateNumber:
            _role == UserRole.rider ? _plateController.text.trim() : null,
      );

      await _authService.signUp(
        email: email,
        password: _passwordController.text,
        profile: profile,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = AuthService.friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
