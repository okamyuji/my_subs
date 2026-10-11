import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_subs/presets.dart';
import 'package:my_subs/subscription.dart';

class FakeBundle extends CachingAssetBundle {
  FakeBundle(this.content);
  final String? content;

  @override
  Future<ByteData> load(String key) async {
    if (content == null || key != presetsAsset) {
      throw FlutterError('missing $key');
    }
    return ByteData.sublistView(utf8.encode(content!));
  }
}

void main() {
  test('parses presets', () async {
    final list = await loadPresets(
      FakeBundle('[{"name":"ア","category":"music","intervalMonths":12}]'),
    );
    expect(list.single.name, 'ア');
    expect(list.single.category, Category.music);
    expect(list.single.intervalMonths, 12);
  });

  test('returns empty when asset missing', () async {
    expect(await loadPresets(FakeBundle(null)), isEmpty);
  });

  test('returns empty when JSON is broken', () async {
    expect(await loadPresets(FakeBundle('[{')), isEmpty);
  });
}
