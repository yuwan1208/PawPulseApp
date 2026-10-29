import '../controllers/firestore_client.dart';

/// Firestore collection name for feeding schedule records.
const String kFeedingCollection = 'feeding_schedules';

/// Represents a single feeding entry in the Firestore feeding_schedules collection.
///
/// Each document maps to one feeding event for one pet on one date.
/// Example Firestore fields:
///   petId, userId, mealName, amount, scheduledDate (YYYY-MM-DD),
///   scheduledTime (HH:mm), notes, isCompleted, createdAt, updatedAt
class FeedingRecord {
  final String id;           // Firestore document ID
  final String petId;        // Links this record to a specific pet
  final String userId;       // Firebase Auth UID of the owner
  final String mealName;     // e.g. "Breakfast", "Kibble"
  final String amount;       // e.g. "1 cup", "200g"
  final String scheduledDate; // YYYY-MM-DD
  final String scheduledTime; // HH:mm (24-hour)
  final String notes;
  final bool isCompleted;
  final String createdAt;    // ISO 8601 timestamp
  final String updatedAt;    // ISO 8601 timestamp

  const FeedingRecord({
    required this.id,
    required this.petId,
    required this.userId,
    required this.mealName,
    required this.amount,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.notes,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a brand-new FeedingRecord with a generated ID and current timestamps.
  /// Call this when the user taps "Save" on the Add Feeding form.
  factory FeedingRecord.create({
    required String petId,
    required String userId,
    required String mealName,
    required String amount,
    required String scheduledDate,
    required String scheduledTime,
    String notes = '',
  }) {
    final now = FirestoreClient.nowTimestamp();
    return FeedingRecord(
      id: FirestoreClient.generateId('feeding'),
      petId: petId,
      userId: userId,
      mealName: mealName,
      amount: amount,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      notes: notes,
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Parses a FeedingRecord from the map returned by FirestoreClient.queryByUser().
  /// All field values in the map are already plain Dart types (String, bool, etc.).
  factory FeedingRecord.fromFirestoreMap(Map<String, dynamic> map) {
    return FeedingRecord(
      id: map['id'] as String? ?? '',
      petId: map['petId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      mealName: map['mealName'] as String? ?? '',
      amount: map['amount'] as String? ?? '',
      scheduledDate: map['scheduledDate'] as String? ?? '',
      scheduledTime: map['scheduledTime'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt: map['createdAt'] as String? ?? '',
      updatedAt: map['updatedAt'] as String? ?? '',
    );
  }

  /// Converts this record to Firestore-typed fields ready for PATCH/POST.
  Map<String, dynamic> toFirestoreFields() {
    return FirestoreClient.encodeFields({
      'petId': petId,
      'userId': userId,
      'mealName': mealName,
      'amount': amount,
      'scheduledDate': scheduledDate,
      'scheduledTime': scheduledTime,
      'notes': notes,
      'isCompleted': isCompleted,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  }

  /// Returns a copy of this record with the given fields changed.
  /// updatedAt is automatically refreshed.
  FeedingRecord copyWith({
    String? mealName,
    String? amount,
    String? scheduledDate,
    String? scheduledTime,
    String? notes,
    bool? isCompleted,
  }) {
    return FeedingRecord(
      id: id,
      petId: petId,
      userId: userId,
      mealName: mealName ?? this.mealName,
      amount: amount ?? this.amount,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      updatedAt: FirestoreClient.nowTimestamp(),
    );
  }
}

