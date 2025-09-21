class TokenStorage {
  static String? _accessToken;
  static String? _tokenType;

  static void setToken(String accessToken, String tokenType) {
    _accessToken = accessToken;
    _tokenType = tokenType;
  }

  static String? getAccessToken() {
    return _accessToken;
  }

  static String? getTokenType() {
    return _tokenType;
  }

  static void clearToken() {
    _accessToken = null;
    _tokenType = null;
  }
}
