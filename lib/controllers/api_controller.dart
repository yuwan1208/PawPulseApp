import 'package:flutter/services.dart';

import '../services/user_pets.dart';

class ApiController {
  /// Loads pet data from the local JSON asset file.
  ///
  /// Returns a [UsersPets] object parsed from `assets/user_pets.json`.
  /// If loading fails, returns a [UsersPets] with an empty data list
  /// and sets [errorMessage] with the error details.
  String errorMessage = '';

  Future<UsersPets> getDataFromAPI() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/user_pets.json');

      return usersPetsFromJson(jsonString);
    } catch (error) {
      errorMessage = error.toString();
      return UsersPets(data: []);
    }
  }
}
