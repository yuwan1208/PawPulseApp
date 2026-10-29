import 'package:flutter/material.dart';

import '../controllers/api_controller.dart';
import '../controllers/firestore_client.dart';
import '../models/feeding_model.dart';
import '../models/health_record_model.dart';
import '../models/medicine_model.dart';
import '../models/routine_model.dart';
import '../services/feeding_service.dart';
import '../services/medicine_service.dart';
import '../services/routine_service.dart';
import '../services/user_pets.dart';

const Color kTurquoise = Color.fromARGB(255, 37, 214, 199);

/// Today's Pet Care Overview across ALL pet profiles.
///
/// Displays all feedings, routines, medicines, and health events scheduled for
/// today across all pets, with filter chips to view a specific pet or all pets.
class AllPetsOverviewPage extends StatefulWidget {
  final List<Datum>? pets;

  const AllPetsOverviewPage({super.key, this.pets});

  @override
  State<AllPetsOverviewPage> createState() => _AllPetsOverviewPageState();
}

class _AllPetsOverviewPageState extends State<AllPetsOverviewPage> {
  final _feedingService = FeedingService();
  final _routineService = RoutineService();
  final _medicineService = MedicineService();

  List<Datum> _pets = [];
  String _selectedPetId = 'all'; // 'all' or specific pet ID

  List<FeedingRecord> _allFeedings = [];
  List<RoutineRecord> _allRoutines = [];
  List<MedicineRecord> _allMedicines = [];
  List<HealthRecord> _allHealth = [];

  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _pets = widget.pets ?? [];
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // If pets were not passed, fetch them
      if (_pets.isEmpty) {
        final petsResult = await ApiController().getDataFromAPI();
        _pets = petsResult.data;
      }

      final today = FirestoreClient.todayDateString();

      // Query all collections for the current user
      final feedingDocs =
          await FirestoreClient.queryByUser(kFeedingCollection);
      final routineDocs =
          await FirestoreClient.queryByUser(kRoutineCollection);
      final medicineDocs =
          await FirestoreClient.queryByUser(kMedicineCollection);
      final healthDocs =
          await FirestoreClient.queryByUser(kHealthCollection);

      // Filter to today's records
      final feedings = feedingDocs
          .map(FeedingRecord.fromFirestoreMap)
          .where((f) => f.scheduledDate == today)
          .toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

      final routines = routineDocs
          .map(RoutineRecord.fromFirestoreMap)
          .where((r) => r.scheduledDate == today)
          .toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

      final medicines = medicineDocs
          .map(MedicineRecord.fromFirestoreMap)
          .where((m) => m.scheduledDate == today)
          .toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

      final health = healthDocs
          .map(HealthRecord.fromFirestoreMap)
          .where((h) => h.recordDate == today)
          .toList();

      if (!mounted) return;
      setState(() {
        _allFeedings = feedings;
        _allRoutines = routines;
        _allMedicines = medicines;
        _allHealth = health;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // ─── Filtered Getters ──────────────────────────────────────────────────────

  List<FeedingRecord> get _filteredFeedings {
    if (_selectedPetId == 'all') return _allFeedings;
    return _allFeedings.where((f) => f.petId == _selectedPetId).toList();
  }

  List<RoutineRecord> get _filteredRoutines {
    if (_selectedPetId == 'all') return _allRoutines;
    return _allRoutines.where((r) => r.petId == _selectedPetId).toList();
  }

  List<MedicineRecord> get _filteredMedicines {
    if (_selectedPetId == 'all') return _allMedicines;
    return _allMedicines.where((m) => m.petId == _selectedPetId).toList();
  }

  List<HealthRecord> get _filteredHealth {
    if (_selectedPetId == 'all') return _allHealth;
    return _allHealth.where((h) => h.petId == _selectedPetId).toList();
  }

  int get _totalTasks =>
      _filteredFeedings.length +
      _filteredRoutines.length +
      _filteredMedicines.length +
      _filteredHealth.length;

  int get _completedTasks {
    final doneFeed = _filteredFeedings.where((f) => f.isCompleted).length;
    final doneRoutine = _filteredRoutines.where((r) => r.isCompleted).length;
    final doneMed =
        _filteredMedicines.where((m) => m.isAdministered).length;
    return doneFeed + doneRoutine + doneMed + _filteredHealth.length;
  }

  // ─── Pet Name & Image Helper ───────────────────────────────────────────────

  Datum? _findPet(String petId) {
    for (final p in _pets) {
      if (p.id == petId) return p;
    }
    return null;
  }

  String _getPetName(String petId) {
    final pet = _findPet(petId);
    return pet?.petName ?? 'Pet';
  }

  ImageProvider? _getPetImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return NetworkImage(imagePath);
    }
    return AssetImage(imagePath);
  }

