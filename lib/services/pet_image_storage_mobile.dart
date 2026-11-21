import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'pet_image_storage.dart';

/// Factory function called by the conditional import on mobile platforms.
PetImageStorage createPetImageStorage() => _MobilePetImageStorage();

class _MobilePetImageStorage implements PetImageStorage {
  String? _documentsDirPath;
  final Map<String, Uint8List> _bytesCache = {};
  final Map<String, String> _pathCache = {};
  String _cachedUserId = '';

  String get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  }

  @override
  Future<void> init() async {
    try {
      if (_documentsDirPath == null) {
        final dir = await getApplicationDocumentsDirectory();
        _documentsDirPath = dir.path;
      }
      await syncUserCache();
    } catch (e) {
      debugPrint('MobilePetImageStorage init error: $e');
    }
  }

  @override
  Future<void> syncUserCache() async {
    if (_documentsDirPath == null) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        _documentsDirPath = dir.path;
      } catch (e) {
        debugPrint('Could not get documents directory: $e');
        return;
      }
    }

    final userId = _currentUserId;
    _cachedUserId = userId;
    _bytesCache.clear();
    _pathCache.clear();

    try {
      final userDir = Directory('$_documentsDirPath/pet_images/$userId');
      if (await userDir.exists()) {
        final entities = await userDir.list().toList();
        for (final entity in entities) {
          if (entity is File) {
            final filename = entity.uri.pathSegments.last;
            final dotIndex = filename.lastIndexOf('.');
            final petId = dotIndex != -1
                ? filename.substring(0, dotIndex)
                : filename;
            if (await entity.exists() && (await entity.length()) > 0) {
              _pathCache[petId] = entity.path;
              _bytesCache[petId] = await entity.readAsBytes();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing pet image cache: $e');
    }
  }

  Future<Directory> _getUserDirectory() async {
    if (_documentsDirPath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _documentsDirPath = dir.path;
    }
    final userDir = Directory('$_documentsDirPath/pet_images/$_currentUserId');
    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }
    return userDir;
  }

  void _checkUserChanged() {
    if (_cachedUserId != _currentUserId) {
      _cachedUserId = _currentUserId;
      _bytesCache.clear();
      _pathCache.clear();
      syncUserCache();
    }
  }

  @override
  Future<void> savePetImage({
    required String petId,
    required Uint8List bytes,
    String extension = '.jpg',
  }) async {
    final userDir = await _getUserDirectory();
    await deletePetImage(petId);

    final ext = ['.jpg', '.jpeg', '.png', '.webp'].contains(extension)
        ? extension
        : '.jpg';
    final targetPath = '${userDir.path}/$petId$ext';
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(bytes);

    _pathCache[petId] = targetPath;
    _bytesCache[petId] = bytes;
  }

  @override
  Future<void> deletePetImage(String petId) async {
    if (_documentsDirPath == null) {
      await init();
    }
    _bytesCache.remove(petId);
    _pathCache.remove(petId);

    try {
      final userDir = Directory(
        '$_documentsDirPath/pet_images/$_currentUserId',
      );
      if (await userDir.exists()) {
        final entities = await userDir.list().toList();
        for (final entity in entities) {
          if (entity is File) {
            final filename = entity.uri.pathSegments.last;
            final dotIndex = filename.lastIndexOf('.');
            final id = dotIndex != -1
                ? filename.substring(0, dotIndex)
                : filename;
            if (id == petId) {
              await entity.delete();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting local pet image for $petId: $e');
    }
  }

  @override
  Uint8List? getPetImageBytesSync(String petId) {
    _checkUserChanged();
    return _bytesCache[petId];
  }

  @override
  Future<Uint8List?> getPetImageBytes(String petId) async {
    if (_documentsDirPath == null) {
      await init();
    }
    _checkUserChanged();

    if (_bytesCache.containsKey(petId)) {
      return _bytesCache[petId];
    }

    // Try reading from disk
    final path = _pathCache[petId];
    if (path != null) {
      final file = File(path);
      if (await file.exists() && (await file.length()) > 0) {
        final bytes = await file.readAsBytes();
        _bytesCache[petId] = bytes;
        return bytes;
      }
    }
    return null;
  }

  @override
  ImageProvider? getPetImageProvider({String? petId, String? fallbackUrl}) {
    if (petId != null && petId.isNotEmpty) {
      _checkUserChanged();

      // Check bytes cache first
      final bytes = _bytesCache[petId];
      if (bytes != null && bytes.isNotEmpty) {
        return MemoryImage(bytes);
      }

      // Check path cache (file on disk)
      final path = _pathCache[petId];
      if (path != null) {
        final file = File(path);
        if (file.existsSync() && file.lengthSync() > 0) {
          return FileImage(file);
        }
      }
    }

    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      if (fallbackUrl.startsWith('http://') ||
          fallbackUrl.startsWith('https://')) {
        return NetworkImage(fallbackUrl);
      }
      return AssetImage(fallbackUrl);
    }

    return null;
  }

  @override
  bool hasLocalImage(String petId) {
    _checkUserChanged();
    return _bytesCache.containsKey(petId) || _pathCache.containsKey(petId);
  }
}
