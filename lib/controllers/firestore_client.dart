import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Shared Firestore REST API client used by all feature services.
///
/// This avoids duplicating authentication, HTTP headers, and field-parsing
/// logic across feeding, routine, medicine, and health services.
class FirestoreClient {
  static const String _baseUrl =
      'https://firestore.googleapis.com/v1/projects/'
      'pawpulse-17842/databases/(default)/documents';

  static const String _queryUrl =
      'https://firestore.googleapis.com/v1/projects/'
      'pawpulse-17842/databases/(default)/documents:runQuery';

  // ─── Authentication ───────────────────────────────────────────────────────

  /// Returns HTTP headers with the current user's Firebase ID token.
  static Future<Map<String, String>> getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('You must be logged in to continue.');
    final idToken = await user.getIdToken();
    if (idToken == null) throw Exception('Unable to retrieve your ID token.');
    return {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  /// Returns the current user's UID. Throws if not logged in.
  static String get currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('You must be logged in to continue.');
    return user.uid;
  }

  // ─── Field helpers ────────────────────────────────────────────────────────

  /// Converts a Firestore typed field value to a plain Dart value.
  /// For example, {"stringValue": "Fluffy"} becomes "Fluffy".
  static dynamic readValue(dynamic field) {
    if (field is! Map<String, dynamic>) return null;
    if (field.containsKey('stringValue')) return field['stringValue'];
    if (field.containsKey('integerValue')) {
      return int.tryParse(field['integerValue'].toString()) ?? 0;
    }
    if (field.containsKey('doubleValue')) {
      return (field['doubleValue'] as num).toDouble();
    }
    if (field.containsKey('booleanValue')) return field['booleanValue'];
    return null;
  }

  /// Encodes a plain Dart value map to Firestore-typed fields.
  /// Supports String, bool, int, and double values.
  static Map<String, dynamic> encodeFields(Map<String, dynamic> values) {
    return values.map((key, value) {
      // Check bool before int because both respond to `is num` in some contexts.
      if (value is bool) return MapEntry(key, {'booleanValue': value});
      if (value is int) return MapEntry(key, {'integerValue': value.toString()});
      if (value is double) return MapEntry(key, {'doubleValue': value});
      return MapEntry(key, {'stringValue': value?.toString() ?? ''});
    });
  }

  // ─── ID and date helpers ──────────────────────────────────────────────────

  /// Generates a unique Firestore document ID based on the current timestamp.
  static String generateId(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}';

  /// Returns today's local date as a YYYY-MM-DD string.
  static String todayDateString() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns the current local time as an ISO 8601 string.
  static String nowTimestamp() => DateTime.now().toIso8601String();

  // ─── Firestore CRUD operations ────────────────────────────────────────────

  /// Queries a collection for all documents belonging to the current user.
  ///
  /// Uses the Firestore :runQuery endpoint with a structured query that
  /// filters by userId. Returns a list of plain Dart maps, each with an
  /// added 'id' key containing the Firestore document ID.
  static Future<List<Map<String, dynamic>>> queryByUser(
    String collectionId,
  ) async {
    final userId = currentUserId;

    final response = await http.post(
      Uri.parse(_queryUrl),
      headers: await getHeaders(),
      body: jsonEncode({
        'structuredQuery': {
          'from': [
            {'collectionId': collectionId},
          ],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'userId'},
              'op': 'EQUAL',
              'value': {'stringValue': userId},
            },
          },
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Query failed (${response.statusCode}): ${response.body}',
      );
    }

    final results = jsonDecode(response.body) as List<dynamic>;
    final docs = <Map<String, dynamic>>[];

    for (final result in results) {
      final entry = result as Map<String, dynamic>;

      // The last element in the response is a plain {readTime: ...} with no
      // document. Skip any entry that does not contain a document.
      if (!entry.containsKey('document')) continue;

      final doc = entry['document'] as Map<String, dynamic>;
      final docId = (doc['name'] as String).split('/').last;
      final rawFields = doc['fields'] as Map<String, dynamic>? ?? {};

      // Parse each Firestore-typed field to a plain Dart value.
      final parsed = <String, dynamic>{'id': docId};
      rawFields.forEach((key, value) {
        parsed[key] = readValue(value);
      });

      docs.add(parsed);
    }

    return docs;
  }

  /// Creates or fully replaces a Firestore document (PATCH without updateMask).
  ///
  /// Use this when creating a new record or replacing all fields.
  static Future<void> setDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> firestoreFields,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/$collection/${Uri.encodeComponent(documentId)}',
    );

    final response = await http.patch(
      uri,
      headers: await getHeaders(),
      body: jsonEncode({'fields': firestoreFields}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Write failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Updates only the specified fields in a document (PATCH with updateMask).
  ///
  /// Use this for partial updates such as toggling completion status,
  /// so that unrelated fields are not accidentally overwritten.
  static Future<void> updateFields({
    required String collection,
    required String documentId,
    required Map<String, dynamic> firestoreFields,
  }) async {
    // Build the updateMask query string so Firestore only touches these fields.
    final maskParams = firestoreFields.keys
        .map((f) => 'updateMask.fieldPaths=${Uri.encodeComponent(f)}')
        .join('&');

    final uri = Uri.parse(
      '$_baseUrl/$collection/${Uri.encodeComponent(documentId)}?$maskParams',
    );

    final response = await http.patch(
      uri,
      headers: await getHeaders(),
      body: jsonEncode({'fields': firestoreFields}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Update failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Permanently deletes a document from Firestore.
  static Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/$collection/${Uri.encodeComponent(documentId)}',
    );

    final response = await http.delete(
      uri,
      headers: await getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Delete failed (${response.statusCode}): ${response.body}',
      );
    }
  }
}

