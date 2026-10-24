import '../entities/review_message.dart';
import '../entities/review_request.dart';
import '../entities/review_status.dart';
import '../entities/vet_profile.dart';

/// Abstract repository defining the contract for Farmer-Veterinarian reviews and messaging.
abstract class VetReviewRepository {
  /// Fetches the directory of registered veterinarians available for consultations.
  Future<List<VetProfile>> getRegisteredVeterinarians();

  /// Submits an immutable review request to Firestore.
  /// Returns the newly generated request document ID.
  Future<String> submitReviewRequest(ReviewRequest request);

  /// Streams requests created by the specified farmer in real time.
  Stream<List<ReviewRequest>> streamFarmerRequests(String farmerUid);

  /// Streams requests assigned to the specified veterinarian in real time.
  /// Optionally filtered by [statusFilter].
  Stream<List<ReviewRequest>> streamVeterinarianRequests(
    String veterinarianUid, {
    ReviewStatus? statusFilter,
  });

  /// Streams a single review request by its unique document ID.
  Stream<ReviewRequest?> streamRequestById(String requestId);

  /// Streams the chronological append-only message thread for a request.
  Stream<List<ReviewMessage>> streamMessages(String requestId);

  /// Appends a new message to the request's thread and executes the appropriate status transition.
  Future<void> sendMessage({
    required String requestId,
    required String senderUid,
    required String senderRole,
    required String text,
    required ReviewStatus currentStatus,
  });

  /// Closes an open review request. Terminal operation permitted only for the assigned veterinarian.
  Future<void> closeReviewRequest({
    required String requestId,
    required String veterinarianUid,
  });
}
