import 'dart:convert';
import '../../domain/entities/cow.dart';
import '../../domain/repositories/cow_repository.dart';

/// In-memory and extensible cattle repository for field identification.
class CowRepositoryImpl implements CowRepository {
  static const List<Cow> _catalog = [
    Cow(
      id: 'COW-104',
      tagNumber: 'RFID-9821',
      breed: 'Gir / Sahiwal Cross',
      ageYears: 4,
      lactationStage: 'Early Lactation (Day 42)',
      status: 'Ready for Test',
    ),
    Cow(
      id: 'COW-101',
      tagNumber: 'RFID-7714',
      breed: 'Murrah Buffalo',
      ageYears: 5,
      lactationStage: 'Mid Lactation (Day 110)',
      status: 'Collar History Available',
    ),
    Cow(
      id: 'COW-102',
      tagNumber: 'RFID-5529',
      breed: 'Tharparkar',
      ageYears: 3,
      lactationStage: 'Fresh (Day 14)',
      status: 'Needs Milk Test',
    ),
  ];

  @override
  Future<List<Cow>> getAllCows() async {
    return List.unmodifiable(_catalog);
  }

  @override
  Future<Cow?> getCowById(String query) async {
    final clean = query.trim().toUpperCase();

    // 1. Try direct ID match
    for (final cow in _catalog) {
      if (cow.id.toUpperCase() == clean || cow.tagNumber.toUpperCase() == clean) {
        return cow;
      }
    }

    // 2. Try JSON payload parse: {"cow_id": "COW-104", ...}
    try {
      if (clean.startsWith('{') && clean.endsWith('}')) {
        final decoded = json.decode(query) as Map<String, dynamic>;
        final targetId = (decoded['cow_id'] ?? decoded['id'] ?? decoded['tag_number'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
        for (final cow in _catalog) {
          if (cow.id.toUpperCase() == targetId || cow.tagNumber.toUpperCase() == targetId) {
            return cow;
          }
        }
        // If not in standard catalog, instantiate from JSON payload
        if (decoded.containsKey('id') || decoded.containsKey('cow_id')) {
          return Cow.fromJson(decoded);
        }
      }
    } catch (_) {
      // Fallback
    }

    // 3. Fallback contains match (e.g., '104' -> 'COW-104')
    for (final cow in _catalog) {
      if (clean.contains(cow.id.toUpperCase()) || clean.contains(cow.tagNumber.toUpperCase())) {
        return cow;
      }
    }

    return null;
  }
}
