import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';
import '../../providers/attendance_provider.dart';
import '../../services/api_service.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService _apiService = ApiService(baseUrl: 'http://localhost:5000');
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  String _selectedDepartment = 'All';

  Future<void> _uploadEmployeePhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null) return;

      setState(() => _isLoading = true);

      for (var file in result.files) {
        if (file.bytes != null) {
          final base64Image = base64Encode(file.bytes!);
          await _apiService.uploadEmployeePhoto('new_employee_id', base64Image);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photos uploaded successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading photos: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportReport() async {
    // Implement report export logic
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.file_upload),
            onPressed: _uploadEmployeePhoto,
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _exportReport,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${_selectedDate.toLocal()}'.split(' ')[0]),
                                Icon(Icons.calendar_today),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Gap(8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Department',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedDepartment,
                          items: ['All', 'IT', 'HR', 'Finance']
                              .map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() => _selectedDepartment = newValue);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Consumer<AttendanceProvider>(
                    builder: (context, AttendanceProvider provider, Widget? child) {
                      if (provider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final employees = provider.employees;
                      if (employees.isEmpty) {
                        return const Center(child: Text('No employees found'));
                      }

                      return ListView.builder(
                        itemCount: employees.length,
                        itemBuilder: (context, index) {
                          final employee = employees[index];
                          return Card(
                            margin: EdgeInsets.all(8),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(employee.name[0]),
                              ),
                              title: Text(employee.name),
                              subtitle: Text(employee.department),
                              trailing: Text('Present'), // Replace with actual status
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}