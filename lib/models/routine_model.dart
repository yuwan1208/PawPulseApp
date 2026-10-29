import '../controllers/firestore_client.dart';

/// Firestore collection name for routine schedule records.
const String kRoutineCollection = 'routine_schedules';

/// Supported activity type values.
/// Use these constants when creating or filtering routines.
class ActivityType {
  static const String walking = 'walking';
  static const String bathing = 'bathing';
  static const String grooming = 'grooming';
  static const String exercise = 'exercise';
  static const String custom = 'custom';

  /// All built-in activity types for display in a dropdown or picker.
  static const List<String> all = [
    walking,
    bathing,
    grooming,
    exercise,
    custom,
  ];

  /// Returns a human-readable label for a given activity type value.
  static String label(String type) {
    switch (type) {
      case walking:
        return 'Walking';
      case bathing:
        return 'Bathing';
      case grooming:
        return 'Grooming';
      case exercise:
        return 'Exercise';
      default:
        return 'Custom';
    }
  }
}

/// Represents a single routine entry in the Firestore routine_schedules collection.
///
/// Each document is one scheduled activity for one pet on one date.
/// Example fields: petId, userId, activityType, activityName,
///   scheduledDate (YYYY-MM-DD), scheduledTime (HH:mm),
///   notes, isCompleted, createdAt, updatedAt
class RoutineRecord {
  final String id;
  final String petId;
  final String userId;
  final String activityType;   // walking | bathing | grooming | exercise | custom
  final String activityName;   // user-visible name, e.g. "Morning Walk"
  final String scheduledDate;  // YYYY-MM-DD
  final String scheduledTime;  // HH:mm
  final String notes;
  final bool isCompleted;
  final String createdAt;
  final String updatedAt;

  const RoutineRecord({
    required this.id,
    required this.petId,
    required this.userId,
    required this.activityType,
    required this.activityName,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.notes,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a new RoutineRecord with a generated ID and current timestamps.
  factory RoutineRecord.create({
    required String petId,
    required String userId,
    required String activityType,
    required String activityName,
    required String scheduledDate,
    required String scheduledTime,
    String notes = '',
  }) {
    final now = FirestoreClient.nowTimestamp();
    return RoutineRecord(
      id: FirestoreClient.generateId('routine'),
      petId: petId,
      userId: userId,
      activityType: activityType,
      activityName: activityName,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      notes: notes,
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Parses a RoutineRecord from a plain-Dart map returned by FirestoreClient.
  factory RoutineRecord.fromFirestoreMap(Map<String, dynamic> map) {
    return RoutineRecord(
      id: map['id'] as String? ?? '',
      petId: map['petId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      activityType: map['activityType'] as String? ?? ActivityType.custom,
      activityName: map['activityName'] as String? ?? '',
      scheduledDate: map['scheduledDate'] as String? ?? '',
      scheduledTime: map['scheduledTime'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt: map['createdAt'] as String? ?? '',
      updatedAt: map['updatedAt'] as String? ?? '',
    );
  }

  /// Converts this record to Firestore-typed fields ready for writing.
  Map<String, dynamic> toFirestoreFields() {
    return FirestoreClient.encodeFields({
      'petId': petId,
      'userId': userId,
      'activityType': activityType,
      'activityName': activityName,
      'scheduledDate': scheduledDate,
      'scheduledTime': scheduledTime,
      'notes': notes,
      'isCompleted': isCompleted,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  }

  /// Returns a copy with selected fields updated. updatedAt is refreshed.
  RoutineRecord copyWith({
    String? activityType,
    String? activityName,
    String? scheduledDate,
    String? scheduledTime,
    String? notes,
    bool? isCompleted,
  }) {
    return RoutineRecord(
      id: id,
      petId: petId,
      userId: userId,
      activityType: activityType ?? this.activityType,
      activityName: activityName ?? this.activityName,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      updatedAt: FirestoreClient.nowTimestamp(),
    );
  }
}

