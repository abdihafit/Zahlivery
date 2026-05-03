import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { customer, hotel, rider, admin }

extension UserRoleX on UserRole {
  String get value {
    switch (this) {
      case UserRole.customer:
        return 'customer';
      case UserRole.hotel:
        return 'hotel';
      case UserRole.rider:
        return 'rider';
      case UserRole.admin:
        return 'admin';
    }
  }

  String get label {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.hotel:
        return 'Hotel / Shop / Business';
      case UserRole.rider:
        return 'Rider';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

UserRole userRoleFromString(String value) {
  switch (value) {
    case 'hotel':
      return UserRole.hotel;
    case 'rider':
      return UserRole.rider;
    case 'admin':
      return UserRole.admin;
    case 'customer':
    default:
      return UserRole.customer;
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    this.address,
    this.businessName,
    this.businessCategory,
    this.serviceDescription,
    this.bannerImageUrl,
    this.galleryImageUrls = const [],
    this.vehicleType,
    this.plateNumber,
  });

  final String uid;
  final UserRole role;
  final String name;
  final String email;
  final String phone;
  final String? address;
  final String? businessName;
  final String? businessCategory;
  final String? serviceDescription;
  final String? bannerImageUrl;
  final List<String> galleryImageUrls;
  final String? vehicleType;
  final String? plateNumber;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role.value,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'businessName': businessName,
      'businessCategory': businessCategory,
      'serviceDescription': serviceDescription,
      'bannerImageUrl': bannerImageUrl,
      'galleryImageUrls': galleryImageUrls,
      'vehicleType': vehicleType,
      'plateNumber': plateNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String? ?? '',
      role: userRoleFromString(map['role'] as String? ?? 'customer'),
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String?,
      businessName: map['businessName'] as String?,
      businessCategory: map['businessCategory'] as String?,
      serviceDescription: map['serviceDescription'] as String?,
      bannerImageUrl: map['bannerImageUrl'] as String?,
      galleryImageUrls:
          (map['galleryImageUrls'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .map((url) => url.trim())
              .where((url) => url.isNotEmpty)
              .toList(),
      vehicleType: map['vehicleType'] as String?,
      plateNumber: map['plateNumber'] as String?,
    );
  }
}
