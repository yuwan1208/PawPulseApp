import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../controllers/api_controller.dart';
import '../controllers/firestore_client.dart';
import '../models/health_record_model.dart';
import '../services/health_service.dart';
import '../services/user_pets.dart';

const Color kTurquoise = Color.fromARGB(255, 37, 214, 199);

/// Full Health History page.
///
/// Displays health records across all pet profiles with pet filter chips,
/// pet badges on cards, and pet selection when logging new health events.
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
    return _records
        .where((h) => h.petId == _selectedFilterPetId)
        .toList();
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

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(existing == null ? 'Add Health Record' : 'Edit Health Record'),
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
                          initialValue: formPetId.isNotEmpty ? formPetId : _pets.first.id,
                          decoration: const InputDecoration(
                            labelText: 'Assign to Pet *',
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: kTurquoise),
                            ),
                          ),
                          items: _pets.map((pet) {
                            return DropdownMenuItem(
                              value: pet.id,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundImage: _getPetImage(pet.petImage),
                                    child: pet.petImage.isEmpty
                                        ? const Icon(Icons.pets, size: 12)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(pet.petName),
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
                            const Icon(Icons.pets, color: kTurquoise, size: 18),
                            const SizedBox(width: 6),
                            Text(widget.initialPet!.petName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Event Type *',
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: kTurquoise),
                          ),
                        ),
                        items: HealthRecordType.all
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(HealthRecordType.label(t)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedType = v);
                        },
                      ),
                    ),
                    _field(descController, 'Description / Summary *'),
                    _field(vetController, 'Veterinarian / Clinic name',
                        required: false),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today,
                          color: kTurquoise, size: 20),
                      title: Text('Date: $selectedDate'),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogCtx,
                          initialDate: DateTime.tryParse(selectedDate) ??
                              DateTime.now(),
                          firstDate: DateTime(2015),
                          lastDate: DateTime(2035),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme:
                                  const ColorScheme.light(primary: kTurquoise),
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
                    _field(notesController, 'Notes (optional)', required: false),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTurquoise,
                  foregroundColor: Colors.white,
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
                            );
                            await _service.updateHealthRecord(updated);
                          }
                          if (!dialogCtx.mounted) return;
                          Navigator.pop(dialogCtx);
                          await _load();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(existing == null
                                  ? 'Health record added!'
                                  : 'Health record updated!'),
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
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        });
      },
    );

    descController.dispose();
    vetController.dispose();
    treatmentController.dispose();
    vaccineController.dispose();
    notesController.dispose();
  }

  Future<void> _confirmDelete(HealthRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Health Record?'),
        content: Text('Delete "${record.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
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
      await _service.deleteHealthRecord(record.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Health record deleted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = widget.initialPet != null
        ? '${widget.initialPet!.petName} – Health History'
        : 'Health History (All Pets)';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: kTurquoise,
              title: Text(title),
              centerTitle: true,
              actions: [
                IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh),
                    onPressed: _load),
              ],
            ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: kTurquoise,
        tooltip: 'Add Health Record',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: kTurquoise));
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
                  label: const Text('Retry')),
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All Pets (${_records.length})'),
                    selected: _selectedFilterPetId == 'all',
                    selectedColor: kTurquoise,
                    labelStyle: TextStyle(
                      color: _selectedFilterPetId == 'all'
                          ? Colors.white
                          : Colors.black87,
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
                        selectedColor: kTurquoise,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : Colors.black87,
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
                        Icon(Icons.favorite, size: 64, color: kTurquoise),
                        SizedBox(height: 16),
                        Text('No health records found.',
                            style: TextStyle(fontSize: 16)),
                        SizedBox(height: 8),
                        Text('Tap + to log an appointment, vaccination, or checkup.',
                            style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: kTurquoise,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
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
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kTurquoise.withValues(alpha: 0.15),
          child: const Icon(Icons.favorite, color: kTurquoise),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                record.description.isNotEmpty
                    ? record.description
                    : HealthRecordType.label(record.recordType),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
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
            ),
          ],
        ),
        subtitle: Text(
          '${record.recordDate} • ${HealthRecordType.label(record.recordType)}'
          '${record.vetName.isNotEmpty ? '\nClinic/Vet: ${record.vetName}' : ''}'
          '${record.vaccinationDetails.isNotEmpty ? '\nVaccine: ${record.vaccinationDetails}' : ''}'
          '${record.treatmentDetails.isNotEmpty ? '\nTreatment: ${record.treatmentDetails}' : ''}'
          '${record.notes.isNotEmpty ? '\nNotes: ${record.notes}' : ''}',
        ),
        isThreeLine: record.vetName.isNotEmpty ||
            record.vaccinationDetails.isNotEmpty ||
            record.treatmentDetails.isNotEmpty ||
            record.notes.isNotEmpty,
        trailing: PopupMenuButton<String>(
          tooltip: 'Options',
          onSelected: (v) {
            if (v == 'edit') _showForm(existing: record);
            if (v == 'delete') _confirmDelete(record);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit, color: Colors.blue),
                SizedBox(width: 8),
                Text('Edit'),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete'),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: kTurquoise)),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'This field is required' : null
            : null,
      ),
    );
  }
}
