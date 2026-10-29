import 'dart:convert';

UsersPets usersPetsFromJson(String str) => UsersPets.fromJson(json.decode(str));

String usersPetsToJson(UsersPets data) => json.encode(data.toJson());

class UsersPets {
  UsersPets({
    required this.data,
  });

  final List<Datum> data;

  factory UsersPets.fromJson(Map<String, dynamic> json) {
    // Navigate into the nested "data" object
    final dataNode = json["data"] as Map<String, dynamic>?;
    
    // Extract the pets array
    final petsArray = dataNode?["pets"] as List<dynamic>? ?? [];
    
    // Extract the owner's name from the user object to display in the pet card
    final ownerName = dataNode?["user"]?["displayName"] ?? "Pet Owner";

    return UsersPets(
      data: petsArray
          .map((pet) => Datum.fromJson(pet as Map<String, dynamic>, ownerName))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        "data": {
          "pets": List<dynamic>.from(data.map((x) => x.toJson())),
        }
      };
}

class Datum {
  Datum({
    required this.id,
    required this.userName,
    required this.petName,
    required this.petImage,
    required this.isFriendly,
    required this.species,
    required this.breed,
    required this.age,
    required this.weight,
    required this.gender,
  });

  // Updated to String since the new JSON uses IDs like "pet_101"
  final String id;
  final String userName;
  final String petName;
  final String petImage;
  final bool isFriendly;
  
  final String species;
  final String breed;
  final String age;
  final String weight;
  final String gender;

  factory Datum.fromJson(Map<String, dynamic> json, String ownerName) => Datum(
      id: json["id"]?.toString() ?? "0",
      userName: ownerName, // Applied from the parent "user" object
      petName: json["name"] ?? "Unknown",
      petImage: json["avatarUrl"] ?? "",
      isFriendly: true, // Defaulting to true since it's removed from the new JSON
      
      species: json["species"] ?? "Unknown",
      breed: json["breed"] ?? "Unknown",
      // Convert the integer and double from the JSON into readable strings for the UI
      age: "${json["ageYears"] ?? 0} years", 
      weight: "${json["weightKg"] ?? 0} kg",
      gender: json["gender"] ?? "Unknown",
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": petName,
        "avatarUrl": petImage,
        "species": species,
        "breed": breed,
        "gender": gender,
      };
}