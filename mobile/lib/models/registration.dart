class PendingRegistration {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime submittedAt;

  PendingRegistration({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.status,
    required this.submittedAt,
  });

  factory PendingRegistration.fromJson(Map<String, dynamic> json) {
    return PendingRegistration(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String,
      status: json['status'] as String? ?? 'pending',
      submittedAt: DateTime.parse(json['submitted_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'status': status,
      'submitted_at': submittedAt.toIso8601String(),
    };
  }
}
