// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:face_attendance_app/services/api_service.dart';
import 'package:face_attendance_app/providers/attendance_provider.dart';
import 'package:face_attendance_app/views/auth/login_screen.dart';
import 'package:face_attendance_app/views/admin/admin_dashboard.dart';
import 'package:face_attendance_app/views/attendance/attendance_screen.dart';

void main() {
  setUp(() async {
    // Set up a mock SharedPreferences instance
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
  });

  testWidgets('Login screen shows email and password fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => AttendanceProvider(
              ApiService(baseUrl: 'http://localhost:5000'),
            ),
          ),
        ],
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verify that the login form fields are present
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Admin login navigates to admin dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => AttendanceProvider(
              ApiService(baseUrl: 'http://localhost:5000'),
            ),
          ),
        ],
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Enter admin credentials
    await tester.enterText(
      find.byType(TextFormField).first,
      'admin@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'password123',
    );

    // Submit the form
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    // Verify navigation to admin dashboard
    expect(find.byType(AdminDashboard), findsOneWidget);
  });

  testWidgets('Employee login navigates to attendance screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => AttendanceProvider(
              ApiService(baseUrl: 'http://localhost:5000'),
            ),
          ),
        ],
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Enter employee credentials
    await tester.enterText(
      find.byType(TextFormField).first,
      'employee@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'password123',
    );

    // Submit the form
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    // Verify navigation to attendance screen
    expect(find.byType(AttendanceScreen), findsOneWidget);
  });
}
