class TokenStorage {
  static String? _accessTokenId;
  static String? _accessToken;
  static String? _tokenType;

  static void setToken(String accessToken, String tokenType, String tokenID) {
    _accessToken = accessToken;
    _accessTokenId = tokenID;
    _tokenType = tokenType;
  }

  static String? getAccessToken() {
    return _accessToken;
  }

  static String? getTokenId() {
    return _accessTokenId;
  }

  static String? getTokenType() {
    return _tokenType;
  }

  static void clearToken() {
    _accessTokenId = null;
    _accessToken = null;
    _tokenType = null;
  }
}
