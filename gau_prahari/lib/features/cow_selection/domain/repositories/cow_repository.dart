import '../entities/cow.dart';

/// Repository interface for retrieving registered dairy cattle.
abstract class CowRepository {
  /// Look up a cow by its ID (e.g., 'COW-104') or RFID Tag (e.g., 'RFID-9821').
  Future<Cow?> getCowById(String query);

  /// Get list of all registered cows (catalog + user-added).
  Future<List<Cow>> getAllCows();

  /// Save a cow (add new or update existing).
  Future<void> saveCow(Cow cow);

  /// Delete a user-added cow by ID. Returns true if deleted.
  Future<bool> deleteCow(String id);

  /// Update the name of an existing cow. Returns the updated cow.
  Future<Cow?> updateCowName(String id, String? name);
}
