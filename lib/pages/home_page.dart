import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/api_controller.dart';
import '../services/user_pets.dart';
import '../theme/pawpulse_theme.dart';
import 'all_pets_overview_page.dart';
import '../service_pages/pet_details_page.dart';
import '../service_pages/feeding_schedule_page.dart';
import '../service_pages/routine_schedule_page.dart';
import '../service_pages/medicine_schedule_page.dart';
import '../service_pages/health_history_page.dart';
import '../service_pages/profile_settings_page.dart';
import '../controllers/firestore_client.dart';
import '../models/feeding_model.dart';
import '../models/routine_model.dart';
import '../models/medicine_model.dart';
import '../models/health_record_model.dart';
import '../services/feeding_service.dart';
import '../services/routine_service.dart';
import '../services/medicine_service.dart';
import '../services/health_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  late UsersPets usersPets;
  bool isDataLoaded = false;
  String errorMessage = '';
  String searchQuery = '';

  final ApiController _apiController = ApiController();
  final FeedingService _feedingService = FeedingService();
  final RoutineService _routineService = RoutineService();
  final MedicineService _medicineService = MedicineService();
  final HealthService _healthService = HealthService();

  List<FeedingRecord> _todayFeedings = [];
  List<RoutineRecord> _todayRoutines = [];
  List<MedicineRecord> _todayMedicines = [];
  List<HealthRecord> _todayHealth = [];
  bool _isLoadingSchedules = false;

  // Carousel timer & controller for automatic 15-second profile sliding
  PageController? _petCarouselController;
  Timer? _petCarouselTimer;
  int _currentCarouselIndex = 0;

  final List<String> pageTitles = [
    'Dashboard',
    'My Pets',
    'Feeding Schedule',
    'Routine Schedule',
    'Medicine Schedule',
    'Health History',
  ];

  @override
  void initState() {
    super.initState();
    callAPIandAssignData();
    _loadTodaySchedules();
  }

  @override
  void dispose() {
    _petCarouselTimer?.cancel();
    _petCarouselController?.dispose();
    super.dispose();
  }

  Future<void> _loadTodaySchedules() async {
    if (!mounted) return;
    setState(() => _isLoadingSchedules = true);
    try {
      final today = FirestoreClient.todayDateString();
      final results = await Future.wait([
        FirestoreClient.queryByUser(kFeedingCollection),
        FirestoreClient.queryByUser(kRoutineCollection),
        FirestoreClient.queryByUser(kMedicineCollection),
        FirestoreClient.queryByUser(kHealthCollection),
      ]);

      if (!mounted) return;
      final feedings = (results[0])
          .map(FeedingRecord.fromFirestoreMap)
          .where((f) => f.scheduledDate == today)
          .toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

      final routines = (results[1])
          .map(RoutineRecord.fromFirestoreMap)
          .where((r) => r.scheduledDate == today)
          .toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

      final medicines = (results[2])
          .map(MedicineRecord.fromFirestoreMap)
          .where((m) => m.scheduledDate == today)
          .toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

      final health = (results[3])
          .map(HealthRecord.fromFirestoreMap)
          .where((h) => h.recordDate == today)
          .toList();

      setState(() {
        _todayFeedings = feedings;
        _todayRoutines = routines;
        _todayMedicines = medicines;
        _todayHealth = health;
        _isLoadingSchedules = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSchedules = false);
    }
  }

  // GET: Load pets from Firestore.
  Future<void> callAPIandAssignData() async {
    if (!mounted) return;

    setState(() {
      isDataLoaded = false;
      errorMessage = '';
    });

    try {
      final result = await _apiController.getDataFromAPI();

      if (!mounted) return;

      setState(() {
        usersPets = result;
        isDataLoaded = true;
        errorMessage = '';
      });

      _initPetCarousel();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        usersPets = UsersPets(data: []);
        isDataLoaded = true;
        errorMessage = _apiController.errorMessage.isNotEmpty
            ? _apiController.errorMessage
            : error.toString();
      });
    }
  }

  void _initPetCarousel() {
    _petCarouselTimer?.cancel();
    _currentCarouselIndex = 0;
    _petCarouselController?.dispose();
    _petCarouselController = PageController(initialPage: 0);

    if (usersPets.data.length > 1) {
      _petCarouselTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (!mounted || usersPets.data.isEmpty) return;
        if (_petCarouselController != null &&
            _petCarouselController!.hasClients) {
          final nextIndex = (_currentCarouselIndex + 1) % usersPets.data.length;
          _petCarouselController!.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
          if (mounted) {
            setState(() {
              _currentCarouselIndex = nextIndex;
            });
          }
        }
      });
    }
  }

  void selectPage(int index) {
    setState(() {
      selectedIndex = index;
    });

    Navigator.pop(context);
    if (index == 0) {
      _loadTodaySchedules();
    }
  }

  // Open the Add Pet form.
  Future<void> showAddPetMessage() async {
    await _showPetFormDialog();
  }

  // Add or edit a pet.
  Future<void> _showPetFormDialog({Datum? pet}) async {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: pet?.petName ?? '');
    final speciesController = TextEditingController(text: pet?.species ?? '');
    final breedController = TextEditingController(text: pet?.breed ?? '');
    final cleanAge = (pet?.age ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final ageController = TextEditingController(text: cleanAge);
    final cleanWeight = (pet?.weight ?? '').replaceAll(RegExp(r'[^0-9.]'), '');
    final weightController = TextEditingController(text: cleanWeight);
    final genderController = TextEditingController(text: pet?.gender ?? '');

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(pet == null ? 'Add Pet' : 'Edit Pet'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _petInput(nameController, 'Pet Name'),
                    _petInput(speciesController, 'Species'),
                    _petInput(breedController, 'Breed'),
                    _petInput(ageController, 'Age in years', number: true),
                    _petInput(weightController, 'Weight in kg', number: true),
                    _petInput(genderController, 'Gender'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PawPulseTheme.primaryCyan,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;

                  final age = int.tryParse(ageController.text.trim());
                  final weight = double.tryParse(weightController.text.trim());

                  if (age == null || weight == null || age < 0 || weight < 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid age and weight.'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, {
                    'name': nameController.text.trim(),
                    'species': speciesController.text.trim(),
                    'breed': breedController.text.trim(),
                    'age': age,
                    'weight': weight,
                    'gender': genderController.text.trim(),
                  });
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (result == null || !mounted) return;

      if (pet == null) {
        // POST: Create a new pet.
        await _apiController.addPet(
          name: result['name'] as String,
          species: result['species'] as String,
          breed: result['breed'] as String,
          ageYears: result['age'] as int,
          weightKg: result['weight'] as double,
          gender: result['gender'] as String,
        );
      } else {
        // PATCH: Update an existing Firestore document.
        await _apiController.updatePet(
          documentId: pet.id,
          name: result['name'] as String,
          species: result['species'] as String,
          breed: result['breed'] as String,
          ageYears: result['age'] as int,
          weightKg: result['weight'] as double,
          gender: result['gender'] as String,
          avatarUrl: pet.petImage,
          isFriendly: pet.isFriendly,
        );
      }

      await callAPIandAssignData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pet == null
                ? 'Pet added successfully!'
                : 'Pet updated successfully!',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Operation failed: $error')));
    } finally {
      nameController.dispose();
      speciesController.dispose();
      breedController.dispose();
      ageController.dispose();
      weightController.dispose();
      genderController.dispose();
    }
  }

  Widget _petInput(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  // DELETE: Confirm before deleting a pet.
  Future<void> _confirmDeletePet(Datum pet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Pet?'),
          content: Text('Are you sure you want to delete ${pet.petName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _apiController.deletePet(pet.id);
      await callAPIandAssignData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${pet.petName} deleted successfully.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
    }
  }

  // Supports local asset images and online image URLs.
  ImageProvider? _getPetImage(String imagePath) {
    if (imagePath.isEmpty) return null;

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return NetworkImage(imagePath);
    }

    return AssetImage(imagePath);
  }

  void _openPetOverview(Datum pet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PetDetailsPage(pet: pet)),
    );
    await _loadTodaySchedules();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: PawPulseTheme.background,

      appBar: AppBar(
        backgroundColor: PawPulseTheme.turquoise,
        foregroundColor: PawPulseTheme.darkNavy,
        title: Text(
          pageTitles[selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              callAPIandAssignData();
              _loadTodaySchedules();
            },
          ),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Account',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),

      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: PawPulseTheme.primaryCyan),
              accountName: const Text('PawPulse'),
              accountEmail: Text(user?.email ?? 'Pet Care User'),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.pets, size: 30),
              ),
            ),
            _drawerItem(0, Icons.dashboard, 'Dashboard'),
            _drawerItem(1, Icons.pets, 'My Pets'),
            _drawerItem(2, Icons.restaurant, 'Feeding Schedule'),
            _drawerItem(3, Icons.directions_walk, 'Routine Schedule'),
            _drawerItem(4, Icons.medical_services, 'Medicine Schedule'),
            _drawerItem(5, Icons.favorite, 'Health History'),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),

      endDrawer: Drawer(
        backgroundColor: PawPulseTheme.white,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                decoration: const BoxDecoration(
                  gradient: PawPulseTheme.primaryGradient,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: PawPulseTheme.white,
                      child: Icon(
                        Icons.person,
                        size: 38,
                        color: PawPulseTheme.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user?.displayName?.trim().isNotEmpty == true
                          ? user!.displayName!
                          : 'PawPulse User',
                      style: const TextStyle(
                        color: PawPulseTheme.darkNavy,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'No email available',
                      style: const TextStyle(
                        color: PawPulseTheme.darkNavy,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.settings_outlined,
                  color: PawPulseTheme.primaryCyan,
                ),
                title: const Text('Profile Settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileSettingsPage(),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout'),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ],
          ),
        ),
      ),

      body: _buildPageContent(),

      floatingActionButton: (selectedIndex == 0 || selectedIndex == 1)
          ? FloatingActionButton(
              onPressed: showAddPetMessage,
              backgroundColor: PawPulseTheme.primaryCyan,
              tooltip: 'Add Pet',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _drawerItem(int index, IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: PawPulseTheme.primaryCyan),
      title: Text(title),
      selected: selectedIndex == index,
      onTap: () => selectPage(index),
    );
  }

  Widget _buildPageContent() {
    final petsList = isDataLoaded ? usersPets.data : <Datum>[];

    switch (selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildPetsFromAPI();
      case 2:
        return FeedingSchedulePage(isEmbedded: true, allPets: petsList);
      case 3:
        return RoutineSchedulePage(isEmbedded: true, allPets: petsList);
      case 4:
        return MedicineSchedulePage(isEmbedded: true, allPets: petsList);
      case 5:
        return HealthHistoryPage(isEmbedded: true, allPets: petsList);
      default:
        return _buildDashboard();
    }
  }

  // Dynamic pet list with search filtering.
  Widget _buildPetsFromAPI() {
    if (!isDataLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: PawPulseTheme.primaryCyan),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'Unable to load pets from Firestore',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(errorMessage, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: callAPIandAssignData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final query = searchQuery.trim().toLowerCase();

    final filteredPets = usersPets.data.where((pet) {
      return pet.petName.toLowerCase().contains(query) ||
          pet.species.toLowerCase().contains(query) ||
          pet.breed.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by name, species, or breed',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: PawPulseTheme.primaryCyan),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${filteredPets.length} pet(s) found',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ),
        Expanded(
          child: filteredPets.isEmpty
              ? Center(
                  child: Text(
                    usersPets.data.isEmpty
                        ? 'No pet data found in Firestore.'
                        : 'No pets match "$searchQuery".',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredPets.length,
                  itemBuilder: (context, index) {
                    return _getPetRow(filteredPets[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _getPetRow(Datum pet) {
    final petImage = _getPetImage(pet.petImage);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          radius: 21,
          backgroundColor: PawPulseTheme.primaryCyan,
          backgroundImage: petImage,
          child: petImage == null
              ? const Icon(Icons.pets, color: Colors.white)
              : null,
        ),
        title: Text(
          pet.petName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${pet.species} • ${pet.breed}\nOwner: ${pet.userName}'),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          tooltip: 'Pet actions',
          onSelected: (value) {
            if (value == 'overview') {
              _openPetOverview(pet);
            } else if (value == 'details') {
              _showPetDetailsDialog(pet);
            } else if (value == 'edit') {
              _showPetFormDialog(pet: pet);
            } else if (value == 'delete') {
              _confirmDeletePet(pet);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'overview',
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: PawPulseTheme.primaryCyan),
                  SizedBox(width: 8),
                  Text('Daily Overview'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('Quick Info'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _openPetOverview(pet),
      ),
    );
  }

  void _showPetDetailsDialog(Datum pet) {
    final petImage = _getPetImage(pet.petImage);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: PawPulseTheme.primaryCyan,
                backgroundImage: petImage,
                child: petImage == null
                    ? const Icon(Icons.pets, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(pet.petName)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              Text('Species: ${pet.species}'),
              const SizedBox(height: 8),
              Text('Breed: ${pet.breed}'),
              const SizedBox(height: 8),
              Text('Age: ${pet.age}'),
              const SizedBox(height: 8),
              Text('Weight: ${pet.weight}'),
              const SizedBox(height: 8),
              Text('Gender: ${pet.gender}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openPetOverview(pet);
              },
              child: const Text('Open Daily Overview'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Close',
                style: TextStyle(color: PawPulseTheme.primaryCyan),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboard() {
    final user = FirebaseAuth.instance.currentUser;

    final hasPet =
        isDataLoaded && errorMessage.isEmpty && usersPets.data.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: PawPulseTheme.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: PawPulseTheme.primaryCyan.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to PawPulse! 🐾',
                style: TextStyle(
                  color: PawPulseTheme.darkNavy,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Smart care for happy paws.',
                style: TextStyle(color: PawPulseTheme.darkNavy, fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Your Pet card with automatic 15-second profile sliding carousel.
        Card(
          color: PawPulseTheme.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: PawPulseTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Pet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (hasPet && usersPets.data.length > 1)
                      Text(
                        '${_currentCarouselIndex + 1} of ${usersPets.data.length}',
                        style: const TextStyle(
                          color: PawPulseTheme.primaryCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isDataLoaded)
                  const ListTile(
                    leading: CircularProgressIndicator(
                      color: PawPulseTheme.primaryCyan,
                    ),
                    title: Text('Loading pet information...'),
                  )
                else if (errorMessage.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.cloud_off, color: Colors.red),
                    title: const Text('Unable to load pet information'),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: callAPIandAssignData,
                    ),
                  )
                else if (usersPets.data.isEmpty)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: PawPulseTheme.primaryCyan,
                      child: Icon(Icons.pets, color: Colors.white),
                    ),
                    title: const Text('No pets added yet'),
                    subtitle: const Text('Add a pet to get started.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      setState(() {
                        selectedIndex = 1;
                      });
                    },
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        height: 72,
                        child: PageView.builder(
                          controller: _petCarouselController,
                          itemCount: usersPets.data.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentCarouselIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final pet = usersPets.data[index];
                            final petImage = _getPetImage(pet.petImage);

                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                // Clicking the profile takes the user to the "My Pets" tab
                                setState(() {
                                  selectedIndex = 1;
                                });
                              },
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: PawPulseTheme.turquoise,
                                    backgroundImage: petImage,
                                    child: petImage == null
                                        ? const Icon(
                                            Icons.pets,
                                            color: Colors.white,
                                            size: 26,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              pet.petName,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: PawPulseTheme.primaryCyan
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                pet.gender,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color.fromARGB(
                                                    255,
                                                    12,
                                                    142,
                                                    131,
                                                  ),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${pet.species} • ${pet.breed} • ${pet.age}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: PawPulseTheme.primaryCyan,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      if (usersPets.data.length > 1) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            usersPets.data.length,
                            (idx) => Container(
                              width: _currentCarouselIndex == idx ? 16 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: _currentCarouselIndex == idx
                                    ? PawPulseTheme.primaryCyan
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Today's Pet Care card.
        Card(
          color: PawPulseTheme.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: PawPulseTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Pet Care',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: PawPulseTheme.darkNavy,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'All Pets Overview ($_todayTotalCount task${_todayTotalCount == 1 ? '' : 's'})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: PawPulseTheme.secondaryGray,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AllPetsOverviewPage(
                              pets: isDataLoaded ? usersPets.data : [],
                            ),
                          ),
                        );
                        await _loadTodaySchedules();
                      },
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View All'),
                      style: TextButton.styleFrom(
                        foregroundColor: PawPulseTheme.primaryCyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingSchedules)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: PawPulseTheme.primaryCyan,
                      ),
                    ),
                  )
                else if (_todayTotalCount == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 40,
                            color: PawPulseTheme.primaryCyan
                                .withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No pending pet care tasks for today.',
                            style: TextStyle(
                              color: PawPulseTheme.secondaryGray,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: _buildDashboardScheduleItems(),
                  ),
                const Divider(height: 24),
                // Quick category navigation shortcuts
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _dashboardCategoryChip(
                        icon: Icons.restaurant,
                        label: 'Feeding (${_todayFeedings.length})',
                        pageIndex: 2,
                      ),
                      const SizedBox(width: 8),
                      _dashboardCategoryChip(
                        icon: Icons.directions_walk,
                        label: 'Routine (${_todayRoutines.length})',
                        pageIndex: 3,
                      ),
                      const SizedBox(width: 8),
                      _dashboardCategoryChip(
                        icon: Icons.medical_services,
                        label: 'Medicine (${_todayMedicines.length})',
                        pageIndex: 4,
                      ),
                      const SizedBox(width: 8),
                      _dashboardCategoryChip(
                        icon: Icons.favorite,
                        label: 'Health (${_todayHealth.length})',
                        pageIndex: 5,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Account card.
        Card(
          color: PawPulseTheme.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: PawPulseTheme.cardRadius),
          child: ListTile(
            leading: const Icon(
              Icons.account_circle,
              color: PawPulseTheme.primaryCyan,
            ),
            title: const Text('Signed in as'),
            subtitle: Text(user?.email ?? 'Unknown'),
          ),
        ),
      ],
    );
  }

  int get _todayTotalCount =>
      _todayFeedings.length +
      _todayRoutines.length +
      _todayMedicines.length +
      _todayHealth.length;

  Datum? _findPet(String petId) {
    if (!isDataLoaded) return null;
    for (final p in usersPets.data) {
      if (p.id == petId) return p;
    }
    return null;
  }

  List<Widget> _buildDashboardScheduleItems() {
    final List<_DashboardScheduleItem> items = [];

    for (final f in _todayFeedings) {
      items.add(_DashboardScheduleItem(
        id: f.id,
        petId: f.petId,
        title: f.mealName,
        time: f.scheduledTime,
        detail: f.amount.isNotEmpty ? f.amount : 'Feeding',
        category: 'feeding',
        icon: Icons.restaurant_rounded,
        isCompleted: f.isCompleted,
        onToggle: () => _toggleDashboardFeeding(f),
      ));
    }

    for (final r in _todayRoutines) {
      items.add(_DashboardScheduleItem(
        id: r.id,
        petId: r.petId,
        title: r.activityName,
        time: r.scheduledTime,
        detail: ActivityType.label(r.activityType),
        category: 'routine',
        icon: Icons.directions_walk_rounded,
        isCompleted: r.isCompleted,
        onToggle: () => _toggleDashboardRoutine(r),
      ));
    }

    for (final m in _todayMedicines) {
      items.add(_DashboardScheduleItem(
        id: m.id,
        petId: m.petId,
        title: m.medicineName,
        time: m.scheduledTime,
        detail: m.dosage.isNotEmpty ? m.dosage : 'Medicine',
        category: 'medicine',
        icon: Icons.medical_services_rounded,
        isCompleted: m.isAdministered,
        onToggle: () => _toggleDashboardMedicine(m),
      ));
    }

    for (final h in _todayHealth) {
      items.add(_DashboardScheduleItem(
        id: h.id,
        petId: h.petId,
        title: h.description.isNotEmpty
            ? h.description
            : HealthRecordType.label(h.recordType),
        time: h.recordDate,
        detail: HealthRecordType.label(h.recordType),
        category: 'health',
        icon: Icons.favorite_rounded,
        isCompleted: h.isCompleted,
        onToggle: () => _toggleDashboardHealth(h),
      ));
    }

    // Sort: Pending items first, then by time
    items.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return a.time.compareTo(b.time);
    });

    return items.map(_dashboardScheduleRow).toList();
  }

  Widget _dashboardScheduleRow(_DashboardScheduleItem item) {
    final pet = _findPet(item.petId);
    final petName = pet?.petName ?? 'Pet';
    final petImg = _getPetImage(pet?.petImage ?? '');

    final statusText = item.category == 'medicine'
        ? (item.isCompleted ? 'Given' : 'Pending')
        : (item.isCompleted ? 'Completed' : 'Pending');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: item.isCompleted ? Colors.grey.shade50 : PawPulseTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isCompleted
              ? Colors.grey.shade200
              : PawPulseTheme.primaryCyan.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: item.onToggle,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              item.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color:
                  item.isCompleted ? Colors.green : PawPulseTheme.primaryCyan,
              size: 24,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  decoration:
                      item.isCompleted ? TextDecoration.lineThrough : null,
                  color: item.isCompleted
                      ? PawPulseTheme.secondaryGray
                      : PawPulseTheme.darkNavy,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: PawPulseTheme.primaryCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 7,
                    backgroundImage: petImg,
                    backgroundColor: PawPulseTheme.primaryCyan,
                    child: petImg == null
                        ? const Icon(Icons.pets, size: 7, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    petName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: PawPulseTheme.darkNavy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: item.isCompleted
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: item.isCompleted
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
                  width: 0.8,
                ),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: item.isCompleted
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Icon(item.icon, size: 12, color: PawPulseTheme.secondaryGray),
            const SizedBox(width: 4),
            Text(
              item.time,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: PawPulseTheme.secondaryGray,
              ),
            ),
            if (item.detail.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '• ${item.detail}',
                style: const TextStyle(
                  fontSize: 11,
                  color: PawPulseTheme.secondaryGray,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dashboardCategoryChip({
    required IconData icon,
    required String label,
    required int pageIndex,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 15, color: PawPulseTheme.darkNavy),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: PawPulseTheme.darkNavy,
        ),
      ),
      backgroundColor: PawPulseTheme.lightCyan.withValues(alpha: 0.5),
      side: const BorderSide(color: PawPulseTheme.lightCyan),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: () {
        setState(() {
          selectedIndex = pageIndex;
        });
      },
    );
  }

  Future<void> _toggleDashboardFeeding(FeedingRecord f) async {
    try {
      await _feedingService.setCompleted(f.id, !f.isCompleted);
      await _loadTodaySchedules();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update feeding: $e')),
      );
    }
  }

  Future<void> _toggleDashboardRoutine(RoutineRecord r) async {
    try {
      await _routineService.setCompleted(r.id, !r.isCompleted);
      await _loadTodaySchedules();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update routine: $e')),
      );
    }
  }

  Future<void> _toggleDashboardMedicine(MedicineRecord m) async {
    try {
      await _medicineService.setAdministered(m.id, !m.isAdministered);
      await _loadTodaySchedules();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update medicine: $e')),
      );
    }
  }

  Future<void> _toggleDashboardHealth(HealthRecord h) async {
    try {
      await _healthService.setCompleted(h.id, !h.isCompleted);
      await _loadTodaySchedules();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update health event: $e')),
      );
    }
  }
}

class _DashboardScheduleItem {
  final String id;
  final String petId;
  final String title;
  final String time;
  final String detail;
  final String category;
  final IconData icon;
  final bool isCompleted;
  final VoidCallback onToggle;

  _DashboardScheduleItem({
    required this.id,
    required this.petId,
    required this.title,
    required this.time,
    required this.detail,
    required this.category,
    required this.icon,
    required this.isCompleted,
    required this.onToggle,
  });
}
