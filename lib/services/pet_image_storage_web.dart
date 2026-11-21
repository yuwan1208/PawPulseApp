import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'pet_image_storage.dart';

/// Factory function called by the conditional import on web platforms.
PetImageStorage createPetImageStorage() => _WebPetImageStorage();

class _WebPetImageStorage implements PetImageStorage {
  static const _dbName = 'PawPulsePetImages';
  static const _storeName = 'images';
  static const _dbVersion = 1;

  web.IDBDatabase? _db;
  final Map<String, Uint8List> _bytesCache = {};
  String _cachedUserId = '';

  String get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  }

  /// Open the IndexedDB database, creating the object store if needed.
  Future<web.IDBDatabase> _openDatabase() async {
    if (_db != null) return _db!;

    final completer = Completer<web.IDBDatabase>();
    final request = web.window.self.indexedDB.open(_dbName, _dbVersion);

    request.onupgradeneeded = ((web.IDBVersionChangeEvent event) {
      final db =
          (event.target as web.IDBOpenDBRequest).result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    }).toJS;

    request.onsuccess = ((web.Event event) {
      _db = (event.target as web.IDBOpenDBRequest).result as web.IDBDatabase;
      completer.complete(_db!);
    }).toJS;

    request.onerror = ((web.Event event) {
      debugPrint('IndexedDB open error');
      completer.completeError('Failed to open IndexedDB');
    }).toJS;

    return completer.future;
  }

  /// Build a storage key: "userId/petId"
  String _key(String petId) => '$_currentUserId/$petId';

  @override
  Future<void> init() async {
    try {
      await _openDatabase();
      await syncUserCache();
    } catch (e) {
      debugPrint('WebPetImageStorage init error: $e');
    }
  }

  @override
  Future<void> syncUserCache() async {
    final userId = _currentUserId;
    _cachedUserId = userId;
    _bytesCache.clear();

    try {
      final db = await _openDatabase();
      final completer = Completer<void>();
      final txn = db.transaction(_storeName.toJS, 'readonly');
      final store = txn.objectStore(_storeName);
      final request = store.openCursor();

      final prefix = '$userId/';

      request.onsuccess = ((web.Event event) {
        final cursor =
            (event.target as web.IDBRequest).result as web.IDBCursorWithValue?;
        if (cursor != null) {
          final key = (cursor.key as JSString).toDart;
          if (key.startsWith(prefix)) {
            final petId = key.substring(prefix.length);
            final jsValue = cursor.value;
            // The stored value is a JSArrayBuffer or JSUint8Array
            if (jsValue != null) {
              try {
                final arrayBuffer = jsValue as JSArrayBuffer;
                final bytes = arrayBuffer.toDart.asUint8List();
                _bytesCache[petId] = Uint8List.fromList(bytes);
              } catch (_) {
                // Try as Uint8Array
                try {
                  final uint8Array = jsValue as JSUint8Array;
                  _bytesCache[petId] = Uint8List.fromList(uint8Array.toDart);
                } catch (e) {
                  debugPrint('Could not read cached image for $petId: $e');
                }
              }
            }
          }
          cursor.continue_();
        } else {
          completer.complete();
        }
      }).toJS;

      request.onerror = ((web.Event event) {
        debugPrint('IndexedDB cursor error during sync');
        if (!completer.isCompleted) completer.complete();
      }).toJS;

      await completer.future;
    } catch (e) {
      debugPrint('Error syncing web pet image cache: $e');
    }
  }

  void _checkUserChanged() {
    if (_cachedUserId != _currentUserId) {
      _cachedUserId = _currentUserId;
      _bytesCache.clear();
      syncUserCache();
    }
  }

  @override
  Future<void> savePetImage({
    required String petId,
    required Uint8List bytes,
    String extension = '.jpg',
  }) async {
    final db = await _openDatabase();
    final completer = Completer<void>();
    final txn = db.transaction(_storeName.toJS, 'readwrite');
    final store = txn.objectStore(_storeName);

    // Store as ArrayBuffer
    final jsBytes = bytes.buffer.toJS;
    final request = store.put(jsBytes, _key(petId).toJS);

    request.onsuccess = ((web.Event _) {
      _bytesCache[petId] = bytes;
      completer.complete();
    }).toJS;

    request.onerror = ((web.Event _) {
      debugPrint('IndexedDB put error for $petId');
      if (!completer.isCompleted) {
        completer.completeError('Failed to save image in IndexedDB');
      }
    }).toJS;

    await completer.future;
  }

  @override
  Future<void> deletePetImage(String petId) async {
    _bytesCache.remove(petId);

    try {
      final db = await _openDatabase();
      final completer = Completer<void>();
      final txn = db.transaction(_storeName.toJS, 'readwrite');
      final store = txn.objectStore(_storeName);
      final request = store.delete(_key(petId).toJS);

      request.onsuccess = ((web.Event _) {
        completer.complete();
      }).toJS;

      request.onerror = ((web.Event _) {
        debugPrint('IndexedDB delete error for $petId');
        if (!completer.isCompleted) completer.complete();
      }).toJS;

      await completer.future;
    } catch (e) {
      debugPrint('Error deleting web pet image for $petId: $e');
    }
  }

  @override
  Uint8List? getPetImageBytesSync(String petId) {
    _checkUserChanged();
    return _bytesCache[petId];
  }

  @override
  Future<Uint8List?> getPetImageBytes(String petId) async {
    _checkUserChanged();

    if (_bytesCache.containsKey(petId)) {
      return _bytesCache[petId];
    }

    // Try reading from IndexedDB
    try {
      final db = await _openDatabase();
      final completer = Completer<Uint8List?>();
      final txn = db.transaction(_storeName.toJS, 'readonly');
      final store = txn.objectStore(_storeName);
      final request = store.get(_key(petId).toJS);

      request.onsuccess = ((web.Event event) {
        final jsValue = (event.target as web.IDBRequest).result;
        if (jsValue != null && !jsValue.isUndefinedOrNull) {
          try {
            final arrayBuffer = jsValue as JSArrayBuffer;
            final bytes = Uint8List.fromList(arrayBuffer.toDart.asUint8List());
            _bytesCache[petId] = bytes;
            completer.complete(bytes);
          } catch (e) {
            debugPrint('Could not decode IndexedDB value for $petId: $e');
            completer.complete(null);
          }
        } else {
          completer.complete(null);
        }
      }).toJS;

      request.onerror = ((web.Event _) {
        debugPrint('IndexedDB get error for $petId');
        if (!completer.isCompleted) completer.complete(null);
      }).toJS;

      return await completer.future;
    } catch (e) {
      debugPrint('Error getting web pet image for $petId: $e');
      return null;
    }
  }

  @override
  ImageProvider? getPetImageProvider({String? petId, String? fallbackUrl}) {
    if (petId != null && petId.isNotEmpty) {
      _checkUserChanged();
      final bytes = _bytesCache[petId];
      if (bytes != null && bytes.isNotEmpty) {
        return MemoryImage(bytes);
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
    return _bytesCache.containsKey(petId);
  }
}
