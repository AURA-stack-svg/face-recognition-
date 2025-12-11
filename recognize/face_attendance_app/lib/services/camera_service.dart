import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// dart:io no longer needed (using InputImage.fromFilePath)

class CameraService {
  CameraController? _cameraController;
  CameraDescription? _cameraDescription;

  FaceDetector? _faceDetector;
  bool _isProcessing = false;

  CameraController? get cameraController => _cameraController;

  Future<void> initialize() async {
    if (_cameraDescription == null) {
      final cameras = await availableCameras();
      final firstCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraDescription = firstCamera;
    }

    _cameraController = CameraController(
      _cameraDescription!,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    // Use the modular google_mlkit_face_detection API: instantiate FaceDetector
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
      ),
    );
  }

  Future<List<Face>> detectFaces(String imagePath) async {
    if (_isProcessing) return [];
    _isProcessing = true;

    try {
  // prefer fromFilePath for a simple path-based API
  final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector?.processImage(inputImage) ?? [];
      return faces;
    } catch (e) {
      print('Error detecting faces: $e');
      return [];
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.close();
  }
}