  // ─── Toggles ───────────────────────────────────────────────────────────────

  Future<void> _toggleFeeding(FeedingRecord record) async {
    try {
      await _feedingService.setCompleted(record.id, !record.isCompleted);
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update feeding: $e')),
      );
    }
  }

  Future<void> _toggleRoutine(RoutineRecord record) async {
    try {
      await _routineService.setCompleted(record.id, !record.isCompleted);
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update routine: $e')),
      );
    }
  }

  Future<void> _toggleMedicine(MedicineRecord record) async {
    try {
      await _medicineService.setAdministered(record.id, !record.isAdministered);
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update medicine: $e')),
      );
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kTurquoise,
        title: const Text('Today\'s Pet Care (All Pets)'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kTurquoise),
            )
          : _errorMessage.isNotEmpty
              ? _buildError()
              : RefreshIndicator(
                  color: kTurquoise,
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildPetFilterChips(),
                      const SizedBox(height: 16),
                      _buildProgressCard(),
                      const SizedBox(height: 16),
                      _buildFeedingSection(),
                      const SizedBox(height: 16),
                      _buildRoutineSection(),
                      const SizedBox(height: 16),
                      _buildMedicineSection(),
                      const SizedBox(height: 16),
                      _buildHealthSection(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  // ─── Pet Filter Chips ──────────────────────────────────────────────────────

  Widget _buildPetFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text('All Pets (${_pets.length})'),
            selected: _selectedPetId == 'all',
            selectedColor: kTurquoise,
            labelStyle: TextStyle(
              color: _selectedPetId == 'all' ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
            onSelected: (selected) {
              if (selected) setState(() => _selectedPetId = 'all');
            },
          ),
          const SizedBox(width: 8),
          ..._pets.map((pet) {
            final isSelected = _selectedPetId == pet.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: CircleAvatar(
                  backgroundImage: _getPetImage(pet.petImage),
                  child: pet.petImage.isEmpty
                      ? const Icon(Icons.pets, size: 14)
                      : null,
                ),
                label: Text(pet.petName),
                selected: isSelected,
                selectedColor: kTurquoise,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedPetId = pet.id);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Progress Card ─────────────────────────────────────────────────────────

  Widget _buildProgressCard() {
    final total = _totalTasks;
    final done = _completedTasks;
    final remaining = total - done;
    final progress = total == 0 ? 0.0 : done / total;

    final targetName = _selectedPetId == 'all'
        ? 'All Pets'
        : _getPetName(_selectedPetId);

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$targetName – Today\'s Progress',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kTurquoise,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                color: kTurquoise,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  total == 0
                      ? 'No tasks scheduled today'
                      : '$done / $total completed',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                if (remaining > 0)
                  Text(
                    '$remaining remaining',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Feeding Section ───────────────────────────────────────────────────────

  Widget _buildFeedingSection() {
    final feedings = _filteredFeedings;
    return _sectionContainer(
      icon: Icons.restaurant,
      title: 'Feedings Today (${feedings.length})',
      child: feedings.isEmpty
          ? _emptyText('No feedings scheduled today.')
          : Column(
              children: feedings.map((f) {
                final pet = _findPet(f.petId);
                return CheckboxListTile(
                  activeColor: kTurquoise,
                  value: f.isCompleted,
                  onChanged: (_) => _toggleFeeding(f),
                  title: Row(
                    children: [
                      Text(
                        f.mealName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration:
                              f.isCompleted ? TextDecoration.lineThrough : null,
                          color:
                              f.isCompleted ? Colors.black45 : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _petBadge(pet?.petName ?? 'Pet'),
                    ],
                  ),
                  subtitle: Text(
                    '${f.scheduledTime}${f.amount.isNotEmpty ? ' • ${f.amount}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }).toList(),
            ),
    );
  }

  // ─── Routine Section ───────────────────────────────────────────────────────

  Widget _buildRoutineSection() {
    final routines = _filteredRoutines;
    return _sectionContainer(
      icon: Icons.directions_walk,
      title: 'Routines Today (${routines.length})',
      child: routines.isEmpty
          ? _emptyText('No routines scheduled today.')
          : Column(
              children: routines.map((r) {
                final pet = _findPet(r.petId);
                return CheckboxListTile(
                  activeColor: kTurquoise,
                  value: r.isCompleted,
                  onChanged: (_) => _toggleRoutine(r),
                  title: Row(
                    children: [
                      Text(
                        r.activityName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration:
                              r.isCompleted ? TextDecoration.lineThrough : null,
                          color:
                              r.isCompleted ? Colors.black45 : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _petBadge(pet?.petName ?? 'Pet'),
                    ],
                  ),
                  subtitle: Text(
                    '${r.scheduledTime} • ${ActivityType.label(r.activityType)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }).toList(),
            ),
    );
  }

  // ─── Medicine Section ──────────────────────────────────────────────────────

  Widget _buildMedicineSection() {
    final medicines = _filteredMedicines;
    return _sectionContainer(
      icon: Icons.medical_services,
      title: 'Medicines Today (${medicines.length})',
      child: medicines.isEmpty
          ? _emptyText('No medicines scheduled today.')
          : Column(
              children: medicines.map((m) {
                final pet = _findPet(m.petId);
                return CheckboxListTile(
                  activeColor: kTurquoise,
                  value: m.isAdministered,
                  onChanged: (_) => _toggleMedicine(m),
                  title: Row(
                    children: [
                      Text(
                        m.medicineName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: m.isAdministered
                              ? TextDecoration.lineThrough
                              : null,
                          color: m.isAdministered
                              ? Colors.black45
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _petBadge(pet?.petName ?? 'Pet'),
                    ],
                  ),
                  subtitle: Text(
                    '${m.scheduledTime}${m.dosage.isNotEmpty ? ' • ${m.dosage}' : ''}'
                    '${m.instructions.isNotEmpty ? '\n${m.instructions}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: m.instructions.isNotEmpty,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }).toList(),
            ),
    );
  }

  // ─── Health Section ────────────────────────────────────────────────────────

  Widget _buildHealthSection() {
    final health = _filteredHealth;
    return _sectionContainer(
      icon: Icons.favorite,
      title: 'Health Events Today (${health.length})',
      child: health.isEmpty
          ? _emptyText('No health events recorded for today.')
          : Column(
              children: health.map((h) {
                final pet = _findPet(h.petId);
                return ListTile(
                  leading: const Icon(Icons.favorite, color: kTurquoise),
                  title: Row(
                    children: [
                      Text(
                        h.description.isNotEmpty
                            ? h.description
                            : HealthRecordType.label(h.recordType),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      _petBadge(pet?.petName ?? 'Pet'),
                    ],
                  ),
                  subtitle: Text(
                    '${HealthRecordType.label(h.recordType)}'
                    '${h.vetName.isNotEmpty ? ' • ${h.vetName}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionContainer({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: kTurquoise, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _petBadge(String petName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: kTurquoise.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        petName,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 12, 142, 131),
        ),
      ),
    );
  }

  Widget _emptyText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(text,
            style: const TextStyle(color: Colors.black45, fontSize: 13)),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            SelectableText(_errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
