import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _accessTokenKey = 'access_token';
  static const String _accessTokenIdKey = 'access_token_id';
  static const String _tokenTypeKey = 'token_type';

  static Future<void> setToken(String accessToken, String tokenType, String tokenID) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_accessTokenIdKey, tokenID);
    await prefs.setString(_tokenTypeKey, tokenType);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  static Future<String?> getTokenId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenIdKey);
  }

  static Future<String?> getTokenType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenTypeKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_accessTokenIdKey);
    await prefs.remove(_tokenTypeKey);
  }
}
