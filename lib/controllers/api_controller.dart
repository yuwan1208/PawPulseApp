
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../services/user_pets.dart';

class ApiController {
  static const String _baseUrl =
      'https://firestore.googleapis.com/v1/projects/'
      'pawpulse-17842/databases/(default)/documents';

  String errorMessage = '';

  // Get the currently logged-in user's authentication headers.
  Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in first.');
    }

    final idToken = await user.getIdToken();

    if (idToken == null) {
      throw Exception('Unable to get your Firebase ID token.');
    }

    return {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // GET: Retrieve all pets from Firestore.
  Future<UsersPets> getDataFromAPI() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/pets'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'GET failed (${response.statusCode}): ${response.body}',
        );
      }

      final responseJson =
          jsonDecode(response.body) as Map<String, dynamic>;

      final documents =
          responseJson['documents'] as List<dynamic>? ?? [];

      final pets = documents.map((document) {
        final doc = document as Map<String, dynamic>;
        final fields =
            doc['fields'] as Map<String, dynamic>? ?? {};

        return <String, dynamic>{
          'id': doc['name'].toString().split('/').last,
          'name': _readValue(fields['name']) ?? '',
          'species': _readValue(fields['species']) ?? '',
          'breed': _readValue(fields['breed']) ?? '',
          'ageYears': _readValue(fields['ageYears']) ?? 0,
          'weightKg': _readValue(fields['weightKg']) ?? 0.0,
          'gender': _readValue(fields['gender']) ?? '',
          'avatarUrl': _readValue(fields['avatarUrl']) ?? '',
          'isFriendly': _readValue(fields['isFriendly']) ?? false,
        };
      }).toList();

      final modelJson = jsonEncode({
        'data': {
          'user': {
            'displayName':
                FirebaseAuth.instance.currentUser?.displayName ??
                    'Pet Owner',
          },
          'pets': pets,
        },
      });

      errorMessage = '';
      return usersPetsFromJson(modelJson);
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    }
  }

  // POST: Add a new pet to Firestore.
  Future<String> addPet({
    required String name,
    required String species,
    required String breed,
    required int ageYears,
    required double weightKg,
    required String gender,
    String avatarUrl = '',
    bool isFriendly = false,
    bool isVaccinated = false,
  }) async {
    try {
      final documentId =
          'pet_${DateTime.now().millisecondsSinceEpoch}';

      final uri = Uri.parse('$_baseUrl/pets').replace(
        queryParameters: {'documentId': documentId},
      );

      final response = await http.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({
          'fields': _encodeFields(
            name: name,
            species: species,
            breed: breed,
            ageYears: ageYears,
            weightKg: weightKg,
            gender: gender,
            avatarUrl: avatarUrl,
            isFriendly: isFriendly,
            isVaccinated: isVaccinated,
          ),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'POST failed (${response.statusCode}): ${response.body}',
        );
      }

      errorMessage = '';
      return documentId;
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    }
  }

  // PATCH: Update an existing pet in Firestore.
  // Firestore's REST API uses PATCH for document updates.
  Future<void> updatePet({
    required String documentId,
    required String name,
    required String species,
    required String breed,
    required int ageYears,
    required double weightKg,
    required String gender,
    String avatarUrl = '',
    bool isFriendly = false,
    bool isVaccinated = false,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/pets/${Uri.encodeComponent(documentId)}',
      );

      final response = await http.patch(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({
          'fields': _encodeFields(
            name: name,
            species: species,
            breed: breed,
            ageYears: ageYears,
            weightKg: weightKg,
            gender: gender,
            avatarUrl: avatarUrl,
            isFriendly: isFriendly,
            isVaccinated: isVaccinated,
          ),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'PATCH failed (${response.statusCode}): ${response.body}',
        );
      }

      errorMessage = '';
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    }
  }

  // DELETE: Remove a pet from Firestore.
  Future<void> deletePet(String documentId) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/pets/${Uri.encodeComponent(documentId)}',
      );

      final response = await http.delete(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'DELETE failed (${response.statusCode}): ${response.body}',
        );
      }

      errorMessage = '';
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    }
  }

  // Convert normal Dart values to Firestore REST field values.
  Map<String, dynamic> _encodeFields({
    required String name,
    required String species,
    required String breed,
    required int ageYears,
    required double weightKg,
    required String gender,
    required String avatarUrl,
    required bool isFriendly,
    required bool isVaccinated,
  }) {
    return {
      'name': {'stringValue': name},
      'species': {'stringValue': species},
      'breed': {'stringValue': breed},
      'ageYears': {'integerValue': ageYears.toString()},
      'weightKg': {'doubleValue': weightKg},
      'gender': {'stringValue': gender},
      'avatarUrl': {'stringValue': avatarUrl},
      'isFriendly': {'booleanValue': isFriendly},
      'isVaccinated': {'booleanValue': isVaccinated},
    };
  }

  // Read typed Firestore values as normal Dart values.
  dynamic _readValue(dynamic field) {
    if (field is! Map<String, dynamic>) {
      return null;
    }

    if (field.containsKey('stringValue')) {
      return field['stringValue'];
    }

    if (field.containsKey('integerValue')) {
      return int.tryParse(field['integerValue'].toString()) ?? 0;
    }

    if (field.containsKey('doubleValue')) {
      return (field['doubleValue'] as num).toDouble();
    }

    if (field.containsKey('booleanValue')) {
      return field['booleanValue'];
    }

    return null;
  }
}
