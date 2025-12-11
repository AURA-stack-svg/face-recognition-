import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/employee.dart';
import '../models/attendance.dart';

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<List<Employee>> getEmployees() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/employees'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Employee.fromJson(json)).toList();
      }
      throw Exception('Failed to load employees');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<bool> markAttendance(String employeeId, String imageBase64) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/mark-attendance'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'employee_id': employeeId,
          'image': imageBase64,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error marking attendance: $e');
    }
  }

  Future<bool> processGroupPhoto(String imageBase64) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/process-group-photo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image': imageBase64,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error processing group photo: $e');
    }
  }

  Future<List<Attendance>> getAttendanceHistory(String employeeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attendance-history/$employeeId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Attendance.fromJson(json)).toList();
      }
      throw Exception('Failed to load attendance history');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<bool> uploadEmployeePhoto(String employeeId, String imageBase64) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/upload-employee-photo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'employee_id': employeeId,
          'image': imageBase64,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error uploading employee photo: $e');
    }
  }
}