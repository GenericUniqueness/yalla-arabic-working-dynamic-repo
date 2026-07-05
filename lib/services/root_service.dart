import 'dart:convert';
import 'package:flutter/services.dart';

/// Represents a single Arabic root (e.g., "ك ت ب" for writing-related words).
class ArabicRoot {
  final String root;
  final String coreMeaning;
  final String explanation;
  final String? partOfSpeech;

  const ArabicRoot({
    required this.root,
    required this.coreMeaning,
    required this.explanation,
    this.partOfSpeech,
  });

  factory ArabicRoot.fromMap(String root, Map<String, dynamic> data) {
    return ArabicRoot(
      root: root,
      coreMeaning: data['core_meaning'] as String? ?? '',
      explanation: data['explanation'] as String? ?? '',
      partOfSpeech: data['part_of_speech'] as String?,
    );
  }
}

/// Service for managing the centralized Arabic root dictionary.
///
/// Roots are loaded from `assets/roots.json`. Word families are computed
/// at runtime by finding all glossary entries sharing the same root.
class RootService {
  static Map<String, ArabicRoot>? _cache;

  static Future<Map<String, ArabicRoot>> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/roots.json');
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final rootsJson = json['roots'] as Map<String, dynamic>? ?? {};
      _cache = {};
      for (final entry in rootsJson.entries) {
        if (entry.value is Map) {
          _cache![entry.key] = ArabicRoot.fromMap(
            entry.key,
            Map<String, dynamic>.from(entry.value),
          );
        }
      }
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }

  /// Get a root by its string representation (e.g., "ك ت ب").
  static ArabicRoot? getRoot(String root) {
    return _cache?[root];
  }

  /// Get all roots.
  static Map<String, ArabicRoot> get allRoots => _cache ?? {};

  /// Normalize a root string for consistent matching.
  /// Roots are stored as space-separated letters (e.g., "ك ت ب").
  static String normalizeRoot(String root) {
    return root.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
