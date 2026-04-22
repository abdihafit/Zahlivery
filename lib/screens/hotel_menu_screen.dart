import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';

class HotelMenuScreen extends StatefulWidget {
  const HotelMenuScreen({super.key, required this.hotel});

  final AppUser hotel;

  @override
  State<HotelMenuScreen> createState() => _HotelMenuScreenState();
}

class _HotelMenuScreenState extends State<HotelMenuScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();
  static const int _maxMenuPhotos = 4;

  @override
  Widget build(BuildContext context) {
    final signedInUser = FirebaseAuth.instance.currentUser;
    if (signedInUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Session expired. Please sign in again.'),
        ),
      );
    }
    final signedInUid = signedInUser.uid;
    final menuStream = _firestore
        .collection('users')
        .doc(signedInUid)
        .collection('menuItems')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Menu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: menuStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No menu items yet.\nTap "Add Item" to create your menu.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name = data['name'] as String? ?? 'Item';
              final description = data['description'] as String? ?? '';
              final imageUrls = _readImageUrls(data);
              final imageUrl = imageUrls.isNotEmpty
                  ? imageUrls.first
                  : (data['imageUrl'] as String? ?? '');
              final available = data['available'] as bool? ?? true;
              final price = _toDouble(data['price']);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMenuImageGallery(
                        context: context,
                        imageUrls: imageUrls,
                        fallbackImageUrl: imageUrl,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text('KSH ${price.toStringAsFixed(2)}'),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(description),
                                ],
                                if (imageUrls.length > 1) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '${imageUrls.length} photos attached',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Switch(
                                      value: available,
                                      onChanged: (value) => _toggleAvailability(
                                        itemId: doc.id,
                                        value: value,
                                      ),
                                    ),
                                    Text(available ? 'Available' : 'Hidden'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete item',
                            onPressed: () => _deleteItem(doc.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddItemSheet() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final selectedImages = <XFile>[];
    var saving = false;
    final parentContext = context;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Menu Item',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Item name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Price'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Food photos',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (selectedImages.isNotEmpty)
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedImages.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final image = selectedImages[index];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(image.path),
                                    width: 88,
                                    height: 88,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: InkWell(
                                    onTap: saving
                                        ? null
                                        : () {
                                            setModalState(() {
                                              selectedImages.removeAt(index);
                                            });
                                          },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    if (selectedImages.isNotEmpty) const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final remainingSlots =
                                  _maxMenuPhotos - selectedImages.length;
                              if (remainingSlots <= 0) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(parentContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'You can upload up to 4 photos per menu item.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final images = await _picker.pickMultiImage(
                                imageQuality: 80,
                                maxWidth: 1200,
                              );
                              if (images.isEmpty) return;

                              setModalState(() {
                                for (final image in images.take(remainingSlots)) {
                                  selectedImages.add(image);
                                }
                              });
                            },
                      icon: const Icon(Icons.photo_outlined),
                      label: Text(
                        selectedImages.isEmpty
                            ? 'Upload Up To 4 Photos'
                            : 'Add More Photos (${selectedImages.length}/4)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final priceText = priceController.text.trim();
                                final price = double.tryParse(priceText);

                                if (name.isEmpty || price == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please provide a valid name and price.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (selectedImages.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please upload at least one food photo.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);
                                try {
                                  final currentUserId =
                                      FirebaseAuth.instance.currentUser?.uid ??
                                          widget.hotel.uid;
                                  final itemRef = _firestore
                                      .collection('users')
                                      .doc(currentUserId)
                                      .collection('menuItems')
                                      .doc();

                                  await itemRef.set({
                                    'name': name,
                                    'description':
                                        descriptionController.text.trim(),
                                    'price': price,
                                    'imageUrl': '',
                                    'imageUrls': const <String>[],
                                    'available': true,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                                  final imageUrls = <String>[];
                                  var failedUploads = 0;
                                  Object? firstUploadError;
                                  for (final image in selectedImages) {
                                    try {
                                      final imageUrl = await _uploadMenuImage(
                                        hotelId: currentUserId,
                                        itemId: itemRef.id,
                                        file: image,
                                      );
                                      imageUrls.add(imageUrl);
                                    } catch (error) {
                                      failedUploads++;
                                      firstUploadError ??= error;
                                    }
                                  }

                                  await itemRef.update({
                                    'imageUrl':
                                        imageUrls.isEmpty ? '' : imageUrls.first,
                                    'imageUrls': imageUrls,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                                  if (!parentContext.mounted) return;
                                  Navigator.of(parentContext).pop();
                                  ScaffoldMessenger.of(parentContext).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _buildSaveMessage(
                                          failedUploads: failedUploads,
                                          totalImages: selectedImages.length,
                                          firstUploadError: firstUploadError,
                                        ),
                                      ),
                                    ),
                                  );
                                } catch (error) {
                                  if (parentContext.mounted) {
                                    ScaffoldMessenger.of(parentContext).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to add menu item: $error',
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setModalState(() => saving = false);
                                  }
                                }
                              },
                        child: Text(saving ? 'Saving...' : 'Save Item'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String> _uploadMenuImage({
    required String hotelId,
    required String itemId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final ref = _storage
        .ref()
        .child('menu_items')
        .child(hotelId)
        .child(itemId)
        .child(fileName);
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: file.mimeType ?? 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  Future<void> _toggleAvailability({
    required String itemId,
    required bool value,
  }) async {
    await _firestore
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid ?? widget.hotel.uid)
        .collection('menuItems')
        .doc(itemId)
        .update({
      'available': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteItem(String itemId) async {
    await _firestore
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid ?? widget.hotel.uid)
        .collection('menuItems')
        .doc(itemId)
        .delete();
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<String> _readImageUrls(Map<String, dynamic> data) {
    final raw = data['imageUrls'];
    if (raw is List) {
      return raw
          .map((item) => item?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final fallback = data['imageUrl'] as String? ?? '';
    return fallback.isEmpty ? const [] : [fallback];
  }

  Widget _buildMenuImageGallery({
    required BuildContext context,
    required List<String> imageUrls,
    required String fallbackImageUrl,
  }) {
    final galleryImages = imageUrls.isNotEmpty
        ? imageUrls
        : (fallbackImageUrl.isEmpty ? const <String>[] : [fallbackImageUrl]);

    if (galleryImages.isEmpty) {
      return Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0x11000000),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.fastfood_outlined, size: 32),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: galleryImages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final imageUrl = galleryImages[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 160,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0x11000000),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _buildSaveMessage({
    required int failedUploads,
    required int totalImages,
    required Object? firstUploadError,
  }) {
    if (failedUploads == 0) {
      return 'Menu item saved successfully.';
    }

    final errorText = firstUploadError?.toString().toLowerCase() ?? '';
    final storageUnavailable = errorText.contains('storage not available') ||
        errorText.contains('no-default-bucket') ||
        errorText.contains('bucket');

    if (failedUploads == totalImages && storageUnavailable) {
      return 'Menu item saved, but Firebase Storage is not available, so the photos were skipped.';
    }

    if (failedUploads == totalImages) {
      return 'Menu item saved, but the photos could not be uploaded.';
    }

    return 'Menu item saved. $failedUploads photo upload(s) failed.';
  }
}
