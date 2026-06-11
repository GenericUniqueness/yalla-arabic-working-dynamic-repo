import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/daily_usage_service.dart';

class SavedWordRef {
  final String key;
  final String? clickedForm;
  final String? lessonKey;
  final DateTime savedAt;

  const SavedWordRef({
    required this.key,
    this.clickedForm,
    this.lessonKey,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        if (clickedForm != null && clickedForm!.isNotEmpty)
          'clickedForm': clickedForm,
        if (lessonKey != null && lessonKey!.isNotEmpty) 'lessonKey': lessonKey,
        'savedAt': savedAt.toIso8601String(),
      };

  static SavedWordRef? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final key = raw['key']?.toString();
    if (key == null || key.isEmpty) return null;
    return SavedWordRef(
      key: key,
      clickedForm: raw['clickedForm']?.toString(),
      lessonKey: raw['lessonKey']?.toString(),
      savedAt: DateTime.tryParse(raw['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class FavouritesProvider extends ChangeNotifier {
  Set<String> _favourites = {};
  final Map<String, SavedWordRef> _savedWords = {};
  String? _uid;
  bool _localOnlyUser = false;
  final Completer<void> _loadCompleter = Completer<void>();
  bool _cloudDirty = false;
  final Set<String> _pendingFavouriteRemovals = {};
  final Set<String> _pendingSavedWordRemovals = {};
  int _cloudMutationVersion = 0;
  Future<void> Function()? _markCombinedBackupDirty;

  bool isFavourite(int courseId, int lessonId) =>
      _favourites.contains('${courseId}_$lessonId');
  bool get hasPendingCloudSave => _cloudDirty;
  int get cloudMutationVersion => _cloudMutationVersion;
  Future<void> get loaded => _loadCompleter.future;
  Map<String, dynamic> get cloudBackupFields => {
        'favourites': _favourites.toList(),
        'savedWords': _savedWords.values.map((word) => word.toJson()).toList(),
      };

  List<SavedWordRef> get savedWords {
    final words = _savedWords.values.toList();
    words.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return words;
  }

  bool isWordSaved(String key) => _savedWords.containsKey(_normaliseWord(key));

  FavouritesProvider() {
    _loadLocal();
  }

  void bindCombinedBackupDirtyCallback(Future<void> Function() callback) {
    _markCombinedBackupDirty = callback;
  }

  void setUser(String? uid, {bool localOnly = false}) {
    if (uid == _uid && localOnly == _localOnlyUser) return;
    _uid = uid;
    _localOnlyUser = localOnly;
    if (localOnly) {
      notifyListeners();
      return;
    }
    if (uid == null) {
      _favourites = {};
      _savedWords.clear();
      _cloudDirty = false;
      _pendingFavouriteRemovals.clear();
      _pendingSavedWordRemovals.clear();
      _clearLocal();
      notifyListeners();
    }
  }

  Future<void> toggle(int courseId, int lessonId) async {
    final key = '${courseId}_$lessonId';
    final added = !_favourites.contains(key);
    if (_favourites.contains(key)) {
      _favourites.remove(key);
      _pendingFavouriteRemovals.add(key);
    } else {
      _favourites.add(key);
      _pendingFavouriteRemovals.remove(key);
    }
    notifyListeners();
    await _saveLocal();
    await _markCloudDirty();
    if (added) await DailyUsageService.recordFavoriteLessonAdded();
  }

  Future<void> toggleSavedWord(
    String key, {
    String? clickedForm,
    String? lessonKey,
  }) async {
    final normalised = _normaliseWord(key);
    if (normalised.isEmpty) return;
    final added = !_savedWords.containsKey(normalised);
    if (_savedWords.containsKey(normalised)) {
      _savedWords.remove(normalised);
      _pendingSavedWordRemovals.add(normalised);
    } else {
      _savedWords[normalised] = SavedWordRef(
        key: normalised,
        clickedForm: _cleanOptional(clickedForm),
        lessonKey: _cleanOptional(lessonKey),
        savedAt: DateTime.now(),
      );
      _pendingSavedWordRemovals.remove(normalised);
    }
    notifyListeners();
    await _saveLocal();
    await _markCloudDirty();
    if (added) await DailyUsageService.recordSavedWordAdded();
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _favourites = (prefs.getStringList('favourites') ?? []).toSet();
    _cloudDirty = prefs.getBool('favourites_cloud_dirty') ?? false;
    _pendingFavouriteRemovals
      ..clear()
      ..addAll(
        prefs.getStringList('pending_favourite_removals') ?? const [],
      );
    _pendingSavedWordRemovals
      ..clear()
      ..addAll(
        prefs.getStringList('pending_saved_word_removals') ?? const [],
      );
    _savedWords
      ..clear()
      ..addEntries(
        (prefs.getStringList('saved_words') ?? [])
            .map((raw) {
              try {
                return SavedWordRef.fromJson(jsonDecode(raw));
              } catch (_) {
                return null;
              }
            })
            .whereType<SavedWordRef>()
            .map((word) => MapEntry(word.key, word)),
      );
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    notifyListeners();
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favourites', _favourites.toList());
    await prefs.setStringList(
      'saved_words',
      _savedWords.values.map((word) => jsonEncode(word.toJson())).toList(),
    );
  }

  Future<void> _clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('favourites');
    await prefs.remove('saved_words');
    await prefs.remove('favourites_cloud_dirty');
    await prefs.remove('pending_favourite_removals');
    await prefs.remove('pending_saved_word_removals');
  }

  Future<void> mergeCloudData(
    Map<String, dynamic> data, {
    required bool preserveLocalChanges,
  }) async {
    if (data['favourites'] != null) {
      final remote = (data['favourites'] as List<dynamic>)
          .map((e) => e.toString())
          .toSet();
      _favourites = preserveLocalChanges ? {...remote, ..._favourites} : remote;
      _favourites.removeAll(_pendingFavouriteRemovals);
    }
    if (data['savedWords'] is List) {
      final remoteWords = {
        for (final word in (data['savedWords'] as List<dynamic>)
            .map(SavedWordRef.fromJson)
            .whereType<SavedWordRef>())
          word.key: word,
      };
      if (preserveLocalChanges) {
        remoteWords.addAll(_savedWords);
      }
      _savedWords
        ..clear()
        ..addAll(remoteWords);
      for (final removed in _pendingSavedWordRemovals) {
        _savedWords.remove(removed);
      }
    }
    await _saveLocal();
    notifyListeners();
  }

  Future<void> _markCloudDirty() async {
    _cloudDirty = true;
    _cloudMutationVersion++;
    await _persistCloudDirtyMetadata();
    await _markCombinedBackupDirty?.call();
  }

  Future<void> _persistCloudDirtyMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('favourites_cloud_dirty', true);
    await prefs.setStringList(
      'pending_favourite_removals',
      _pendingFavouriteRemovals.toList(),
    );
    await prefs.setStringList(
      'pending_saved_word_removals',
      _pendingSavedWordRemovals.toList(),
    );
  }

  Future<void> markCombinedBackupSynced(int expectedMutationVersion) async {
    if (expectedMutationVersion != _cloudMutationVersion) return;
    _cloudDirty = false;
    _pendingFavouriteRemovals.clear();
    _pendingSavedWordRemovals.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('favourites_cloud_dirty', false);
    await prefs.remove('pending_favourite_removals');
    await prefs.remove('pending_saved_word_removals');
  }

  Future<void> resetForUserSwitch() async {
    _favourites.clear();
    _savedWords.clear();
    _cloudDirty = false;
    _pendingFavouriteRemovals.clear();
    _pendingSavedWordRemovals.clear();
    _cloudMutationVersion = 0;
    await _clearLocal();
    notifyListeners();
  }

  Future<void> markExistingDirtyForCombinedBackup() async {
    if (_cloudDirty) {
      await _markCombinedBackupDirty?.call();
    }
  }

  static String _normaliseWord(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?;:]'), '')
        .replaceAll(RegExp(r"^'+|'+$"), '')
        .trim();
  }

  static String? _cleanOptional(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }
}
