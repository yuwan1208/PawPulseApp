import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../controllers/api_controller.dart';
import '../controllers/firestore_client.dart';
import '../models/medicine_model.dart';
import '../services/medicine_service.dart';
import '../services/user_pets.dart';
import '../theme/pawpulse_theme.dart';

/// Full Medicine Schedule page.
///
/// Displays medicine doses across all pet profiles with pet filter chips,
/// pet badges on cards, and pet selection when creating new doses.
class MedicineSchedulePage extends StatefulWidget {
  final Datum? initialPet;
  final bool isEmbedded;
  final List<Datum>? allPets;

  const MedicineSchedulePage({
    super.key,
    this.initialPet,
    this.isEmbedded = false,
    this.allPets,
  });

  @override
  State<MedicineSchedulePage> createState() => _MedicineSchedulePageState();
}

class _MedicineSchedulePageState extends State<MedicineSchedulePage> {
  final _service = MedicineService();

  List<MedicineRecord> _records = [];
  List<Datum> _pets = [];
  String _selectedFilterPetId = 'all';

  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _pets = widget.allPets ?? [];
    if (widget.initialPet != null) {
      _selectedFilterPetId = widget.initialPet!.id;
    }
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      if (_pets.isEmpty) {
        final petsResult = await ApiController().getDataFromAPI();
        _pets = petsResult.data;
      }

      List<MedicineRecord> records;
      final petId = widget.initialPet?.id;
      if (petId != null) {
        records = await _service.getMedicines(petId);
      } else {
        final docs = await FirestoreClient.queryByUser(kMedicineCollection);
        records = docs.map(MedicineRecord.fromFirestoreMap).toList();
        records.sort((a, b) {
          final d = a.scheduledDate.compareTo(b.scheduledDate);
          return d != 0 ? d : a.scheduledTime.compareTo(b.scheduledTime);
        });
      }
      if (!mounted) return;
      setState(() {
        _records = records;
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

  List<MedicineRecord> get _displayedRecords {
    if (widget.initialPet != null || _selectedFilterPetId == 'all') {
      return _records;
    }
    return _records.where((m) => m.petId == _selectedFilterPetId).toList();
  }

  String _getPetName(String petId) {
    for (final p in _pets) {
      if (p.id == petId) return p.petName;
    }
    return 'Pet';
  }

  ImageProvider? _getPetImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return NetworkImage(imagePath);
    }
    return AssetImage(imagePath);
  }

  // ─── Form ──────────────────────────────────────────────────────────────────

