// Person model for relationship-level identity and contact details.
class Person {
  const Person({
    required this.id,
    required this.name,
    required this.relationship,
    this.phoneNumber,
    this.memo,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String relationship;
  final String? phoneNumber;
  final String? memo;
  final DateTime createdAt;

  Person copyWith({
    String? id,
    String? name,
    String? relationship,
    String? phoneNumber,
    String? memo,
    DateTime? createdAt,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'phoneNumber': phoneNumber,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      relationship: map['relationship'] as String? ?? '기타',
      phoneNumber: map['phoneNumber'] as String?,
      memo: map['memo'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
