import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'pet_image_storage.dart';

/// Facade over the platform-specific [PetImageStorage] implementation.
///
/// This service retains the same public API so that all existing pages
/// (home_page, pet_details_page, feeding_schedule_page, etc.) continue
/// working without any import changes.
///
/// On Android: images are stored as files in the app documents directory.
/// On Web (Chrome): images are stored as byte arrays in IndexedDB.
///
/// Does NOT use any cloud image storage service.
class LocalPetImageService {
  static final LocalPetImageService _instance =
      LocalPetImageService._internal();
  factory LocalPetImageService() => _instance;
  LocalPetImageService._internal();

  final PetImageStorage _storage = PetImageStorage();

  /// Initialize the underlying platform storage.
  Future<void> init() => _storage.init();

  /// Synchronize the in-memory cache for the current user.
  Future<void> syncUserCache() => _storage.syncUserCache();

  /// Save or replace a pet profile picture from raw [bytes].
  Future<void> savePetImageBytes({
    required String petId,
    required Uint8List bytes,
    String extension = '.jpg',
  }) =>
      _storage.savePetImage(
        petId: petId,
        bytes: bytes,
        extension: extension,
      );

  /// Delete the locally stored image for [petId].
  Future<void> deletePetImage(String petId) =>
      _storage.deletePetImage(petId);

  /// Get image bytes synchronously from cache (may be null if not cached).
  Uint8List? getPetImageBytesSync(String petId) =>
      _storage.getPetImageBytesSync(petId);

  /// Get image bytes asynchronously (checks storage if not in cache).
  Future<Uint8List?> getPetImageBytes(String petId) =>
      _storage.getPetImageBytes(petId);

  /// Returns an [ImageProvider] for a pet.
  ///
  /// Priority:
  /// 1. Locally saved image for [petId].
  /// 2. [fallbackUrl] as network image (http/https).
  /// 3. [fallbackUrl] as asset image.
  /// 4. null if nothing is available.
  ImageProvider? getPetImageProvider({
    String? petId,
    String? fallbackUrl,
  }) =>
      _storage.getPetImageProvider(
        petId: petId,
        fallbackUrl: fallbackUrl,
      );

  /// Whether a local image exists for [petId].
  bool hasLocalImage(String petId) => _storage.hasLocalImage(petId);
}
