import '../controllers/firestore_client.dart';
import '../models/routine_model.dart';

/// Handles all Firestore operations for routine schedule records.
///
/// Routines include walking, bathing, grooming, exercise, and custom activities.
/// Each document is one scheduled activity for one pet on one specific date.
class RoutineService {
  /// Retrieves all routine records for a specific pet, sorted by date and time.
  Future<List<RoutineRecord>> getRoutines(String petId) async {
    final docs = await FirestoreClient.queryByUser(kRoutineCollection);

    final records = docs
        .where((d) => d['petId'] == petId)
        .map(RoutineRecord.fromFirestoreMap)
        .toList();

    records.sort((a, b) {
      final dateCompare = a.scheduledDate.compareTo(b.scheduledDate);
      if (dateCompare != 0) return dateCompare;
      return a.scheduledTime.compareTo(b.scheduledTime);
    });

    return records;
  }

  /// Retrieves only the routines scheduled for today for a specific pet.
  Future<List<RoutineRecord>> getTodayRoutines(String petId) async {
    final today = FirestoreClient.todayDateString();
    final all = await getRoutines(petId);
    return all.where((r) => r.scheduledDate == today).toList();
  }

  /// Saves a new routine record to Firestore.
  Future<void> addRoutine(RoutineRecord record) async {
    await FirestoreClient.setDocument(
      collection: kRoutineCollection,
      documentId: record.id,
      firestoreFields: record.toFirestoreFields(),
    );
  }

  /// Replaces all fields of an existing routine record in Firestore.
  Future<void> updateRoutine(RoutineRecord record) async {
    final updated = record.copyWith();
    await FirestoreClient.setDocument(
      collection: kRoutineCollection,
      documentId: updated.id,
      firestoreFields: updated.toFirestoreFields(),
    );
  }

  /// Marks a specific routine as completed or undoes the completion.
  ///
  /// Only isCompleted and updatedAt are changed. Other fields are untouched.
  Future<void> setCompleted(String docId, bool isCompleted) async {
    await FirestoreClient.updateFields(
      collection: kRoutineCollection,
      documentId: docId,
      firestoreFields: FirestoreClient.encodeFields({
        'isCompleted': isCompleted,
        'updatedAt': FirestoreClient.nowTimestamp(),
      }),
    );
  }

  /// Permanently deletes a routine record from Firestore.
  Future<void> deleteRoutine(String docId) async {
    await FirestoreClient.deleteDocument(
      collection: kRoutineCollection,
      documentId: docId,
    );
  }
}

