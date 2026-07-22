class Participant {
  final int id;
  final String username;
  final String role;
  final String fullName;
  final String storeCode;
  final String city;
  final String designation;
  final String department;
  final String createdAt;
  final int subordinateCount;

  Participant({
    required this.id,
    required this.username,
    required this.role,
    required this.fullName,
    required this.storeCode,
    required this.city,
    required this.designation,
    required this.department,
    required this.createdAt,
    required this.subordinateCount,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username'] ?? '',
      role: json['role'] ?? 'participant',
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      storeCode: json['store_code'] ?? json['storeCode'] ?? '',
      city: json['city'] ?? '',
      designation: json['designation'] ?? '',
      department: json['department'] ?? '',
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
      subordinateCount: json['subordinate_count'] is int ? json['subordinate_count'] : int.tryParse(json['subordinate_count']?.toString() ?? '0') ?? 0,
    );
  }
}
