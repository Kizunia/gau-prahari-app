import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/review_draft.dart';

/// Repository for locally persisting and managing farmer review drafts.
class LocalDraftRepository {
  final SharedPreferences? _prefs;

  LocalDraftRepository([this._prefs]);

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  String _getKey(String farmerUid) => 'vet_review_drafts_$farmerUid';

  Future<List<ReviewDraft>> getDrafts(String farmerUid) async {
    if (farmerUid.trim().isEmpty) return const [];
    final prefs = await _getPrefs();
    final rawList = prefs.getStringList(_getKey(farmerUid)) ?? [];
    return rawList
        .map((str) {
          try {
            final json = jsonDecode(str) as Map<String, dynamic>;
            return ReviewDraft.fromJson(json);
          } catch (_) {
            return null;
          }
        })
        .whereType<ReviewDraft>()
        .toList();
  }

  Future<void> saveDraft(ReviewDraft draft) async {
    if (draft.farmerUid.trim().isEmpty) return;
    final prefs = await _getPrefs();
    final drafts = await getDrafts(draft.farmerUid);
    final index = drafts.indexWhere((d) => d.id == draft.id);
    if (index >= 0) {
      drafts[index] = draft;
    } else {
      drafts.insert(0, draft);
    }

    final rawList = drafts.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList(_getKey(draft.farmerUid), rawList);
  }

  Future<void> deleteDraft(String farmerUid, String draftId) async {
    if (farmerUid.trim().isEmpty) return;
    final prefs = await _getPrefs();
    final drafts = await getDrafts(farmerUid);
    drafts.removeWhere((d) => d.id == draftId);
    final rawList = drafts.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList(_getKey(farmerUid), rawList);
  }
}
