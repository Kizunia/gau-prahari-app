import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/cow.dart';
import '../../domain/repositories/cow_repository.dart';

/// Cattle repository backed by SharedPreferences for name persistence.
///
/// The built-in catalog cows are always present; user-added cows are stored
/// in SharedPreferences under [_userCowsKey].  Name overrides for catalog
/// cows are stored separately under [_namesKey].
class CowRepositoryImpl implements CowRepository {
  static const String _userCowsKey = 'gau_prahari_user_cows';
  static const String _namesKey = 'gau_prahari_cow_names';

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

  // ── helpers ──────────────────────────────────────────────────────────────

  Future<Map<String, String>> _loadNames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_namesKey);
    if (raw == null) return {};
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  }

  Future<void> _saveNames(Map<String, String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_namesKey, json.encode(names));
  }

  Future<List<Cow>> _loadUserCows() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userCowsKey);
    if (raw == null) return [];
    final list = json.decode(raw) as List<dynamic>;
    return list.map((e) => Cow.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveUserCows(List<Cow> cows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userCowsKey, json.encode(cows.map((c) => c.toJson()).toList()));
  }

  // ── CowRepository ─────────────────────────────────────────────────────────

  @override
  Future<List<Cow>> getAllCows() async {
    final names = await _loadNames();
    final userCows = await _loadUserCows();

    // Apply stored names to catalog cows
    final catalogWithNames = _catalog.map((c) {
      final savedName = names[c.id];
      return savedName != null ? c.copyWith(name: savedName) : c;
    }).toList();

    // Merge: catalog first, then user-added cows not shadowing catalog IDs
    final catalogIds = _catalog.map((c) => c.id).toSet();
    final uniqueUserCows = userCows.where((c) => !catalogIds.contains(c.id)).toList();

    return [...catalogWithNames, ...uniqueUserCows];
  }

  @override
  Future<Cow?> getCowById(String query) async {
    final all = await getAllCows();
    final clean = query.trim().toUpperCase();

    // 1. Direct ID / tag match across all cows
    for (final cow in all) {
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
        for (final cow in all) {
          if (cow.id.toUpperCase() == targetId || cow.tagNumber.toUpperCase() == targetId) {
            return cow;
          }
        }
        if (decoded.containsKey('id') || decoded.containsKey('cow_id')) {
          return Cow.fromJson(decoded);
        }
      }
    } catch (_) {
      // Fallback
    }

    // 3. Contains match
    for (final cow in all) {
      if (clean.contains(cow.id.toUpperCase()) || clean.contains(cow.tagNumber.toUpperCase())) {
        return cow;
      }
    }

    return null;
  }

  @override
  Future<void> saveCow(Cow cow) async {
    final catalogIds = _catalog.map((c) => c.id).toSet();
    if (catalogIds.contains(cow.id)) {
      // Catalog cow — only save the name override
      if (cow.name != null && cow.name!.trim().isNotEmpty) {
        final names = await _loadNames();
        names[cow.id] = cow.name!.trim();
        await _saveNames(names);
      }
      return;
    }
    // User-added cow
    final userCows = await _loadUserCows();
    final idx = userCows.indexWhere((c) => c.id == cow.id);
    if (idx >= 0) {
      userCows[idx] = cow;
    } else {
      userCows.add(cow);
    }
    await _saveUserCows(userCows);
  }

  @override
  Future<bool> deleteCow(String id) async {
    final catalogIds = _catalog.map((c) => c.id).toSet();
    if (catalogIds.contains(id)) return false; // Cannot delete built-in catalog cows

    final userCows = await _loadUserCows();
    final before = userCows.length;
    userCows.removeWhere((c) => c.id == id);
    await _saveUserCows(userCows);
    return userCows.length < before;
  }

  @override
  Future<Cow?> updateCowName(String id, String? name) async {
    final names = await _loadNames();
    if (name == null || name.trim().isEmpty) {
      names.remove(id);
    } else {
      names[id] = name.trim();
    }
    await _saveNames(names);

    // Also update user cows list if it is a user-added cow
    final userCows = await _loadUserCows();
    final idx = userCows.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      userCows[idx] = userCows[idx].copyWith(name: name?.trim(), clearName: name == null || name.trim().isEmpty);
      await _saveUserCows(userCows);
    }

    return getCowById(id);
  }
}
