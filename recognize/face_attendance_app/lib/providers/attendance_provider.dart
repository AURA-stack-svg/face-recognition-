import 'package:flutter/foundation.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';

class AttendanceProvider with ChangeNotifier {
  final ApiService _apiService;
  List<Attendance> _attendanceHistory = [];
  List<Employee> _employees = [];
  Employee? _currentEmployee;
  bool _isLoading = false;

  AttendanceProvider(this._apiService);

  List<Attendance> get attendanceHistory => _attendanceHistory;
  List<Employee> get employees => _employees;
  Employee? get currentEmployee => _currentEmployee;
  bool get isLoading => _isLoading;

  void setCurrentEmployee(Employee employee) {
    _currentEmployee = employee;
    notifyListeners();
  }

  Future<void> loadEmployees() async {
    _isLoading = true;
    notifyListeners();

    try {
      _employees = await _apiService.getEmployees();
    } catch (e) {
      print('Error loading employees: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAttendanceHistory(String employeeId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _attendanceHistory = await _apiService.getAttendanceHistory(employeeId);
    } catch (e) {
      print('Error loading attendance history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markAttendance(String employeeId, String imageBase64) async {
    try {
      final success = await _apiService.markAttendance(employeeId, imageBase64);
      if (success) {
        await loadAttendanceHistory(employeeId);
      }
      return success;
    } catch (e) {
      print('Error marking attendance: $e');
      return false;
    }
  }
}