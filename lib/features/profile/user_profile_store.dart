import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileStore extends ChangeNotifier {
  UserProfileStore._();

  static final UserProfileStore instance = UserProfileStore._();

  final Map<String, Map<String, dynamic>> _profiles = {};
  final Map<String, String> _errors = {};
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, Future<void>> _pendingLoads = {};
  final Set<String> _loadedUserIds = {};
  final Map<String, int> _revisions = {};

  Map<String, dynamic>? profileFor(String userId) => _profiles[userId];

  bool isLoadedFor(String userId) => _loadedUserIds.contains(userId);

  String? errorFor(String userId) => _errors[userId];

  void clearMemoryCache() {
    for (final userId in _pendingLoads.keys) {
      _revisions.update(userId, (revision) => revision + 1, ifAbsent: () => 1);
    }
    _profiles.clear();
    _errors.clear();
    _loadedUserIds.clear();
    notifyListeners();
  }

  Future<void> watchUser(String userId) {
    if (userId.isEmpty) return Future<void>.value();
    final pending = _pendingLoads[userId];
    if (pending != null) return pending;
    if (_loadedUserIds.contains(userId) && _channels.containsKey(userId)) {
      return Future<void>.value();
    }

    final load = _loadAndSubscribe(userId);
    _pendingLoads[userId] = load;
    return load.whenComplete(() => _pendingLoads.remove(userId));
  }

  Future<void> _loadAndSubscribe(String userId) async {
    bool changed = false;
    try {
      final client = Supabase.instance.client;
      final initialRevision = _revisions[userId] ?? 0;
      _channels.putIfAbsent(userId, () {
        return client
            .channel('profile-sync-$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'profiles',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: userId,
              ),
              callback: (payload) {
                _revisions.update(
                  userId,
                  (revision) => revision + 1,
                  ifAbsent: () => 1,
                );
                if (payload.eventType == PostgresChangeEvent.delete) {
                  _profiles.remove(userId);
                } else {
                  _profiles[userId] = Map<String, dynamic>.from(
                    payload.newRecord,
                  );
                }
                _errors.remove(userId);
                notifyListeners();
              },
            )
            .subscribe();
      });

      final profile = await client
          .from('profiles')
          .select('id, full_name, class_name, avatar_url, banner_url, bio')
          .eq('id', userId)
          .maybeSingle();
      if ((_revisions[userId] ?? 0) == initialRevision) {
        if (profile == null) {
          _profiles.remove(userId);
        } else {
          _profiles[userId] = Map<String, dynamic>.from(profile);
        }
        changed = true;
      }
      if (!_loadedUserIds.contains(userId)) {
        _loadedUserIds.add(userId);
        changed = true;
      }
      if (_errors.containsKey(userId)) {
        _errors.remove(userId);
        changed = true;
      }
    } catch (error) {
      _errors[userId] = error.toString();
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void applyProfile(Map<String, dynamic> profile) {
    final userId = profile['id']?.toString();
    if (userId == null || userId.isEmpty) return;
    _revisions.update(userId, (revision) => revision + 1, ifAbsent: () => 1);
    _profiles[userId] = Map<String, dynamic>.from(profile);
    _loadedUserIds.add(userId);
    _errors.remove(userId);
    notifyListeners();
  }
}
