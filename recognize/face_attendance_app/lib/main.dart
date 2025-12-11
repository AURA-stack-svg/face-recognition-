import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'views/auth/login_screen.dart';
import 'providers/attendance_provider.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = await AuthService.create();
  runApp(MyApp(authService: authService));
}

class MyApp extends StatelessWidget {
  final AuthService authService;

  const MyApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AttendanceProvider(
            ApiService(baseUrl: 'http://localhost:5000'), // Update with your backend URL
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Face Attendance',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: LoginScreen(),
      ),
    );
  }
}


