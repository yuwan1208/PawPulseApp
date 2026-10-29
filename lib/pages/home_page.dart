
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../controllers/api_controller.dart';
import '../services/user_pets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  // API State Variables
  late UsersPets usersPets;
  bool isDataLoaded = false;
  String errorMessage = '';

  // Controller for loading pet data
  final ApiController _apiController = ApiController();

  final List<String> pageTitles = [
    'Dashboard',
    'My Pets',
    'Feeding Schedule',
    'Routine Schedule',
    'Medicine Schedule',
    'Health History',
  ];

  Future<void> callAPIandAssignData() async {
    final result = await _apiController.getDataFromAPI();

    if (!mounted) return;

    setState(() {
      usersPets = result;
      errorMessage = _apiController.errorMessage;
      isDataLoaded = true;
    });
  }

  @override
  void initState() {
    super.initState();
    callAPIandAssignData();
  }

  void selectPage(int index) {
    setState(() {
      selectedIndex = index;
    });

    Navigator.pop(context);
  }

  void showAddPetMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add Pet selected'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,

      // APP BAR
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 37, 214, 199),
        title: Text(pageTitles[selectedIndex]),
        centerTitle: true,
      ),

      // NAVIGATION DRAWER
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
                child: Icon(
                  Icons.pets,
                  size: 30,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.dashboard,
                color: Color.fromARGB(255, 37, 214, 199),
              ),
              title: const Text('Dashboard'),
              selected: selectedIndex == 0,
              onTap: () => selectPage(0),
            ),
            ListTile(
              leading: const Icon(
                Icons.pets,
                color: Color.fromARGB(255, 37, 214, 199),
              ),
              title: const Text('My Pets'),
              selected: selectedIndex == 1,
              onTap: () => selectPage(1),
            ),
            ListTile(
              leading: const Icon(
                Icons.restaurant,
                color: Color.fromARGB(255, 37, 214, 199),
              ),
              title: const Text('Feeding Schedule'),
              selected: selectedIndex == 2,
              onTap: () => selectPage(2),
            ),
            ListTile(
              leading: const Icon(
                Icons.directions_walk,
                color: Color.fromARGB(255, 37, 214, 199),
              ),
              title: const Text('Routine Schedule'),
              selected: selectedIndex == 3,
              onTap: () => selectPage(3),
            ),
            ListTile(
              leading: const Icon(
                Icons.medical_services,
                color: Color.fromARGB(255, 37, 214, 199),
              ),
              title: const Text('Medicine Schedule'),
              selected: selectedIndex == 4,
              onTap: () => selectPage(4),
            ),
            ListTile(
              leading: const Icon(
                Icons.favorite,
                color: Color.fromARGB(255, 37, 214, 199),
              ),
              title: const Text('Health History'),
              selected: selectedIndex == 5,
              onTap: () => selectPage(5),
            ),
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

      // PAGE CONTENT
      body: _buildPageContent(),

      // FLOATING ACTION BUTTON
      floatingActionButton: FloatingActionButton(
        onPressed: showAddPetMessage,
        backgroundColor: const Color.fromARGB(255, 37, 214, 199),
        tooltip: 'Add Pet',
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

  // PAGE SWITCHING
  Widget _buildPageContent() {
    switch (selectedIndex) {
      case 0:
        return _buildDashboard();

      case 1:
        return _buildPetsFromAPI();

      case 2:
        return _buildSimplePage(
          'Feeding Schedule',
          Icons.restaurant,
          'Check your pets\' feeding schedules.',
        );

      case 3:
        return _buildSimplePage(
          'Routine Schedule',
          Icons.directions_walk,
          'Keep track of your pets\' daily routines.',
        );

      case 4:
        return _buildSimplePage(
          'Medicine Schedule',
          Icons.medical_services,
          'Keep track of scheduled medicines.',
        );

      case 5:
        return _buildSimplePage(
          'Health History',
          Icons.favorite,
          'View your pets\' health history.',
        );

      default:
        return _buildDashboard();
    }
  }

  // DYNAMIC MY PETS LIST
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
        child: Text(errorMessage),
      );
    }

    if (usersPets.data.isEmpty) {
      return const Center(
        child: Text('No Pet Data Found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: usersPets.data.length,
      itemBuilder: (context, index) => _getPetRow(index),
    );
  }

  // PET ITEM ROW
  Widget _getPetRow(int index) {
    final pet = usersPets.data[index];

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          radius: 21,
          backgroundColor: const Color.fromARGB(255, 37, 214, 199),
          backgroundImage: NetworkImage(pet.petImage),
        ),
        title: Text(
          pet.petName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Owner: ${pet.userName}'),
        trailing: Icon(
          pet.isFriendly ? Icons.pets : Icons.do_not_touch,
          color: pet.isFriendly ? Colors.green : Colors.red,
        ),
        onTap: () => _showPetDetailsDialog(context, pet),
      ),
    );
  }

  // PET DETAILS DIALOG
  void _showPetDetailsDialog(BuildContext context, Datum pet) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(pet.petImage),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(pet.petName),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              Text(
                'Species: ${pet.species}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Breed: ${pet.breed}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Age: ${pet.age}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Weight: ${pet.weight}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Gender: ${pet.gender}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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

  // DASHBOARD
  Widget _buildDashboard() {
    final user = FirebaseAuth.instance.currentUser;

    // Use the first pet in the JSON data for the dashboard summary.
    final hasPet = isDataLoaded && usersPets.data.isNotEmpty;
    final pet = hasPet ? usersPets.data[0] : null;

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

        // CONTAINMENT WIDGET 1: YOUR PET
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Pet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ListTile(
                  // SHOW THE PET AVATAR INSTEAD OF THE PAW ICON
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        const Color.fromARGB(255, 10, 246, 226),
                    backgroundImage:
                        pet != null ? NetworkImage(pet.petImage) : null,
                    child: pet == null
                        ? const Icon(
                            Icons.pets,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  title: Text(
                    pet?.petName ?? 'Buddy',
                  ),
                  subtitle: Text(
                    pet != null
                        ? '${pet.species} • ${pet.age}'
                        : 'Dog • 3 years old',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Color.fromARGB(255, 37, 214, 199),
                  ),
                  onTap: () {
                    setState(() {
                      selectedIndex = 1;
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // CONTAINMENT WIDGET 2: TODAY'S PET CARE
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Pet Care',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const ListTile(
                  leading: Icon(
                    Icons.restaurant,
                    color: Color.fromARGB(255, 37, 214, 199),
                  ),
                  title: Text('Feeding'),
                  subtitle: Text('Next feeding: 6:00 PM'),
                ),
                const ListTile(
                  leading: Icon(
                    Icons.directions_walk,
                    color: Color.fromARGB(255, 37, 214, 199),
                  ),
                  title: Text('Routine'),
                  subtitle: Text('Daily walk: 5:00 PM'),
                ),
                const ListTile(
                  leading: Icon(
                    Icons.medical_services,
                    color: Color.fromARGB(255, 37, 214, 199),
                  ),
                  title: Text('Medicine'),
                  subtitle: Text('Next medicine: 8:00 PM'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ACCOUNT CARD
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

  // SIMPLE PLACEHOLDER PAGE
  Widget _buildSimplePage(
    String title,
    IconData icon,
    String description,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 64,
                  color: const Color.fromARGB(255, 2, 244, 244),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
