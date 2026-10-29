import '../controllers/firestore_client.dart';
import '../models/medicine_model.dart';

/// Handles all Firestore operations for medicine schedule records.
///
/// IMPORTANT DESIGN RULE:
/// Each document in medicine_schedules is exactly one dose on one date.
/// Marking a dose as administered only updates that one document.
/// Passing a scheduled time does NOT automatically mark the dose as given.
class MedicineService {
  /// Retrieves all medicine records for a specific pet, sorted by date and time.
  Future<List<MedicineRecord>> getMedicines(String petId) async {
    final docs = await FirestoreClient.queryByUser(kMedicineCollection);

    final records = docs
        .where((d) => d['petId'] == petId)
        .map(MedicineRecord.fromFirestoreMap)
        .toList();

    records.sort((a, b) {
      final dateCompare = a.scheduledDate.compareTo(b.scheduledDate);
      if (dateCompare != 0) return dateCompare;
      return a.scheduledTime.compareTo(b.scheduledTime);
    });

    return records;
  }

  /// Retrieves only the medicine doses scheduled for today for a specific pet.
  Future<List<MedicineRecord>> getTodayMedicines(String petId) async {
    final today = FirestoreClient.todayDateString();
    final all = await getMedicines(petId);
    return all.where((m) => m.scheduledDate == today).toList();
  }

  /// Saves a new medicine record to Firestore.
  Future<void> addMedicine(MedicineRecord record) async {
    await FirestoreClient.setDocument(
      collection: kMedicineCollection,
      documentId: record.id,
      firestoreFields: record.toFirestoreFields(),
    );
  }

  /// Replaces all fields of an existing medicine record in Firestore.
  Future<void> updateMedicine(MedicineRecord record) async {
    final updated = record.copyWith();
    await FirestoreClient.setDocument(
      collection: kMedicineCollection,
      documentId: updated.id,
      firestoreFields: updated.toFirestoreFields(),
    );
  }

  /// Marks a specific dose as administered or un-administered.
  ///
  /// Only isAdministered and updatedAt are changed.
  /// This NEVER affects any other dose document, regardless of the medicine name.
  Future<void> setAdministered(String docId, bool isAdministered) async {
    await FirestoreClient.updateFields(
      collection: kMedicineCollection,
      documentId: docId,
      firestoreFields: FirestoreClient.encodeFields({
        'isAdministered': isAdministered,
        'updatedAt': FirestoreClient.nowTimestamp(),
      }),
    );
  }

  /// Permanently deletes a medicine record from Firestore.
  Future<void> deleteMedicine(String docId) async {
    await FirestoreClient.deleteDocument(
      collection: kMedicineCollection,
      documentId: docId,
    );
  }
}

