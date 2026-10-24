import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/review_message.dart';
import '../../domain/entities/review_request.dart';
import '../../domain/entities/review_status.dart';
import '../../domain/entities/vet_profile.dart';
import '../../domain/repositories/vet_review_repository.dart';

/// Firestore implementation of [VetReviewRepository] complying with SRS Section 4, 5, and 7.
class FirestoreVetReviewRepository implements VetReviewRepository {
  final FirebaseFirestore? _firestore;

  FirestoreVetReviewRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _requestsCol =>
      _db.collection('reviewRequests');

  @override
  Future<List<VetProfile>> getRegisteredVeterinarians() async {
    try {
      final snapshot =
          await _usersCol.where('role', isEqualTo: 'veterinarian').get();
      return snapshot.docs
          .map((doc) => VetProfile.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      // Return empty list on failure or permissions
      return [];
    }
  }

  @override
  Future<String> submitReviewRequest(ReviewRequest request) async {
    final docRef = _requestsCol.doc();
    final data = request.toMap(useTimestamps: true);
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['lastMessageAt'] = null;

    await docRef.set(data);
    return docRef.id;
  }

  @override
  Stream<List<ReviewRequest>> streamFarmerRequests(String farmerUid) {
    if (farmerUid.trim().isEmpty) {
      return Stream.value(const []);
    }

    return _requestsCol
        .where('farmerUid', isEqualTo: farmerUid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ReviewRequest.fromMap(doc.data(), doc.id))
              .toList();
          // Sort descending by createdAt
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  @override
  Stream<List<ReviewRequest>> streamVeterinarianRequests(
    String veterinarianUid, {
    ReviewStatus? statusFilter,
  }) {
    if (veterinarianUid.trim().isEmpty) {
      return Stream.value(const []);
    }

    Query<Map<String, dynamic>> query = _requestsCol.where(
      'veterinarianUid',
      isEqualTo: veterinarianUid,
    );

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.value);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ReviewRequest.fromMap(doc.data(), doc.id))
          .toList();
      // Sort descending by createdAt
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Stream<ReviewRequest?> streamRequestById(String requestId) {
    if (requestId.trim().isEmpty) {
      return Stream.value(null);
    }
    return _requestsCol.doc(requestId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ReviewRequest.fromMap(doc.data()!, doc.id);
    });
  }

  @override
  Stream<List<ReviewMessage>> streamMessages(String requestId) {
    if (requestId.trim().isEmpty) {
      return Stream.value(const []);
    }

    return _requestsCol
        .doc(requestId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ReviewMessage.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return list;
        });
  }

  @override
  Future<void> sendMessage({
    required String requestId,
    required String senderUid,
    required String senderRole,
    required String text,
    required ReviewStatus currentStatus,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message text cannot be empty or whitespace only.');
    }
    if (trimmed.length > 2000) {
      throw ArgumentError('Message text exceeds maximum 2000 characters limit.');
    }
    if (currentStatus == ReviewStatus.closed) {
      throw StateError('Cannot send a message to a closed review request.');
    }

    final requestDocRef = _requestsCol.doc(requestId);
    final messagesColRef = requestDocRef.collection('messages');
    final newMessageRef = messagesColRef.doc();

    // Determine lifecycle status transition according to Section 4.6 & 4.7
    String? nextStatusValue;
    final normalizedRole = senderRole.toLowerCase();

    if (normalizedRole == 'farmer') {
      if (currentStatus == ReviewStatus.responded) {
        nextStatusValue = ReviewStatus.inReview.value;
      }
    } else if (normalizedRole == 'veterinarian') {
      if (currentStatus == ReviewStatus.pending ||
          currentStatus == ReviewStatus.inReview) {
        nextStatusValue = ReviewStatus.responded.value;
      }
    }

    // Atomic batch write
    final batch = _db.batch();

    // 1. Add message document
    batch.set(newMessageRef, {
      'senderUid': senderUid,
      'senderRole': normalizedRole,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Update request document
    final Map<String, dynamic> requestUpdates = {
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    };
    if (nextStatusValue != null) {
      requestUpdates['status'] = nextStatusValue;
    }
    batch.update(requestDocRef, requestUpdates);

    await batch.commit();
  }

  @override
  Future<void> closeReviewRequest({
    required String requestId,
    required String veterinarianUid,
  }) async {
    final docRef = _requestsCol.doc(requestId);
    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Review request not found.');
    }
    final data = snapshot.data()!;
    final assignedVet = data['veterinarianUid'] as String? ?? '';
    if (assignedVet != veterinarianUid) {
      throw StateError('Only the assigned veterinarian can close this request.');
    }

    final currentStatus = ReviewStatus.fromString(data['status'] as String?);
    if (currentStatus == ReviewStatus.closed) {
      return; // Already closed
    }

    await docRef.update({
      'status': ReviewStatus.closed.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
