import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userTypeKey = 'user_type';
  static const String _employeeIdKey = 'employee_id';

  final SharedPreferences _prefs;

  AuthService(this._prefs);

  static Future<AuthService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthService(prefs);
  }

  Future<void> saveAuthToken(String token) async {
    await _prefs.setString(_tokenKey, token);
  }

  Future<void> saveUserType(String userType) async {
    await _prefs.setString(_userTypeKey, userType);
  }

  Future<void> saveEmployeeId(String employeeId) async {
    await _prefs.setString(_employeeIdKey, employeeId);
  }

  String? getAuthToken() {
    return _prefs.getString(_tokenKey);
  }

  String? getUserType() {
    return _prefs.getString(_userTypeKey);
  }

  String? getEmployeeId() {
    return _prefs.getString(_employeeIdKey);
  }

  bool isLoggedIn() {
    return getAuthToken() != null;
  }

  bool isAdmin() {
    return getUserType() == 'admin';
  }

  Future<void> logout() async {
    await Future.wait([
      _prefs.remove(_tokenKey),
      _prefs.remove(_userTypeKey),
      _prefs.remove(_employeeIdKey),
    ]);
  }
}