import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/api_controller.dart';
import '../controllers/firestore_client.dart';
import '../models/routine_model.dart';
import '../services/local_pet_image_service.dart';
import '../services/routine_service.dart';
import '../services/user_pets.dart';
import '../theme/pawpulse_theme.dart';

const Color kTurquoise = PawPulseTheme.primaryCyan;

/// Full Routine Schedule page.
///
/// Displays routine records across all pet profiles with pet filter chips,
/// pet badges on cards, and pet selection when creating new routines.
class RoutineSchedulePage extends StatefulWidget {
  final Datum? initialPet;
  final bool isEmbedded;
  final List<Datum>? allPets;
  const RoutineSchedulePage({
    super.key,
    this.initialPet,
    this.isEmbedded = false,
    this.allPets,
  });
  @override
  State<RoutineSchedulePage> createState() => _RoutineSchedulePageState();
}

class _RoutineSchedulePageState extends State<RoutineSchedulePage> {
  final _service = RoutineService();
  List<RoutineRecord> _records = [];
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
      final petId = widget.initialPet?.id;
      List<RoutineRecord> records;
      if (petId != null) {
        records = await _service.getRoutines(petId);
      } else {
        final docs = await FirestoreClient.queryByUser(kRoutineCollection);
        records = docs.map(RoutineRecord.fromFirestoreMap).toList();
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

  List<RoutineRecord> get _displayedRecords {
    if (widget.initialPet != null || _selectedFilterPetId == 'all') {
      return _records;
    }
    return _records.where((r) => r.petId == _selectedFilterPetId).toList();
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

  // ─── Form ──────────────────────────────────────────────────────────────────
  Future<void> _showForm({RoutineRecord? existing}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    String formPetId =
        existing?.petId ??
        widget.initialPet?.id ??
        (_pets.isNotEmpty ? _pets.first.id : '');
    final nameController = TextEditingController(
      text: existing?.activityName ?? '',
    );
    final notesController = TextEditingController(text: existing?.notes ?? '');
    String selectedType = existing?.activityType ?? ActivityType.walking;
    String selectedDate =
        existing?.scheduledDate ?? FirestoreClient.todayDateString();
    String selectedTime = existing?.scheduledTime ?? '09:00';
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: PawPulseTheme.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: PawPulseTheme.cardRadius,
              ),
              title: Text(
                existing == null ? 'Add Routine' : 'Edit Routine',
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
                            decoration: _inputDecoration('Assign to Pet *'),
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
                              const Icon(
                                Icons.pets,
                                color: kTurquoise,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.initialPet!.petName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: _inputDecoration('Activity type *'),
                          items: ActivityType.all
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(ActivityType.label(t)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedType = v);
                            }
                          },
                        ),
                      ),
                      _field(nameController, 'Activity name *'),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.calendar_today,
                          color: kTurquoise,
                          size: 20,
                        ),
                        title: Text(
                          'Date: $selectedDate',
                          style: const TextStyle(color: PawPulseTheme.darkNavy),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogCtx,
                            initialDate:
                                DateTime.tryParse(selectedDate) ??
                                DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: PawPulseTheme.primaryCyan,
                                  onPrimary: PawPulseTheme.darkNavy,
                                  onSurface: PawPulseTheme.darkNavy,
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
                          color: kTurquoise,
                          size: 20,
                        ),
                        title: Text(
                          'Time: $selectedTime',
                          style: const TextStyle(color: PawPulseTheme.darkNavy),
                        ),
                        onTap: () async {
                          final parts = selectedTime.split(':');
                          final initial = TimeOfDay(
                            hour: int.tryParse(parts[0]) ?? 9,
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
                                  onSurface: PawPulseTheme.darkNavy,
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PawPulseTheme.primaryCyan,
                    foregroundColor: PawPulseTheme.darkNavy,
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
                              final record = RoutineRecord.create(
                                petId: formPetId,
                                userId: userId,
                                activityType: selectedType,
                                activityName: nameController.text.trim(),
                                scheduledDate: selectedDate,
                                scheduledTime: selectedTime,
                                notes: notesController.text.trim(),
                              );
                              await _service.addRoutine(record);
                            } else {
                              final updated = existing.copyWith(
                                activityType: selectedType,
                                activityName: nameController.text.trim(),
                                scheduledDate: selectedDate,
                                scheduledTime: selectedTime,
                                notes: notesController.text.trim(),
                              );
                              await _service.updateRoutine(updated);
                            }
                            if (!dialogCtx.mounted) return;
                            Navigator.pop(dialogCtx);
                            await _load();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  existing == null
                                      ? 'Routine added!'
                                      : 'Routine updated!',
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
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    notesController.dispose();
  }

  Future<void> _confirmDelete(RoutineRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PawPulseTheme.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: PawPulseTheme.cardRadius),
        title: const Text(
          'Delete Routine?',
          style: TextStyle(
            color: PawPulseTheme.darkNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text('Delete "${record.activityName}"?'),
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
      await _service.deleteRoutine(record.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Routine deleted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _toggleComplete(RoutineRecord record) async {
    try {
      await _service.setCompleted(record.id, !record.isCompleted);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final title = widget.initialPet != null
        ? '${widget.initialPet!.petName} – Routine'
        : 'Routine Schedule (All Pets)';
    return Scaffold(
      backgroundColor: PawPulseTheme.background,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: PawPulseTheme.darkNavy,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: PawPulseTheme.headerGradient,
                ),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: PawPulseTheme.darkNavy,
                  fontWeight: FontWeight.bold,
                ),
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
        foregroundColor: PawPulseTheme.darkNavy,
        tooltip: 'Add Routine',
        child: const Icon(Icons.add),
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All Pets (${_records.length})'),
                    selected: _selectedFilterPetId == 'all',
                    selectedColor: PawPulseTheme.primaryCyan,
                    labelStyle: TextStyle(
                      color: _selectedFilterPetId == 'all'
                          ? PawPulseTheme.darkNavy
                          : PawPulseTheme.secondaryGray,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilterPetId = 'all');
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ..._pets.map((p) {
                    final count = _records.where((r) => r.petId == p.id).length;
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
                          Icons.directions_walk,
                          size: 64,
                          color: kTurquoise,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No routines found.',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap + to add a routine.',
                          style: TextStyle(color: PawPulseTheme.secondaryGray),
                        ),
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

  Widget _buildCard(RoutineRecord record) {
    final petName = _getPetName(record.petId);
    return Card(
      color: PawPulseTheme.white,
      elevation: 2,
      shadowColor: PawPulseTheme.darkNavy.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: PawPulseTheme.cardRadius),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: record.isCompleted
              ? Colors.grey.shade200
              : PawPulseTheme.primaryCyan.withValues(alpha: 0.15),
          child: Icon(
            record.isCompleted
                ? Icons.check_circle_rounded
                : Icons.directions_walk_rounded,
            color: record.isCompleted
                ? PawPulseTheme.secondaryGray
                : PawPulseTheme.primaryCyan,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                record.activityName,
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
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.category_rounded,
                  size: 13,
                  color: PawPulseTheme.secondaryGray,
                ),
                const SizedBox(width: 4),
                Text(
                  'Type: ${ActivityType.label(record.activityType)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PawPulseTheme.secondaryGray,
                  ),
                ),
              ],
            ),
            if (record.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Notes: ${record.notes}',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: PawPulseTheme.secondaryGray,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Options',
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
                  Icon(Icons.edit_outlined, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: PawPulseTheme.secondaryGray),
      filled: true,
      fillColor: PawPulseTheme.background,
      border: OutlineInputBorder(
        borderRadius: PawPulseTheme.buttonRadius,
        borderSide: BorderSide(
          color: PawPulseTheme.secondaryGray.withValues(alpha: 0.25),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: PawPulseTheme.buttonRadius,
        borderSide: BorderSide(
          color: PawPulseTheme.secondaryGray.withValues(alpha: 0.25),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: PawPulseTheme.buttonRadius,
        borderSide: const BorderSide(
          color: PawPulseTheme.primaryCyan,
          width: 1.6,
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: _inputDecoration(label),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                  ? 'This field is required'
                  : null
            : null,
      ),
    );
  }
}
