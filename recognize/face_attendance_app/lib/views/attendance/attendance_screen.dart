import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../services/camera_service.dart';
import '../../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final CameraService _cameraService = CameraService();
  final ApiService _apiService = ApiService(baseUrl: 'http://localhost:5000'); // Update with your backend URL
  bool _isInitialized = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initialize();
      setState(() => _isInitialized = true);
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _captureAndProcess() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final image = await _cameraService.cameraController!.takePicture();
      final faces = await _cameraService.detectFaces(image.path);

      if (faces.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No face detected. Please try again.')),
        );
        return;
      }

      // Convert image to base64
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      // Send to backend for processing
      final success = await _apiService.markAttendance('current_employee_id', base64Image);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance marked successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark attendance. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Mark Attendance'),
      ),
      body: Column(
        children: [
          Expanded(
            child: CameraPreview(_cameraService.cameraController!),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isProcessing ? null : _captureAndProcess,
                  child: Text(_isProcessing ? 'Processing...' : 'Take Selfie'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to group photo screen
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => GroupPhotoScreen()));
                  },
                  child: Text('Group Photo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}