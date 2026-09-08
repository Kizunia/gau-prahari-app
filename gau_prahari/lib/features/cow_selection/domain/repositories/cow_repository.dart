import '../entities/cow.dart';

/// Repository interface for retrieving registered dairy cattle.
abstract class CowRepository {
  /// Look up a cow by its ID (e.g., 'COW-104') or RFID Tag (e.g., 'RFID-9821').
  Future<Cow?> getCowById(String query);

  /// Get list of all registered cows.
  Future<List<Cow>> getAllCows();
}
