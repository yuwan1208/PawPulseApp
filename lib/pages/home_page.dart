import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../controllers/api_controller.dart';
import '../services/user_pets.dart';
import 'all_pets_overview_page.dart';
import 'pet_details_page.dart';
import 'feeding_schedule_page.dart';
import 'routine_schedule_page.dart';
import 'medicine_schedule_page.dart';
import 'health_history_page.dart';

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
  }

  @override
  void dispose() {
    _petCarouselTimer?.cancel();
    _petCarouselController?.dispose();
    super.dispose();
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
      _petCarouselTimer =
          Timer.periodic(const Duration(seconds: 15), (timer) {
        if (!mounted || usersPets.data.isEmpty) return;
        if (_petCarouselController != null &&
            _petCarouselController!.hasClients) {
          final nextIndex =
              (_currentCarouselIndex + 1) % usersPets.data.length;
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
  }

  // Open the Add Pet form.
  Future<void> showAddPetMessage() async {
    await _showPetFormDialog();
  }

  // Add or edit a pet.
  Future<void> _showPetFormDialog({Datum? pet}) async {
    final formKey = GlobalKey<FormState>();

    final nameController =
        TextEditingController(text: pet?.petName ?? '');
    final speciesController =
        TextEditingController(text: pet?.species ?? '');
    final breedController =
        TextEditingController(text: pet?.breed ?? '');
    final cleanAge =
        (pet?.age ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final ageController = TextEditingController(text: cleanAge);
    final cleanWeight =
        (pet?.weight ?? '').replaceAll(RegExp(r'[^0-9.]'), '');
    final weightController = TextEditingController(text: cleanWeight);
    final genderController =
        TextEditingController(text: pet?.gender ?? '');

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
                    _petInput(
                      ageController,
                      'Age in years',
                      number: true,
                    ),
                    _petInput(
                      weightController,
                      'Weight in kg',
                      number: true,
                    ),
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
                  backgroundColor:
                      const Color.fromARGB(255, 37, 214, 199),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;

                  final age =
                      int.tryParse(ageController.text.trim());
                  final weight =
                      double.tryParse(weightController.text.trim());

                  if (age == null ||
                      weight == null ||
                      age < 0 ||
                      weight < 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Enter a valid age and weight.',
                        ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operation failed: $error')),
      );
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
          content: Text(
            'Are you sure you want to delete ${pet.petName}?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
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
        SnackBar(
          content: Text('${pet.petName} deleted successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }

  // Supports local asset images and online image URLs.
  ImageProvider? _getPetImage(String imagePath) {
    if (imagePath.isEmpty) return null;

    if (imagePath.startsWith('http://') ||
        imagePath.startsWith('https://')) {
      return NetworkImage(imagePath);
    }

    return AssetImage(imagePath);
  }

  void _openPetOverview(Datum pet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetDetailsPage(pet: pet),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 37, 214, 199),
        title: Text(pageTitles[selectedIndex]),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (selectedIndex <= 1) {
                callAPIandAssignData();
              } else {
                setState(() {});
              }
            },
          ),
        ],
      ),

      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 37, 214, 199),
              ),
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

      body: _buildPageContent(),

      floatingActionButton: (selectedIndex == 0 || selectedIndex == 1)
          ? FloatingActionButton(
              onPressed: showAddPetMessage,
              backgroundColor: const Color.fromARGB(255, 37, 214, 199),
              tooltip: 'Add Pet',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _drawerItem(int index, IconData icon, String title) {
    return ListTile(
      leading: Icon(
        icon,
        color: const Color.fromARGB(255, 37, 214, 199),
      ),
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
        child: CircularProgressIndicator(
          color: Color.fromARGB(255, 37, 214, 199),
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load pets from Firestore',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(
                errorMessage,
                textAlign: TextAlign.center,
              ),
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
                borderSide: const BorderSide(
                  color: Color.fromARGB(255, 37, 214, 199),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
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
          backgroundColor: const Color.fromARGB(255, 37, 214, 199),
          backgroundImage: petImage,
          child: petImage == null
              ? const Icon(Icons.pets, color: Colors.white)
              : null,
        ),
        title: Text(
          pet.petName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${pet.species} • ${pet.breed}\nOwner: ${pet.userName}',
        ),
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
                  Icon(Icons.calendar_today,
                      color: Color.fromARGB(255, 37, 214, 199)),
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
                backgroundColor:
                    const Color.fromARGB(255, 37, 214, 199),
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
                style: TextStyle(
                  color: Color.fromARGB(255, 37, 214, 199),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboard() {
    final user = FirebaseAuth.instance.currentUser;

    final hasPet = isDataLoaded &&
        errorMessage.isEmpty &&
        usersPets.data.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Welcome to PawPulse! 🐾',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Smart care for happy paws.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),

        // Your Pet card with automatic 15-second profile sliding carousel.
        Card(
          color: Colors.white,
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
                          color: Color.fromARGB(255, 37, 214, 199),
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
                      color: Color.fromARGB(255, 37, 214, 199),
                    ),
                    title: Text('Loading pet information...'),
                  )
                else if (errorMessage.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.cloud_off,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Unable to load pet information',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: callAPIandAssignData,
                    ),
                  )
                else if (usersPets.data.isEmpty)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor:
                          Color.fromARGB(255, 37, 214, 199),
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
                                    backgroundColor: const Color.fromARGB(
                                        255, 10, 246, 226),
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
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color.fromARGB(
                                                        255, 37, 214, 199)
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                pet.gender,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color.fromARGB(
                                                      255, 12, 142, 131),
                                                  fontWeight:
                                                      FontWeight.bold,
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
                                    color:
                                        Color.fromARGB(255, 37, 214, 199),
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
                                    ? const Color.fromARGB(255, 37, 214, 199)
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
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Today\'s Pet Care',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AllPetsOverviewPage(
                              pets: isDataLoaded ? usersPets.data : [],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View All'),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            const Color.fromARGB(255, 37, 214, 199),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.restaurant,
                    color: Color.fromARGB(255, 37, 214, 199),
                  ),
                  title: const Text('Feeding Schedule'),
                  subtitle: const Text('View and manage daily meals across all pets'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    setState(() {
                      selectedIndex = 2;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.directions_walk,
                    color: Color.fromARGB(255, 37, 214, 199),
                  ),
                  title: const Text('Routine Schedule'),
                  subtitle: const Text('Daily walks, grooming & exercises across all pets'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    setState(() {
                      selectedIndex = 3;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.medical_services,
                    color: Color.fromARGB(255, 37, 214, 199),
                  ),
                  title: const Text('Medicine Schedule'),
                  subtitle: const Text('Prescription doses & administration across all pets'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    setState(() {
                      selectedIndex = 4;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.favorite,
                    color: Color.fromARGB(255, 37, 214, 199),
                  ),
                  title: const Text('Health History'),
                  subtitle: const Text('Vet visits, vaccines & checkups across all pets'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    setState(() {
                      selectedIndex = 5;
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Account card.
        Card(
          color: Colors.white,
          child: ListTile(
            leading: const Icon(
              Icons.account_circle,
              color: Color.fromARGB(255, 37, 214, 199),
            ),
            title: const Text('Signed in as'),
            subtitle: Text(user?.email ?? 'Unknown'),
          ),
        ),
      ],
    );
  }
}
