import 'package:flutter/material.dart';

import '../models/feeding_model.dart';
import '../models/health_record_model.dart';
import '../models/medicine_model.dart';
import '../models/routine_model.dart';
import '../services/feeding_service.dart';
import '../services/health_service.dart';
import '../services/medicine_service.dart';
import '../services/routine_service.dart';
import '../services/user_pets.dart';
import 'feeding_schedule_page.dart';
import 'health_history_page.dart';
import 'medicine_schedule_page.dart';
import 'routine_schedule_page.dart';

const Color kTurquoise = Color.fromARGB(255, 37, 214, 199);

/// Shows an individual pet's daily overview:
///   - Pet profile (photo, name, species, breed, age, weight, gender)
///   - Today's scheduled feedings, routines, medicines, and health records
///   - A progress bar showing how many tasks are done today
///
/// This page does NOT mix data from other pets. Every record is filtered
/// by the selected pet's document ID before being displayed.
class PetDetailsPage extends StatefulWidget {
  final Datum pet;

  const PetDetailsPage({super.key, required this.pet});

  @override
  State<PetDetailsPage> createState() => _PetDetailsPageState();
}

class _PetDetailsPageState extends State<PetDetailsPage> {
  // Services — each one handles exactly one feature's Firestore operations.
  final _feedingService = FeedingService();
  final _routineService = RoutineService();
  final _medicineService = MedicineService();
  final _healthService = HealthService();

  // Today's records for this pet.
  List<FeedingRecord> _todayFeedings = [];
  List<RoutineRecord> _todayRoutines = [];
  List<MedicineRecord> _todayMedicines = [];
  List<HealthRecord> _todayHealth = [];

  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  // ─── Data loading ──────────────────────────────────────────────────────────

  /// Loads all of today's tasks for this pet in parallel for speed.
  Future<void> _loadTodayData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final results = await Future.wait([
        _feedingService.getTodayFeedings(widget.pet.id),
        _routineService.getTodayRoutines(widget.pet.id),
        _medicineService.getTodayMedicines(widget.pet.id),
        _healthService.getTodayHealthRecords(widget.pet.id),
      ]);

