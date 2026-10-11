import 'dart:convert';

import 'package:flutter/services.dart';

import 'subscription.dart';

const presetsAsset = 'assets/private/presets.json';

class Preset {
  const Preset({
    required this.name,
    required this.category,
    required this.intervalMonths,
  });

  factory Preset.fromJson(Map<String, Object?> json) => Preset(
    name: json['name']! as String,
    category: Category.values.byName(json['category']! as String),
    intervalMonths: json['intervalMonths']! as int,
  );

  final String name;
  final Category category;
  final int intervalMonths;
}

// The file is git-ignored personal data; a public checkout has none, so
// absence is the normal case, not an error.
Future<List<Preset>> loadPresets(AssetBundle bundle) async {
  try {
    final raw = await bundle.loadString(presetsAsset);
    return [
      for (final e in jsonDecode(raw) as List<Object?>)
        Preset.fromJson(e! as Map<String, Object?>),
    ];
  } catch (_) {
    return const [];
  }
}
