import 'dart:convert';

class Tag {
  final String id;
  final String blockPoint;
  final String addedBy;
  final DateTime addedAt;

  Tag({
    required this.id,
    required this.blockPoint,
    required this.addedBy,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'blockPoint': blockPoint,
      'addedBy': addedBy,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] ?? '',
      blockPoint: map['blockPoint'] ?? '',
      addedBy: map['addedBy'] ?? '',
      addedAt: DateTime.parse(map['addedAt']),
    );
  }
}

class ServiceOrder {
  final String id;
  String status;
  final String createdBy;
  final DateTime createdAt;
  final List<Tag> tags;

  ServiceOrder({
    required this.id,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    List<Tag>? tags,
  }) : tags = tags ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'tags': tags.map((x) => x.toMap()).toList(),
    };
  }

  factory ServiceOrder.fromMap(Map<String, dynamic> map) {
    return ServiceOrder(
      id: map['id'] ?? '',
      status: map['status'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      tags: List<Tag>.from(map['tags']?.map((x) => Tag.fromMap(x)) ?? []),
    );
  }

  String toJson() => json.encode(toMap());

  factory ServiceOrder.fromJson(String source) =>
      ServiceOrder.fromMap(json.decode(source));
}
