import '../controllers/firestore_client.dart';
import '../models/feeding_model.dart';

/// Handles all Firestore operations for feeding schedule records.
///
/// All methods automatically use the current user's UID for ownership checks.
/// Records are always filtered by petId in memory after being retrieved by userId,
/// ensuring one pet's feedings never appear under another pet.
class FeedingService {
  /// Retrieves all feeding records for a specific pet, sorted by date and time.
  Future<List<FeedingRecord>> getFeedings(String petId) async {
    final docs = await FirestoreClient.queryByUser(kFeedingCollection);

    final records = docs
        .where((d) => d['petId'] == petId)
        .map(FeedingRecord.fromFirestoreMap)
        .toList();

    // Sort chronologically so the earliest scheduled feeding appears first.
    records.sort((a, b) {
      final dateCompare = a.scheduledDate.compareTo(b.scheduledDate);
      if (dateCompare != 0) return dateCompare;
      return a.scheduledTime.compareTo(b.scheduledTime);
    });

    return records;
  }

  /// Retrieves only the feedings scheduled for today for a specific pet.
  /// Today's date is determined by the device's local clock.
  Future<List<FeedingRecord>> getTodayFeedings(String petId) async {
    final today = FirestoreClient.todayDateString();
    final all = await getFeedings(petId);
    return all.where((f) => f.scheduledDate == today).toList();
  }

  /// Saves a new feeding record to Firestore.
  /// The record's ID and timestamps must already be set (use FeedingRecord.create).
  Future<void> addFeeding(FeedingRecord record) async {
    await FirestoreClient.setDocument(
      collection: kFeedingCollection,
      documentId: record.id,
      firestoreFields: record.toFirestoreFields(),
    );
  }

  /// Replaces all fields of an existing feeding record in Firestore.
  Future<void> updateFeeding(FeedingRecord record) async {
    // copyWith refreshes updatedAt automatically.
    final updated = record.copyWith();
    await FirestoreClient.setDocument(
      collection: kFeedingCollection,
      documentId: updated.id,
      firestoreFields: updated.toFirestoreFields(),
    );
  }

  /// Marks a specific feeding as completed or undoes the completion.
  ///
  /// Only the isCompleted and updatedAt fields are changed in Firestore.
  /// All other fields on the document remain untouched.
  Future<void> setCompleted(String docId, bool isCompleted) async {
    await FirestoreClient.updateFields(
      collection: kFeedingCollection,
      documentId: docId,
      firestoreFields: FirestoreClient.encodeFields({
        'isCompleted': isCompleted,
        'updatedAt': FirestoreClient.nowTimestamp(),
      }),
    );
  }

  /// Permanently deletes a feeding record from Firestore.
  Future<void> deleteFeeding(String docId) async {
    await FirestoreClient.deleteDocument(
      collection: kFeedingCollection,
      documentId: docId,
    );
  }
}

