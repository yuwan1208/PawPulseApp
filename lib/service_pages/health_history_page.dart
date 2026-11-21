import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../controllers/api_controller.dart';
import '../controllers/firestore_client.dart';
import '../models/health_record_model.dart';
import '../services/health_service.dart';
import '../services/local_pet_image_service.dart';
import '../services/user_pets.dart';
import '../theme/pawpulse_theme.dart';

/// Full Health History page.
///
/// Displays health records across all pet profiles with pet filter chips,
/// pet badges on cards, and pet selection when logging new health events.
/// Redesigned using the PawPulse Dashboard theme (cyan-to-turquoise palette).
class HealthHistoryPage extends StatefulWidget {
  final Datum? initialPet;
  final bool isEmbedded;
  final List<Datum>? allPets;

  const HealthHistoryPage({
    super.key,
    this.initialPet,
    this.isEmbedded = false,
    this.allPets,
  });

  @override
  State<HealthHistoryPage> createState() => _HealthHistoryPageState();
}

class _HealthHistoryPageState extends State<HealthHistoryPage> {
  final _service = HealthService();

  List<HealthRecord> _records = [];
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

      List<HealthRecord> records;
      final petId = widget.initialPet?.id;
      if (petId != null) {
        records = await _service.getHealthRecords(petId);
      } else {
        final docs = await FirestoreClient.queryByUser(kHealthCollection);
        records = docs.map(HealthRecord.fromFirestoreMap).toList();
        records.sort((a, b) => b.recordDate.compareTo(a.recordDate));
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

  List<HealthRecord> get _displayedRecords {
    if (widget.initialPet != null || _selectedFilterPetId == 'all') {
      return _records;
    }
    return _records.where((h) => h.petId == _selectedFilterPetId).toList();
  }

  String _getPetName(String petId) {
    for (final p in _pets) {
      if (p.id == petId) return p.petName;
    }
    return 'Pet';
  }

  ImageProvider? _getPetImage(String? imagePath, {String? petId}) {
    return LocalPetImageService().getPetImageProvider(
      petId: petId,
      fallbackUrl: imagePath,
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case HealthRecordType.vetVisit:
        return Icons.local_hospital_rounded;
      case HealthRecordType.vaccination:
        return Icons.vaccines_rounded;
      case HealthRecordType.checkup:
        return Icons.health_and_safety_rounded;
      case HealthRecordType.illness:
        return Icons.healing_rounded;
      case HealthRecordType.treatment:
        return Icons.medication_rounded;
      default:
        return Icons.favorite_rounded;
    }
  }

  // ─── Form ──────────────────────────────────────────────────────────────────

  Future<void> _showForm({HealthRecord? existing}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    String formPetId = existing?.petId ??
        widget.initialPet?.id ??
        (_pets.isNotEmpty ? _pets.first.id : '');

    final descController =
        TextEditingController(text: existing?.description ?? '');
    final vetController =
        TextEditingController(text: existing?.vetName ?? '');
    final treatmentController =
        TextEditingController(text: existing?.treatmentDetails ?? '');
    final vaccineController =
        TextEditingController(text: existing?.vaccinationDetails ?? '');
    final notesController =
        TextEditingController(text: existing?.notes ?? '');

    String selectedType = existing?.recordType ?? HealthRecordType.checkup;
    String selectedDate =
        existing?.recordDate ?? FirestoreClient.todayDateString();
    bool isCompleted = existing?.isCompleted ?? false;

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
                existing == null ? 'Add Health Record' : 'Edit Health Record',
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
                                  color: PawPulseTheme.secondaryGray),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
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
                              final img = _getPetImage(pet.petImage, petId: pet.id);
                              return DropdownMenuItem(
                                value: pet.id,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundImage: img,
                                      child: img == null
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
                              const SizedBox(width: 8),
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
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: InputDecoration(
                            labelText: 'Event Type *',
                            labelStyle: const TextStyle(
                                color: PawPulseTheme.secondaryGray),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: PawPulseTheme.primaryCyan,
                                width: 2,
                              ),
                            ),
                          ),
                          items: HealthRecordType.all
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(
                                      HealthRecordType.label(t),
                                      style: const TextStyle(
                                        color: PawPulseTheme.darkNavy,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedType = v);
                            }
                          },
                        ),
                      ),
                      _field(descController, 'Description / Summary *'),
                      _field(vetController, 'Veterinarian / Clinic name',
                          required: false),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.calendar_today_rounded,
                          color: PawPulseTheme.primaryCyan,
                          size: 20,
                        ),
                        title: Text(
                          'Date: $selectedDate',
                          style: const TextStyle(
                            color: PawPulseTheme.darkNavy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            size: 14, color: PawPulseTheme.secondaryGray),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogCtx,
                            initialDate: DateTime.tryParse(selectedDate) ??
                                DateTime.now(),
                            firstDate: DateTime(2015),
                            lastDate: DateTime(2035),
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
                      if (selectedType == HealthRecordType.vaccination)
                        _field(vaccineController, 'Vaccine Details',
                            required: false),
                      if (selectedType == HealthRecordType.treatment ||
                          selectedType == HealthRecordType.illness)
                        _field(treatmentController, 'Treatment Details',
                            required: false),
                      _field(notesController, 'Notes (optional)',
                          required: false),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Mark as Completed',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: PawPulseTheme.darkNavy,
                          ),
                        ),
                        subtitle: Text(
                          isCompleted
                              ? 'Event completed / attended'
                              : 'Pending appointment / event',
                          style: const TextStyle(
                            fontSize: 12,
                            color: PawPulseTheme.secondaryGray,
                          ),
                        ),
                        value: isCompleted,
                        activeThumbColor: PawPulseTheme.primaryCyan,
                        onChanged: (val) {
                          setDialogState(() => isCompleted = val);
                        },
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
                    foregroundColor: PawPulseTheme.darkNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: PawPulseTheme.buttonRadius,
                    ),
                    elevation: 0,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);
                          try {
                            if (existing == null) {
                              final record = HealthRecord.create(
                                petId: formPetId,
                                userId: userId,
                                recordDate: selectedDate,
                                recordType: selectedType,
                                description: descController.text.trim(),
                                vetName: vetController.text.trim(),
                                treatmentDetails:
                                    treatmentController.text.trim(),
                                vaccinationDetails:
                                    vaccineController.text.trim(),
                                notes: notesController.text.trim(),
                                isCompleted: isCompleted,
                              );
                              await _service.addHealthRecord(record);
                            } else {
                              final updated = existing.copyWith(
                                recordDate: selectedDate,
                                recordType: selectedType,
                                description: descController.text.trim(),
                                vetName: vetController.text.trim(),
                                treatmentDetails:
                                    treatmentController.text.trim(),
                                vaccinationDetails:
                                    vaccineController.text.trim(),
                                notes: notesController.text.trim(),
                                isCompleted: isCompleted,
                              );
                              await _service.updateHealthRecord(updated);
                            }
                            if (!dialogCtx.mounted) return;
                            Navigator.pop(dialogCtx);
                            await _load();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  existing == null
                                      ? 'Health record added!'
                                      : 'Health record updated!',
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
                            color: PawPulseTheme.darkNavy,
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

    descController.dispose();
    vetController.dispose();
    treatmentController.dispose();
    vaccineController.dispose();
    notesController.dispose();
  }

  Future<void> _toggleComplete(HealthRecord record) async {
    try {
      await _service.setCompleted(record.id, !record.isCompleted);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  Future<void> _confirmDelete(HealthRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PawPulseTheme.white,
        shape: RoundedRectangleBorder(borderRadius: PawPulseTheme.cardRadius),
        title: const Text(
          'Delete Health Record?',
          style: TextStyle(
            color: PawPulseTheme.darkNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Delete "${record.description}"?',
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
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.deleteHealthRecord(record.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health record deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = widget.initialPet != null
        ? '${widget.initialPet!.petName} – Health History'
        : 'Health History (All Pets)';

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
        tooltip: 'Add Health Record',
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
                    final img = _getPetImage(p.petImage, petId: p.id);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundImage: img,
                          child: img == null
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
                          Icons.favorite_rounded,
                          size: 64,
                          color: PawPulseTheme.primaryCyan,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No health records found.',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: PawPulseTheme.darkNavy,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap + to log an appointment, vaccination, or checkup.',
                          style: TextStyle(
                            color: PawPulseTheme.secondaryGray,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
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

  Widget _buildCard(HealthRecord record) {
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
            backgroundColor: record.isCompleted
                ? Colors.grey.shade200
                : PawPulseTheme.primaryCyan.withValues(alpha: 0.15),
            child: Icon(
              record.isCompleted
                  ? Icons.check_circle_rounded
                  : _getTypeIcon(record.recordType),
              color: record.isCompleted
                  ? PawPulseTheme.secondaryGray
                  : PawPulseTheme.primaryCyan,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  record.description.isNotEmpty
                      ? record.description
                      : HealthRecordType.label(record.recordType),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    decoration: record.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    color: record.isCompleted
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
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: PawPulseTheme.secondaryGray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.recordDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PawPulseTheme.secondaryGray,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: PawPulseTheme.lightCyan,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      HealthRecordType.label(record.recordType),
                      style: const TextStyle(
                        fontSize: 11,
                        color: PawPulseTheme.darkNavy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: record.isCompleted
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: record.isCompleted
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      record.isCompleted ? 'Completed' : 'Pending',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: record.isCompleted
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              if (record.vetName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.business_rounded,
                      size: 13,
                      color: PawPulseTheme.secondaryGray,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Vet / Clinic: ${record.vetName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: PawPulseTheme.secondaryGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (record.vaccinationDetails.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.vaccines_rounded,
                      size: 13,
                      color: PawPulseTheme.secondaryGray,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Vaccine: ${record.vaccinationDetails}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: PawPulseTheme.secondaryGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (record.treatmentDetails.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.medication_rounded,
                      size: 13,
                      color: PawPulseTheme.secondaryGray,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Treatment: ${record.treatmentDetails}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: PawPulseTheme.secondaryGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (record.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.note_alt_outlined,
                      size: 13,
                      color: PawPulseTheme.secondaryGray,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Notes: ${record.notes}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: PawPulseTheme.secondaryGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'Options',
            icon: const Icon(Icons.more_vert, color: PawPulseTheme.secondaryGray),
            onSelected: (v) {
              if (v == 'complete') _toggleComplete(record);
              if (v == 'edit') _showForm(existing: record);
              if (v == 'delete') _confirmDelete(record);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'complete',
                child: Row(
                  children: [
                    Icon(
                      record.isCompleted
                          ? Icons.undo_rounded
                          : Icons.check_circle_rounded,
                      color: record.isCompleted ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(record.isCompleted
                        ? 'Mark as Pending'
                        : 'Mark as Completed'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: PawPulseTheme.secondaryGray),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
