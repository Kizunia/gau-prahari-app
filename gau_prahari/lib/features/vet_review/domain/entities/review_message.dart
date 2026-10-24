import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain entity representing a single append-only message within a review request thread.
class ReviewMessage {
  final String id;
  final String senderUid;
  final String senderRole; // 'farmer' or 'veterinarian'
  final String text;
  final DateTime createdAt;

  const ReviewMessage({
    required this.id,
    required this.senderUid,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  bool get isFarmer => senderRole.toLowerCase() == 'farmer';
  bool get isVeterinarian => senderRole.toLowerCase() == 'veterinarian';

  factory ReviewMessage.fromMap(Map<String, dynamic> data, String id) {
    DateTime parsedDate;
    final rawDate = data['createdAt'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return ReviewMessage(
      id: id,
      senderUid: data['senderUid'] as String? ?? '',
      senderRole: data['senderRole'] as String? ?? 'farmer',
      text: data['text'] as String? ?? '',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderUid': senderUid,
      'senderRole': senderRole,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ReviewMessage copyWith({
    String? id,
    String? senderUid,
    String? senderRole,
    String? text,
    DateTime? createdAt,
  }) {
    return ReviewMessage(
      id: id ?? this.id,
      senderUid: senderUid ?? this.senderUid,
      senderRole: senderRole ?? this.senderRole,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
