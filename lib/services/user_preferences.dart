class UserPreferences {
  static String? _playerName;

  static Future<String?> getPlayerName() async => _playerName;

  static Future<void> setPlayerName(String name) async {
    _playerName = name;
  }
}
