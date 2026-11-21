import 'dart:typed_data';
import 'package:flutter/material.dart';

// Conditional import: mobile uses dart:io-based implementation,
// web uses IndexedDB-based implementation.
import 'pet_image_storage_stub.dart'
    if (dart.library.io) 'pet_image_storage_mobile.dart'
    if (dart.library.js_interop) 'pet_image_storage_web.dart';

/// Platform-agnostic interface for local pet image storage.
///
/// On Android: images are stored as files in the app's documents directory.
/// On Web (Chrome): images are stored as byte arrays in IndexedDB.
abstract class PetImageStorage {
  /// Factory constructor that returns the platform-specific implementation.
  factory PetImageStorage() => createPetImageStorage();

  /// Initialize the storage backend and load any cached images for the
  /// current user into memory.
  Future<void> init();

  /// Synchronize the in-memory cache with on-disk/IndexedDB storage
  /// for the current user.
  Future<void> syncUserCache();

  /// Save image [bytes] for [petId]. Replaces any existing image.
  Future<void> savePetImage({
    required String petId,
    required Uint8List bytes,
    String extension,
  });

  /// Delete the stored image for [petId], if any.
  Future<void> deletePetImage(String petId);

  /// Get the raw image bytes for [petId], or null if none stored.
  Uint8List? getPetImageBytesSync(String petId);

  /// Asynchronously get image bytes for [petId].
  Future<Uint8List?> getPetImageBytes(String petId);

  /// Returns an [ImageProvider] for the pet image.
  ///
  /// Priority:
  /// 1. Local image for [petId] (from storage).
  /// 2. [fallbackUrl] as network image (http/https).
  /// 3. [fallbackUrl] as asset image.
  /// 4. null if nothing is available.
  ImageProvider? getPetImageProvider({String? petId, String? fallbackUrl});

  /// Whether a local image exists for [petId].
  bool hasLocalImage(String petId);
}
