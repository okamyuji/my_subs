import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'subscription.dart';

class SubscriptionStore extends ChangeNotifier {
  SubscriptionStore(this._prefs, {this.onChanged});

  static const key = 'subscriptions_v1';
  static const corruptKey = 'subscriptions_v1_corrupt';

  final SharedPreferencesAsync _prefs;
  final Future<void> Function(List<Subscription>)? onChanged;

  List<Subscription> _items = const [];
  List<Subscription> get items => _items;
  bool recoveredFromCorruption = false;

  Future<void> load() async {
    final raw = await _prefs.getString(key);
    if (raw != null) {
      try {
        _items = [
          for (final e in jsonDecode(raw) as List<Object?>)
            Subscription.fromJson(e! as Map<String, Object?>),
        ];
      } catch (_) {
        // Back up before dropping so a bad write or schema change never
        // destroys data silently.
        await _prefs.setString(corruptKey, raw);
        await _prefs.remove(key);
        _items = const [];
        recoveredFromCorruption = true;
      }
    }
    await _publish();
  }

  Future<void> upsert(Subscription s) => _save([
    for (final e in _items)
      if (e.id != s.id) e,
    s,
  ]);

  Future<void> delete(String id) => _save([
    for (final e in _items)
      if (e.id != id) e,
  ]);

  Future<void> _save(List<Subscription> next) async {
    await _prefs.setString(key, jsonEncode([for (final e in next) e.toJson()]));
    _items = next;
    await _publish();
  }

  Future<void> _publish() async {
    notifyListeners();
    await onChanged?.call(_items);
  }
}
