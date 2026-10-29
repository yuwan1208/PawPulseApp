import '../controllers/firestore_client.dart';

/// Firestore collection name for medicine schedule records.
const String kMedicineCollection = 'medicine_schedules';

/// Represents one specific medicine dose in the Firestore medicine_schedules collection.
///
/// IMPORTANT: Each document is a single dose on a single date.
/// To track a 7-day course, create 7 separate documents.
/// This means marking one dose as administered never affects any other dose.
///
/// Fields stored in Firestore:
///   petId, userId, medicineName, dosage, instructions,
///   scheduledDate (YYYY-MM-DD), scheduledTime (HH:mm),
///   startDate, endDate (optional), notes,
///   isAdministered, createdAt, updatedAt
class MedicineRecord {
  final String id;
  final String petId;
  final String userId;
  final String medicineName;
  final String dosage;          // e.g. "5ml", "1 tablet" — entered by user
  final String instructions;    // e.g. "Give with food"
  final String scheduledDate;   // YYYY-MM-DD — the date this specific dose is due
  final String scheduledTime;   // HH:mm
  final String startDate;       // First day of the treatment course
  final String endDate;         // Optional last day; empty if ongoing
  final String notes;
  final bool isAdministered;    // True only when the user marks THIS dose as given
  final String createdAt;
  final String updatedAt;

  const MedicineRecord({
    required this.id,
    required this.petId,
    required this.userId,
    required this.medicineName,
    required this.dosage,
    required this.instructions,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.startDate,
    required this.endDate,
    required this.notes,
    required this.isAdministered,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a new MedicineRecord with a generated ID and current timestamps.
  factory MedicineRecord.create({
    required String petId,
    required String userId,
    required String medicineName,
    required String dosage,
    required String instructions,
    required String scheduledDate,
    required String scheduledTime,
    required String startDate,
    String endDate = '',
    String notes = '',
  }) {
    final now = FirestoreClient.nowTimestamp();
    return MedicineRecord(
      id: FirestoreClient.generateId('medicine'),
      petId: petId,
      userId: userId,
      medicineName: medicineName,
      dosage: dosage,
      instructions: instructions,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
      isAdministered: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Parses a MedicineRecord from a plain-Dart map returned by FirestoreClient.
  factory MedicineRecord.fromFirestoreMap(Map<String, dynamic> map) {
    return MedicineRecord(
      id: map['id'] as String? ?? '',
      petId: map['petId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      medicineName: map['medicineName'] as String? ?? '',
      dosage: map['dosage'] as String? ?? '',
      instructions: map['instructions'] as String? ?? '',
      scheduledDate: map['scheduledDate'] as String? ?? '',
      scheduledTime: map['scheduledTime'] as String? ?? '',
      startDate: map['startDate'] as String? ?? '',
      endDate: map['endDate'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      isAdministered: map['isAdministered'] as bool? ?? false,
      createdAt: map['createdAt'] as String? ?? '',
      updatedAt: map['updatedAt'] as String? ?? '',
    );
  }

  /// Converts this record to Firestore-typed fields ready for writing.
  Map<String, dynamic> toFirestoreFields() {
    return FirestoreClient.encodeFields({
      'petId': petId,
      'userId': userId,
      'medicineName': medicineName,
      'dosage': dosage,
      'instructions': instructions,
      'scheduledDate': scheduledDate,
      'scheduledTime': scheduledTime,
      'startDate': startDate,
      'endDate': endDate,
      'notes': notes,
      'isAdministered': isAdministered,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  }

  /// Returns a copy with selected fields updated. updatedAt is refreshed.
  MedicineRecord copyWith({
    String? medicineName,
    String? dosage,
    String? instructions,
    String? scheduledDate,
    String? scheduledTime,
    String? startDate,
    String? endDate,
    String? notes,
    bool? isAdministered,
  }) {
    return MedicineRecord(
      id: id,
      petId: petId,
      userId: userId,
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      instructions: instructions ?? this.instructions,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      isAdministered: isAdministered ?? this.isAdministered,
      createdAt: createdAt,
      updatedAt: FirestoreClient.nowTimestamp(),
    );
  }
}

