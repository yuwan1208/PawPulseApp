import '../controllers/firestore_client.dart';

/// Firestore collection name for health history records.
const String kHealthCollection = 'health_records';

/// Supported health record type values.
class HealthRecordType {
  static const String vetVisit = 'vet_visit';
  static const String vaccination = 'vaccination';
  static const String checkup = 'checkup';
  static const String illness = 'illness';
  static const String treatment = 'treatment';
  static const String other = 'other';

  static const List<String> all = [
    vetVisit,
    vaccination,
    checkup,
    illness,
    treatment,
    other,
  ];

  /// Returns a human-readable label for a given record type value.
  static String label(String type) {
    switch (type) {
      case vetVisit:
        return 'Vet Visit';
      case vaccination:
        return 'Vaccination';
      case checkup:
        return 'Checkup';
      case illness:
        return 'Illness';
      case treatment:
        return 'Treatment';
      default:
        return 'Other';
    }
  }
}

/// Represents a single health event in the Firestore health_records collection.
///
/// Health records are historical — they capture what happened in the past.
/// They are NOT automatically turned into upcoming reminders.
/// The user decides to record an event; the app stores it as written.
///
/// Fields:
///   petId, userId, recordDate (YYYY-MM-DD), recordType,
///   vetName (optional), description, treatmentDetails (optional),
///   vaccinationDetails (optional), notes, createdAt, updatedAt
class HealthRecord {
  final String id;
  final String petId;
  final String userId;
  final String recordDate;         // YYYY-MM-DD — the date the event occurred
  final String recordType;         // vet_visit | vaccination | checkup | illness | treatment | other
  final String vetName;            // Optional clinic or vet name
  final String description;        // Summary of what happened
  final String treatmentDetails;   // Optional — what treatment was given
  final String vaccinationDetails; // Optional — vaccine name, batch, etc.
  final String notes;
  final String createdAt;
  final String updatedAt;

  const HealthRecord({
    required this.id,
    required this.petId,
    required this.userId,
    required this.recordDate,
    required this.recordType,
    required this.vetName,
    required this.description,
    required this.treatmentDetails,
    required this.vaccinationDetails,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a new HealthRecord with a generated ID and current timestamps.
  factory HealthRecord.create({
    required String petId,
    required String userId,
    required String recordDate,
    required String recordType,
    required String description,
    String vetName = '',
    String treatmentDetails = '',
    String vaccinationDetails = '',
    String notes = '',
  }) {
    final now = FirestoreClient.nowTimestamp();
    return HealthRecord(
      id: FirestoreClient.generateId('health'),
      petId: petId,
      userId: userId,
      recordDate: recordDate,
      recordType: recordType,
      vetName: vetName,
      description: description,
      treatmentDetails: treatmentDetails,
      vaccinationDetails: vaccinationDetails,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Parses a HealthRecord from a plain-Dart map returned by FirestoreClient.
  factory HealthRecord.fromFirestoreMap(Map<String, dynamic> map) {
    return HealthRecord(
      id: map['id'] as String? ?? '',
      petId: map['petId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      recordDate: map['recordDate'] as String? ?? '',
      recordType: map['recordType'] as String? ?? HealthRecordType.other,
      vetName: map['vetName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      treatmentDetails: map['treatmentDetails'] as String? ?? '',
      vaccinationDetails: map['vaccinationDetails'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt: map['createdAt'] as String? ?? '',
      updatedAt: map['updatedAt'] as String? ?? '',
    );
  }

  /// Converts this record to Firestore-typed fields ready for writing.
  Map<String, dynamic> toFirestoreFields() {
    return FirestoreClient.encodeFields({
      'petId': petId,
      'userId': userId,
      'recordDate': recordDate,
      'recordType': recordType,
      'vetName': vetName,
      'description': description,
      'treatmentDetails': treatmentDetails,
      'vaccinationDetails': vaccinationDetails,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  }

  /// Returns a copy with selected fields updated. updatedAt is refreshed.
  HealthRecord copyWith({
    String? recordDate,
    String? recordType,
    String? vetName,
    String? description,
    String? treatmentDetails,
    String? vaccinationDetails,
    String? notes,
  }) {
    return HealthRecord(
      id: id,
      petId: petId,
      userId: userId,
      recordDate: recordDate ?? this.recordDate,
      recordType: recordType ?? this.recordType,
      vetName: vetName ?? this.vetName,
      description: description ?? this.description,
      treatmentDetails: treatmentDetails ?? this.treatmentDetails,
      vaccinationDetails: vaccinationDetails ?? this.vaccinationDetails,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: FirestoreClient.nowTimestamp(),
    );
  }
}

