import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

class Hadith {
  final int id;
  final String collection;
  final String book;
  final String hadithNo;
  final String chapter;
  final String narrator;
  final String bangla;
  final String arabic;

  const Hadith({
    required this.id,
    required this.collection,
    required this.book,
    required this.hadithNo,
    required this.chapter,
    required this.narrator,
    required this.bangla,
    required this.arabic,
  });

  factory Hadith.fromJson(Map<String, dynamic> j) => Hadith(
    id: j['id'] as int,
    collection: j['collection'] as String,
    book: j['book'] as String,
    hadithNo: j['hadithNo'] as String,
    chapter: j['chapter'] as String,
    narrator: j['narrator'] as String,
    bangla: j['bangla'] as String,
    arabic: (j['arabic'] ?? '') as String,
  );
}

// Top-level helper so it can run inside `compute()` (a separate isolate).
List<Hadith> _parseHadithJson(String raw) {
  final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
  return list
      .map((e) => Hadith.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

class HadithApi {
  static List<Hadith>? _cache;
  static Future<List<Hadith>>? _inflight;

  static Future<List<Hadith>> fetchAll() async {
    if (_cache != null && _cache!.isNotEmpty) return _cache!;
    if (_inflight != null) return _inflight!;
    final future = _inflight = _load();
    try {
      final list = await future;
      _cache = list;
      return list;
    } finally {
      _inflight = null;
    }
  }

  static Future<List<Hadith>> _load() async {
    final raw = await rootBundle.loadString('assets/data/hadith_bn.json');
    // Parse off the main isolate so the very first Hadith screen does
    // not jank while decoding thousands of entries.
    return compute(_parseHadithJson, raw);
  }
}