  Future<void> _showForm({MedicineRecord? existing}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    String formPetId = existing?.petId ??
        widget.initialPet?.id ??
        (_pets.isNotEmpty ? _pets.first.id : '');

    final nameController =
        TextEditingController(text: existing?.medicineName ?? '');
    final dosageController =
        TextEditingController(text: existing?.dosage ?? '');
    final instructionsController =
        TextEditingController(text: existing?.instructions ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');

    String selectedDate =
        existing?.scheduledDate ?? FirestoreClient.todayDateString();
    String selectedTime = existing?.scheduledTime ?? '08:00';
    String startDate = existing?.startDate ?? FirestoreClient.todayDateString();
    String endDate = existing?.endDate ?? '';

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: PawPulseTheme.white,
              shape: RoundedRectangleBorder(
                borderRadius: PawPulseTheme.cardRadius,
              ),
              title: Text(
                existing == null ? 'Add Medicine Dose' : 'Edit Medicine Dose',
                style: const TextStyle(
                  color: PawPulseTheme.darkNavy,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.initialPet == null && _pets.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DropdownButtonFormField<String>(
                            initialValue: formPetId.isNotEmpty
                                ? formPetId
                                : _pets.first.id,
                            decoration: InputDecoration(
                              labelText: 'Assign to Pet *',
                              labelStyle: const TextStyle(
                                color: PawPulseTheme.secondaryGray,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: PawPulseTheme.primaryCyan,
                                  width: 2,
                                ),
                              ),
                            ),
                            items: _pets.map((pet) {
                              return DropdownMenuItem(
                                value: pet.id,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundImage:
                                          _getPetImage(pet.petImage),
                                      child: pet.petImage.isEmpty
                                          ? const Icon(Icons.pets, size: 12)
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      pet.petName,
                                      style: const TextStyle(
                                        color: PawPulseTheme.darkNavy,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => formPetId = val);
                              }
                            },
                          ),
                        )
                      else if (widget.initialPet != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.pets,
                                color: PawPulseTheme.primaryCyan,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.initialPet!.petName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: PawPulseTheme.darkNavy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      _field(nameController, 'Medicine name *'),
                      _field(dosageController, 'Dosage (e.g. 5ml, 1 tablet) *'),
                      _field(
                        instructionsController,
                        'Instructions (e.g. Give with meal) *',
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.calendar_today,
                          color: PawPulseTheme.primaryCyan,
                          size: 20,
                        ),
                        title: Text(
                          'Dose Date: $selectedDate',
                          style: const TextStyle(
                            color: PawPulseTheme.darkNavy,
                            fontSize: 14,
                          ),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogCtx,
                            initialDate: DateTime.tryParse(selectedDate) ??
                                DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: PawPulseTheme.primaryCyan,
                                  onPrimary: PawPulseTheme.darkNavy,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate =
                                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.access_time,
                          color: PawPulseTheme.primaryCyan,
                          size: 20,
                        ),
                        title: Text(
                          'Dose Time: $selectedTime',
                          style: const TextStyle(
                            color: PawPulseTheme.darkNavy,
                            fontSize: 14,
                          ),
                        ),
                        onTap: () async {
                          final parts = selectedTime.split(':');
                          final initial = TimeOfDay(
                            hour: int.tryParse(parts[0]) ?? 8,
                            minute: int.tryParse(parts[1]) ?? 0,
                          );
                          final picked = await showTimePicker(
                            context: dialogCtx,
                            initialTime: initial,
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: PawPulseTheme.primaryCyan,
                                  onPrimary: PawPulseTheme.darkNavy,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedTime =
                                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                      ),
                      _field(
                        notesController,
                        'Notes (optional)',
                        required: false,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: PawPulseTheme.secondaryGray),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PawPulseTheme.primaryCyan,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: PawPulseTheme.buttonRadius,
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);
                          try {
                            if (existing == null) {
                              final record = MedicineRecord.create(
                                petId: formPetId,
                                userId: userId,
                                medicineName: nameController.text.trim(),
                                dosage: dosageController.text.trim(),
                                instructions:
                                    instructionsController.text.trim(),
                                scheduledDate: selectedDate,
                                scheduledTime: selectedTime,
                                startDate: startDate,
                                endDate: endDate,
                                notes: notesController.text.trim(),
                              );
                              await _service.addMedicine(record);
                            } else {
                              final updated = existing.copyWith(
                                medicineName: nameController.text.trim(),
                                dosage: dosageController.text.trim(),
                                instructions:
                                    instructionsController.text.trim(),
                                scheduledDate: selectedDate,
                                scheduledTime: selectedTime,
                                notes: notesController.text.trim(),
                              );
                              await _service.updateMedicine(updated);
                            }
                            if (!dialogCtx.mounted) return;
                            Navigator.pop(dialogCtx);
                            await _load();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  existing == null
                                      ? 'Medicine dose added!'
                                      : 'Medicine dose updated!',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!dialogCtx.mounted) return;
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(content: Text('Save failed: $e')),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    dosageController.dispose();
    instructionsController.dispose();
    notesController.dispose();
  }

  Future<void> _confirmDelete(MedicineRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PawPulseTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: PawPulseTheme.cardRadius,
        ),
        title: const Text(
          'Delete Medicine Dose?',
          style: TextStyle(
            color: PawPulseTheme.darkNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Delete "${record.medicineName}" scheduled for ${record.scheduledDate} at ${record.scheduledTime}?',
          style: const TextStyle(color: PawPulseTheme.secondaryGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: PawPulseTheme.secondaryGray),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.deleteMedicine(record.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine dose deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _toggleAdministered(MedicineRecord record) async {
    try {
      await _service.setAdministered(record.id, !record.isAdministered);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = widget.initialPet != null
        ? '${widget.initialPet!.petName} – Medicine'
        : 'Medicine Schedule (All Pets)';

    return Scaffold(
      backgroundColor: PawPulseTheme.background,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: PawPulseTheme.turquoise,
              foregroundColor: PawPulseTheme.darkNavy,
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                ),
              ],
            ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: PawPulseTheme.primaryCyan,
        tooltip: 'Add Medicine Dose',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: PawPulseTheme.primaryCyan),
      );
    }
    if (_errorMessage.isNotEmpty) {
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
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PawPulseTheme.primaryCyan,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: PawPulseTheme.buttonRadius,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayed = _displayedRecords;

    return Column(
      children: [
        if (widget.initialPet == null && _pets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All Pets (${_records.length})'),
                    selected: _selectedFilterPetId == 'all',
                    selectedColor: PawPulseTheme.primaryCyan,
                    backgroundColor: PawPulseTheme.white,
                    side: const BorderSide(color: PawPulseTheme.lightCyan),
                    labelStyle: TextStyle(
                      color: _selectedFilterPetId == 'all'
                          ? PawPulseTheme.darkNavy
                          : PawPulseTheme.secondaryGray,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilterPetId = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  ..._pets.map((p) {
                    final count =
                        _records.where((r) => r.petId == p.id).length;
                    final isSel = _selectedFilterPetId == p.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundImage: _getPetImage(p.petImage),
                          child: p.petImage.isEmpty
                              ? const Icon(Icons.pets, size: 14)
                              : null,
                        ),
                        label: Text('${p.petName} ($count)'),
                        selected: isSel,
                        selectedColor: PawPulseTheme.primaryCyan,
                        backgroundColor: PawPulseTheme.white,
                        side: const BorderSide(color: PawPulseTheme.lightCyan),
                        labelStyle: TextStyle(
                          color: isSel
                              ? PawPulseTheme.darkNavy
                              : PawPulseTheme.secondaryGray,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedFilterPetId = p.id);
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        Expanded(
          child: displayed.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.medical_services_outlined,
                          size: 64,
                          color: PawPulseTheme.primaryCyan,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No medicines scheduled yet.',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: PawPulseTheme.darkNavy,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap + to schedule a dose.',
                          style: TextStyle(
                            color: PawPulseTheme.secondaryGray,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: PawPulseTheme.primaryCyan,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: displayed.length,
                    itemBuilder: (context, index) =>
                        _buildCard(displayed[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCard(MedicineRecord record) {
    final petName = _getPetName(record.petId);

    return Card(
      color: PawPulseTheme.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: PawPulseTheme.cardRadius),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: record.isAdministered
                ? Colors.grey.shade200
                : PawPulseTheme.primaryCyan.withValues(alpha: 0.15),
            child: Icon(
              record.isAdministered
                  ? Icons.check_circle_rounded
                  : Icons.medical_services_rounded,
              color: record.isAdministered
                  ? PawPulseTheme.secondaryGray
                  : PawPulseTheme.primaryCyan,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  record.medicineName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    decoration: record.isAdministered
                        ? TextDecoration.lineThrough
                        : null,
                    color: record.isAdministered
                        ? PawPulseTheme.secondaryGray
                        : PawPulseTheme.darkNavy,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PawPulseTheme.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  petName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: PawPulseTheme.darkNavy,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: PawPulseTheme.secondaryGray,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${record.scheduledDate} at ${record.scheduledTime}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: PawPulseTheme.secondaryGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: record.isAdministered
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: record.isAdministered
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      record.isAdministered ? 'Given' : 'Pending',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: record.isAdministered
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.medication_rounded,
                    size: 14,
                    color: PawPulseTheme.secondaryGray,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Dosage: ${record.dosage}${record.instructions.isNotEmpty ? ' • ${record.instructions}' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: PawPulseTheme.darkNavy,
                      ),
                    ),
                  ),
                ],
              ),
              if (record.notes.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Notes: ${record.notes}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: PawPulseTheme.secondaryGray,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'Options',
            icon: const Icon(
              Icons.more_vert,
              color: PawPulseTheme.secondaryGray,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (v) {
              if (v == 'administer') _toggleAdministered(record);
              if (v == 'edit') _showForm(existing: record);
              if (v == 'delete') _confirmDelete(record);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'administer',
                child: Row(
                  children: [
                    Icon(
                      record.isAdministered
                          ? Icons.undo_rounded
                          : Icons.check_circle_outline_rounded,
                      color: PawPulseTheme.primaryCyan,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      record.isAdministered
                          ? 'Mark not given'
                          : 'Mark administered',
                      style: const TextStyle(color: PawPulseTheme.darkNavy),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Edit',
                      style: TextStyle(color: PawPulseTheme.darkNavy),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: PawPulseTheme.secondaryGray),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: PawPulseTheme.primaryCyan,
              width: 2,
            ),
          ),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                ? 'This field is required'
                : null
            : null,
      ),
    );
  }
}