      if (!mounted) return;
      setState(() {
        _todayFeedings = results[0] as List<FeedingRecord>;
        _todayRoutines = results[1] as List<RoutineRecord>;
        _todayMedicines = results[2] as List<MedicineRecord>;
        _todayHealth = results[3] as List<HealthRecord>;
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

  // ─── Progress helpers ──────────────────────────────────────────────────────

  int get _totalTasks =>
      _todayFeedings.length +
      _todayRoutines.length +
      _todayMedicines.length +
      _todayHealth.length;

  int get _completedTasks {
    final doneFeed = _todayFeedings.where((f) => f.isCompleted).length;
    final doneRoutine = _todayRoutines.where((r) => r.isCompleted).length;
    final doneMed = _todayMedicines.where((m) => m.isAdministered).length;
    // Health records do not have a completion status — count them as "done."
    return doneFeed + doneRoutine + doneMed + _todayHealth.length;
  }

  // ─── Pet image helper ──────────────────────────────────────────────────────

  ImageProvider? _getPetImage(String imagePath) {
    if (imagePath.isEmpty) return null;
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return NetworkImage(imagePath);
    }
    return AssetImage(imagePath);
  }

  // ─── Completion toggles ────────────────────────────────────────────────────

  Future<void> _toggleFeeding(FeedingRecord record) async {
    try {
      await _feedingService.setCompleted(record.id, !record.isCompleted);
      await _loadTodayData();
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
      await _loadTodayData();
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
      await _loadTodayData();
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
    final pet = widget.pet;
    final petImage = _getPetImage(pet.petImage);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kTurquoise,
        title: Text(pet.petName),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodayData,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kTurquoise,
        onRefresh: _loadTodayData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileCard(pet, petImage),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: kTurquoise),
                ),
              )
            else if (_errorMessage.isNotEmpty)
              _buildErrorCard()
            else ...[
              _buildProgressCard(),
              const SizedBox(height: 16),
              _buildTodaySection(pet),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Profile card ──────────────────────────────────────────────────────────

  Widget _buildProfileCard(Datum pet, ImageProvider? petImage) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: kTurquoise,
              backgroundImage: petImage,
              child: petImage == null
                  ? const Icon(Icons.pets, size: 36, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.petName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _profileRow(Icons.category, pet.species),
                  _profileRow(Icons.pets, pet.breed),
                  _profileRow(Icons.cake, pet.age),
                  _profileRow(Icons.monitor_weight, pet.weight),
                  _profileRow(Icons.wc, pet.gender),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: kTurquoise),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── Progress card ─────────────────────────────────────────────────────────

  Widget _buildProgressCard() {
    final total = _totalTasks;
    final done = _completedTasks;
    final remaining = total - done;
    final progress = total == 0 ? 0.0 : done / total;

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Progress",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
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
                  style: const TextStyle(color: Colors.black54),
                ),
                if (remaining > 0)
                  Text(
                    '$remaining remaining',
                    style: const TextStyle(color: Colors.black54),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Error card ────────────────────────────────────────────────────────────

  Widget _buildErrorCard() {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            const Text('Could not load today\'s tasks.'),
            const SizedBox(height: 4),
            SelectableText(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadTodayData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: kTurquoise),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Today's section ───────────────────────────────────────────────────────

  Widget _buildTodaySection(Datum pet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Pet Care",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildFeedingSection(pet),
        const SizedBox(height: 12),
        _buildRoutineSection(pet),
        const SizedBox(height: 12),
        _buildMedicineSection(pet),
        const SizedBox(height: 12),
        _buildHealthSection(pet),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Feeding section ───────────────────────────────────────────────────────

  Widget _buildFeedingSection(Datum pet) {
    return _sectionCard(
      icon: Icons.restaurant,
      title: 'Feeding',
      onAdd: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FeedingSchedulePage(initialPet: pet),
          ),
        );
        await _loadTodayData();
      },
      child: _todayFeedings.isEmpty
          ? _emptyState('No feedings scheduled for today.')
          : Column(
              children: _todayFeedings
                  .map((f) => _feedingTile(f))
                  .toList(),
            ),
    );
  }

  Widget _feedingTile(FeedingRecord f) {
    return CheckboxListTile(
      activeColor: kTurquoise,
      value: f.isCompleted,
      onChanged: (_) => _toggleFeeding(f),
      title: Text(
        f.mealName,
        style: TextStyle(
          decoration: f.isCompleted ? TextDecoration.lineThrough : null,
          color: f.isCompleted ? Colors.black45 : Colors.black87,
        ),
      ),
      subtitle: Text(
        '${f.scheduledTime}${f.amount.isNotEmpty ? ' • ${f.amount}' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
      secondary: Icon(
        f.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
        color: f.isCompleted ? kTurquoise : Colors.grey,
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  // ─── Routine section ───────────────────────────────────────────────────────

  Widget _buildRoutineSection(Datum pet) {
    return _sectionCard(
      icon: Icons.directions_walk,
      title: 'Routine',
      onAdd: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoutineSchedulePage(initialPet: pet),
          ),
        );
        await _loadTodayData();
      },
      child: _todayRoutines.isEmpty
          ? _emptyState('No routines scheduled for today.')
          : Column(
              children: _todayRoutines
                  .map((r) => _routineTile(r))
                  .toList(),
            ),
    );
  }

  Widget _routineTile(RoutineRecord r) {
    return CheckboxListTile(
      activeColor: kTurquoise,
      value: r.isCompleted,
      onChanged: (_) => _toggleRoutine(r),
      title: Text(
        r.activityName,
        style: TextStyle(
          decoration: r.isCompleted ? TextDecoration.lineThrough : null,
          color: r.isCompleted ? Colors.black45 : Colors.black87,
        ),
      ),
      subtitle: Text(
        '${r.scheduledTime} • ${ActivityType.label(r.activityType)}',
        style: const TextStyle(fontSize: 12),
      ),
      secondary: Icon(
        r.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
        color: r.isCompleted ? kTurquoise : Colors.grey,
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  // ─── Medicine section ──────────────────────────────────────────────────────

  Widget _buildMedicineSection(Datum pet) {
    return _sectionCard(
      icon: Icons.medical_services,
      title: 'Medicine',
      onAdd: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MedicineSchedulePage(initialPet: pet),
          ),
        );
        await _loadTodayData();
      },
      child: _todayMedicines.isEmpty
          ? _emptyState('No medicines scheduled for today.')
          : Column(
              children: _todayMedicines
                  .map((m) => _medicineTile(m))
                  .toList(),
            ),
    );
  }

  Widget _medicineTile(MedicineRecord m) {
    return CheckboxListTile(
      activeColor: kTurquoise,
      value: m.isAdministered,
      onChanged: (_) => _toggleMedicine(m),
      title: Text(
        m.medicineName,
        style: TextStyle(
          decoration: m.isAdministered ? TextDecoration.lineThrough : null,
          color: m.isAdministered ? Colors.black45 : Colors.black87,
        ),
      ),
      subtitle: Text(
        '${m.scheduledTime}${m.dosage.isNotEmpty ? ' • ${m.dosage}' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
      secondary: Icon(
        m.isAdministered ? Icons.check_circle : Icons.radio_button_unchecked,
        color: m.isAdministered ? kTurquoise : Colors.grey,
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  // ─── Health section ────────────────────────────────────────────────────────

  Widget _buildHealthSection(Datum pet) {
    return _sectionCard(
      icon: Icons.favorite,
      title: 'Health',
      onAdd: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HealthHistoryPage(initialPet: pet),
          ),
        );
        await _loadTodayData();
      },
      child: _todayHealth.isEmpty
          ? _emptyState('No health events recorded for today.')
          : Column(
              children: _todayHealth
                  .map((h) => _healthTile(h))
                  .toList(),
            ),
    );
  }

  Widget _healthTile(HealthRecord h) {
    return ListTile(
      leading: const Icon(Icons.favorite, color: kTurquoise),
      title: Text(h.description.isNotEmpty ? h.description : HealthRecordType.label(h.recordType)),
      subtitle: Text(
        '${HealthRecordType.label(h.recordType)}'
        '${h.vetName.isNotEmpty ? ' • ${h.vetName}' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  // ─── Shared section card ───────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
    required VoidCallback onAdd,
  }) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(foregroundColor: kTurquoise),
                ),
              ],
            ),
            const Divider(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.black45),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

