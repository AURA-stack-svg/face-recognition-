import 'package:intl/intl.dart';

class Attendance {
  final String id;
  final String employeeId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String status;
  final String? photoUrl;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.photoUrl,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      employeeId: json['employee_id'],
      checkInTime: DateTime.parse(json['check_in_time']),
      checkOutTime: json['check_out_time'] != null 
        ? DateTime.parse(json['check_out_time'])
        : null,
      status: json['status'],
      photoUrl: json['photo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'check_in_time': checkInTime.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'status': status,
      'photo_url': photoUrl,
    };
  }

  String get formattedCheckInTime => 
      DateFormat('yyyy-MM-dd HH:mm:ss').format(checkInTime);

  String get formattedCheckOutTime => checkOutTime != null
      ? DateFormat('yyyy-MM-dd HH:mm:ss').format(checkOutTime!)
      : 'Not checked out';
}