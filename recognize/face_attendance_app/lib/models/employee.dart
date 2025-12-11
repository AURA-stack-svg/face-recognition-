class Employee {
  final String id;
  final String name;
  final String email;
  final String department;
  final String photoUrl;

  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.photoUrl,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      department: json['department'],
      photoUrl: json['photo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'department': department,
      'photo_url': photoUrl,
    };
  }
}