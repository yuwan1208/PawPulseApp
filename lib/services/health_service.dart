import '../controllers/firestore_client.dart';
import '../models/health_record_model.dart';

/// Handles all Firestore operations for health history records.
///
/// Health records capture appointments, vaccinations, checkups, and treatments.
/// Status can be marked completed or pending for consistent tracking.
class HealthService {
  /// Retrieves all health records for a specific pet, sorted newest-first.
  Future<List<HealthRecord>> getHealthRecords(String petId) async {
    final docs = await FirestoreClient.queryByUser(kHealthCollection);

    final records = docs
        .where((d) => d['petId'] == petId)
        .map(HealthRecord.fromFirestoreMap)
        .toList();

    // Sort by recordDate descending so the most recent event appears first.
    records.sort((a, b) => b.recordDate.compareTo(a.recordDate));

    return records;
  }

  /// Returns health records for the given pet that are scheduled for today.
  ///
  /// This is used in the pet overview to highlight any events scheduled or recorded today.
  Future<List<HealthRecord>> getTodayHealthRecords(String petId) async {
    final today = FirestoreClient.todayDateString();
    final all = await getHealthRecords(petId);
    return all.where((h) => h.recordDate == today).toList();
  }

  /// Saves a new health record to Firestore.
  Future<void> addHealthRecord(HealthRecord record) async {
    await FirestoreClient.setDocument(
      collection: kHealthCollection,
      documentId: record.id,
      firestoreFields: record.toFirestoreFields(),
    );
  }

  /// Replaces all fields of an existing health record in Firestore.
  Future<void> updateHealthRecord(HealthRecord record) async {
    final updated = record.copyWith();
    await FirestoreClient.setDocument(
      collection: kHealthCollection,
      documentId: updated.id,
      firestoreFields: updated.toFirestoreFields(),
    );
  }

  /// Marks a specific health record as completed or pending.
  ///
  /// Only isCompleted and updatedAt are changed. Other fields remain untouched.
  Future<void> setCompleted(String docId, bool isCompleted) async {
    await FirestoreClient.updateFields(
      collection: kHealthCollection,
      documentId: docId,
      firestoreFields: FirestoreClient.encodeFields({
        'isCompleted': isCompleted,
        'updatedAt': FirestoreClient.nowTimestamp(),
      }),
    );
  }

  /// Permanently deletes a health record from Firestore.
  Future<void> deleteHealthRecord(String docId) async {
    await FirestoreClient.deleteDocument(
      collection: kHealthCollection,
      documentId: docId,
    );
  }
}
