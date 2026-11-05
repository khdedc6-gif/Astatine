import 'dart:math';

import 'package:astatine_dashboard/core/cache/timed_memory_cache.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'student_index_scoring.dart';

class ClassroomService {
  ClassroomService._();

  static final SupabaseClient _supabase = Supabase.instance.client;
  static final TimedMemoryCache _classroomListCache = TimedMemoryCache(
    ttl: const Duration(minutes: 1),
    maxEntries: 8,
  );
  static final TimedMemoryCache _classroomDataCache = TimedMemoryCache(
    ttl: const Duration(seconds: 30),
    maxEntries: 24,
  );
  static const String _classCodeCharacters =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  static String? get _currentUserCacheScope => _supabase.auth.currentUser?.id;

  static String? getCachedUserRole() {
    final userId = _currentUserCacheScope;
    if (userId == null) return null;
    return _classroomListCache.read(
      'role:$userId',
      allowExpired: true,
      staleFor: const Duration(minutes: 2),
    ) as String?;
  }

  static List<Map<String, dynamic>>? getCachedMyClassrooms() {
    final userId = _currentUserCacheScope;
    if (userId == null) return null;
    final value = _classroomListCache.read(
      'memberships:$userId',
      allowExpired: true,
      staleFor: const Duration(minutes: 2),
    );
    if (value is! List) return null;
    return value.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  static List<Map<String, dynamic>>? getCachedClassroomMembers(
    String classroomId,
  ) {
    final userId = _currentUserCacheScope;
    if (userId == null) return null;
    final value = _classroomDataCache.read(
      'members:$userId:$classroomId',
      allowExpired: true,
      staleFor: const Duration(seconds: 30),
    );
    if (value is! List) return null;
    return value.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  static Map<String, dynamic>? getCachedClassroomSeatingChart(
    String classroomId,
  ) {
    final userId = _currentUserCacheScope;
    if (userId == null) return null;
    final value = _classroomDataCache.read(
      'seating:$userId:$classroomId',
      allowExpired: true,
      staleFor: const Duration(seconds: 30),
    );
    return value is Map ? _normalizeSeatingChart(value) : null;
  }

  static void _invalidateUserClassroomCache() {
    final userId = _currentUserCacheScope;
    if (userId == null) return;
    _classroomListCache.invalidateWhere(
      (key) => key.endsWith(':$userId') || key == 'role:$userId',
    );
    _classroomDataCache.invalidateWhere((key) => key.contains(':$userId:'));
  }

  static void _invalidateClassroomData(String classroomId) {
    final userId = _currentUserCacheScope;
    if (userId == null) return;
    _classroomDataCache.invalidate('members:$userId:$classroomId');
    _classroomDataCache.invalidate('seating:$userId:$classroomId');
  }

  static Future<List<Map<String, dynamic>>> getStudentSubjectIndexData({
    required String classroomId,
    required String studentId,
  }) async {
    try {
      final subjects = await _supabase
          .from('subjects')
          .select('id, name, code')
          .order('name');
      final rates = await _supabase
          .from('subject_rates')
          .select(
            'id, subject_id, subject_name, score, classification, updated_at',
          )
          .eq('student_id', studentId);
      final transactions = await _supabase
          .from('subject_rate_transactions')
          .select(
            'id, subject_id, subject_name, adjustment_type, delta_score, '
            'previous_score, new_score, reason, created_at, base_impact',
          )
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .limit(100);

      final ratesBySubject = {
        for (final rate in rates)
          (rate['subject_id']?.toString() ??
                  'name:${rate['subject_name']?.toString().toLowerCase()}'):
              Map<String, dynamic>.from(rate),
      };
      final subjectRows = <Map<String, dynamic>>[
        for (final subject in subjects)
          {
            'subject': Map<String, dynamic>.from(subject),
            'rate': ratesBySubject[subject['id']?.toString()],
            'transactions': [
              for (final transaction in transactions)
                if (transaction['subject_id']?.toString() ==
                    subject['id']?.toString())
                  Map<String, dynamic>.from(transaction),
            ],
          },
      ];
      return subjectRows;
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<List<Map<String, dynamic>>> getStudentSubjectRates({
    required String studentId,
  }) async {
    try {
      final subjects = await _supabase
          .from('subjects')
          .select('id, name, code')
          .order('name');
      final rates = await _supabase
          .from('subject_rates')
          .select('subject_id, score')
          .eq('student_id', studentId);
      final ratesBySubject = {
        for (final rate in rates) rate['subject_id'].toString(): rate,
      };
      return [
        for (final subject in subjects)
          {
            'subject': Map<String, dynamic>.from(subject),
            'rate': ratesBySubject[subject['id']?.toString()],
          },
      ];
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<Map<String, dynamic>> applyStudentSubjectIndexChange({
    required String classroomId,
    required String studentId,
    required String subjectId,
    required String subjectName,
    required double baseImpact,
    required StudentIndexChangeType type,
    required String reason,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw const ClassroomServiceException('Vui lòng nhập lý do thay đổi.');
    }
    try {
      final result = await _supabase.rpc(
        'apply_classroom_subject_rate_change',
        params: {
          'p_classroom_id': classroomId,
          'p_student_id': studentId,
          'p_subject_id': subjectId,
          'p_subject_name': subjectName,
          'p_adjustment_type': type == StudentIndexChangeType.positive
              ? 'BONUS'
              : 'PENALTY',
          'p_base_impact': baseImpact,
          'p_reason': normalizedReason,
        },
      );
      if (result is! Map) {
        throw const ClassroomServiceException(
          'Database returned an invalid Subject Rate transaction.',
        );
      }
      return Map<String, dynamic>.from(result);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } on ClassroomServiceException {
      rethrow;
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static List<String> _stringIds(Object? value) {
    if (value is Iterable) {
      return value.map((id) => id.toString()).toList();
    }
    return value == null ? <String>[] : [value.toString()];
  }

  static String _validatedMessageContent(String content) {
    final normalized = content.trim();
    if (normalized.length > 2000) {
      throw const ClassroomServiceException(
        'Message exceeds the 2,000 character limit',
      );
    }
    return normalized;
  }

  static String _generateClassCode() {
    final random = Random.secure();
    return List<String>.generate(
      6,
      (_) => _classCodeCharacters[random.nextInt(_classCodeCharacters.length)],
    ).join();
  }

  static Future<String?> getUserRole({bool forceRefresh = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final cacheKey = 'role:${user.id}';
    if (!forceRefresh) {
      final cached = _classroomListCache.read(cacheKey);
      if (cached is String) return cached;
    }

    try {
      final profile = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = profile?['role'] as String?;
      if (role != null) _classroomListCache.write(cacheKey, role);
      return role;
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<List<Map<String, dynamic>>> getMyClassrooms({
    bool forceRefresh = false,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const ClassroomServiceException('Not authenticated');
    }
    final cacheKey = 'memberships:${user.id}';
    if (!forceRefresh) {
      final cached = _classroomListCache.read(cacheKey);
      if (cached is List) {
        return cached
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      }
    }

    try {
      final rows = await _supabase
          .from('classroom_members')
          .select(
            'classroom_id, role_in_class, custom_role_id, classrooms(id, name, code, created_by)',
          )
          .eq('user_id', user.id);
      final memberships = rows
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      _classroomListCache.write(cacheKey, memberships);
      return memberships
          .map((membership) => Map<String, dynamic>.from(membership))
          .toList();
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<String> createClassroom(String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const ClassroomServiceException('Not authenticated');
    }

    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const ClassroomServiceException('Class name is required');
    }

    try {
      final code = _generateClassCode();
      final classroom = await _supabase
          .from('classrooms')
          .insert({'name': normalizedName, 'code': code, 'created_by': user.id})
          .select('id')
          .single();
      final classroomId = classroom['id'];

      await _supabase.from('classroom_members').insert({
        'classroom_id': classroomId,
        'user_id': user.id,
        'role_in_class': 'owner',
      });

      await _supabase.from('channels').insert({
        'classroom_id': classroomId,
        'name': '#chung',
        'is_private': false,
        'allowed_roles': 'all',
        'target_role_id': null,
      });

      _invalidateUserClassroomCache();
      return code;
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<void> joinClassroom(String inputCode) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const ClassroomServiceException('Not authenticated');
    }

    final code = inputCode.trim().toUpperCase();
    if (code.isEmpty) {
      throw const ClassroomServiceException('Class code is required');
    }

    try {
      await _supabase.rpc('join_classroom_by_code', params: {'p_code': code});
      _invalidateUserClassroomCache();
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const ClassroomServiceException('Already joined');
      }
      throw ClassroomServiceException(error.message);
    } on ClassroomServiceException {
      rethrow;
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<Map<String, dynamic>> getClassroom(String classroomId) async {
    try {
      final row = await _supabase
          .from('classrooms')
          .select('id, name, code, created_by')
          .eq('id', classroomId)
          .maybeSingle();
      if (row == null) {
        throw const ClassroomServiceException('Classroom not found');
      }
      return Map<String, dynamic>.from(row);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } on ClassroomServiceException {
      rethrow;
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<List<Map<String, dynamic>>> getChannels(
    String classroomId,
  ) async {
    try {
      final rows = await _supabase
          .from('channels')
          .select(
            'id, classroom_id, name, is_private, allowed_roles, target_role_id, target_role_ids, chat_access, chat_role_ids, is_hidden',
          )
          .eq('classroom_id', classroomId)
          .order('name');
      final user = _supabase.auth.currentUser;
      final membership = user == null
          ? null
          : await _supabase
                .from('classroom_members')
                .select('role_in_class, custom_role_id')
                .eq('classroom_id', classroomId)
                .eq('user_id', user.id)
                .maybeSingle();
      final roleInClass = membership?['role_in_class']
          ?.toString()
          .toLowerCase();
      final customRoleId = membership?['custom_role_id']?.toString();
      final isClassStaff = const {'owner', 'teacher'}.contains(roleInClass);
      final customRole = customRoleId == null
          ? null
          : await _supabase
                .from('classroom_roles')
                .select('can_manage_channels')
                .eq('id', customRoleId)
                .maybeSingle();
      final canManageChannels = customRole?['can_manage_channels'] == true;

      return rows
          .where((row) {
            final targetRoleIds = _stringIds(row['target_role_ids']);
            if (targetRoleIds.isEmpty && row['target_role_id'] != null) {
              targetRoleIds.add(row['target_role_id'].toString());
            }
            final roleCanView =
                targetRoleIds.isEmpty ||
                isClassStaff ||
                canManageChannels ||
                (customRoleId != null && targetRoleIds.contains(customRoleId));
            return roleCanView && (row['is_hidden'] != true || isClassStaff);
          })
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<List<Map<String, dynamic>>> getClassroomMembers(
    String classroomId, {
    bool forceRefresh = false,
  }) async {
    final userId = _currentUserCacheScope;
    final cacheKey = userId == null ? null : 'members:$userId:$classroomId';
    if (!forceRefresh && cacheKey != null) {
      final cached = _classroomDataCache.read(cacheKey);
      if (cached is List) {
        return cached
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      }
    }
    try {
      final rows = await _supabase
          .from('classroom_members')
          .select('user_id, role_in_class, custom_role_id')
          .eq('classroom_id', classroomId);
      final memberRows = rows
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final userIds = memberRows
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (userIds.isEmpty) {
        if (cacheKey != null) _classroomDataCache.write(cacheKey, memberRows);
        return memberRows;
      }

      final profiles = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', userIds);
      final profilesById = {
        for (final profile in profiles)
          profile['id'].toString(): Map<String, dynamic>.from(profile),
      };
      final roleIds = memberRows
          .map((row) => row['custom_role_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final rolesById = <String, Map<String, dynamic>>{};
      if (roleIds.isNotEmpty) {
        final roles = await _supabase
            .from('classroom_roles')
            .select('id, name, color')
            .inFilter('id', roleIds);
        for (final role in roles) {
          rolesById[role['id'].toString()] = Map<String, dynamic>.from(role);
        }
      }

      final members = memberRows.map((member) {
        final profile = profilesById[member['user_id']?.toString()];
        final role = rolesById[member['custom_role_id']?.toString()];
        return {...member, 'users': profile, 'classroom_role': role};
      }).toList();
      if (cacheKey != null) _classroomDataCache.write(cacheKey, members);
      return members
          .map((member) => Map<String, dynamic>.from(member))
          .toList();
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static String _defaultSeatingColumnName(int index) {
    return 'Cột ${index + 1}';
  }

  static List<Map<String, dynamic>> _seatingRows(
    Object? value, {
    required String field,
  }) {
    if (value is! List) {
      throw FormatException('Sơ đồ chỗ ngồi có trường "$field" không hợp lệ.');
    }
    return value.map((row) {
      if (row is! Map) {
        throw FormatException(
          'Sơ đồ chỗ ngồi có dữ liệu "$field" không hợp lệ.',
        );
      }
      return Map<String, dynamic>.from(row);
    }).toList();
  }

  static Map<String, dynamic> _normalizeSeatingChart(Map chart) => {
    ...Map<String, dynamic>.from(chart),
    'columns': _seatingRows(chart['columns'], field: 'columns'),
    'seats': _seatingRows(chart['seats'], field: 'seats'),
  };

  static Future<Map<String, dynamic>> getClassroomSeatingChart(
    String classroomId, {
    bool forceRefresh = false,
  }) async {
    final userId = _currentUserCacheScope;
    final cacheKey = userId == null ? null : 'seating:$userId:$classroomId';
    if (!forceRefresh && cacheKey != null) {
      final cached = _classroomDataCache.read(cacheKey);
      if (cached is Map) return _normalizeSeatingChart(cached);
    }
    try {
      final chart = await _supabase
          .from('classroom_seating_charts')
          .select('row_count, column_count')
          .eq('classroom_id', classroomId)
          .maybeSingle();
      final rowCount = chart?['row_count'] as int? ?? 4;
      final columnCount = chart?['column_count'] as int? ?? 2;
      final columns = chart == null
          ? List.generate(
              columnCount,
              (index) => {
                'id': null,
                'column_index': index,
                'name': _defaultSeatingColumnName(index),
              },
            )
          : (await _supabase
                    .from('classroom_seating_columns')
                    .select('id, column_index, name')
                    .eq('classroom_id', classroomId)
                    .order('column_index', ascending: true))
                .map((row) => Map<String, dynamic>.from(row))
                .toList();
      final seats = chart == null
          ? <Map<String, dynamic>>[]
          : (await _supabase
                    .from('classroom_seating_chart_seats')
                    .select(
                      'row_index, column_index, seating_column_id, seat_index, student_id',
                    )
                    .eq('classroom_id', classroomId))
                .map((row) => Map<String, dynamic>.from(row))
                .toList();
      final result = _normalizeSeatingChart({
        'row_count': rowCount,
        'column_count': columnCount,
        'columns': columns,
        'seats': seats,
      });
      if (cacheKey != null) _classroomDataCache.write(cacheKey, result);
      return result;
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<void> saveClassroomSeatingChart({
    required String classroomId,
    required int rowCount,
    required int columnCount,
    required List<Map<String, dynamic>> columns,
    required List<Map<String, dynamic>> seats,
  }) async {
    try {
      await _supabase.rpc(
        'save_classroom_seating_chart',
        params: {
          'p_classroom_id': classroomId,
          'p_row_count': rowCount,
          'p_column_count': columnCount,
          'p_columns': columns,
          'p_seats': seats,
        },
      );
      _invalidateClassroomData(classroomId);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<void> sendClassroomSeatingMessage({
    required String classroomId,
    required String seatingColumnId,
    required String content,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    final normalizedContent = _validatedMessageContent(content);
    if (normalizedContent.isEmpty) return;
    try {
      await _supabase.from('classroom_seating_messages').insert({
        'classroom_id': classroomId,
        'seating_column_id': seatingColumnId,
        'sender_id': user.id,
        'content': normalizedContent,
      });
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<void> removeClassroomSeatingStudent({
    required String classroomId,
    required String seatingColumnId,
    required int rowIndex,
    required int seatIndex,
    required String studentId,
  }) async {
    try {
      await _supabase.rpc(
        'remove_classroom_seating_student',
        params: {
          'p_classroom_id': classroomId,
          'p_seating_column_id': seatingColumnId,
          'p_row_index': rowIndex,
          'p_seat_index': seatIndex,
          'p_student_id': studentId,
        },
      );
      _invalidateClassroomData(classroomId);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<List<Map<String, dynamic>>> getClassroomRoles(
    String classroomId,
  ) async {
    try {
      final rows = await _supabase
          .from('classroom_roles')
          .select(
            'id, classroom_id, name, color, can_manage_channels, can_pin_messages, can_invoke_ai',
          )
          .eq('classroom_id', classroomId)
          .order('name');
      return rows.map((row) => Map<String, dynamic>.from(row)).toList();
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<Map<String, dynamic>> createClassroomRole({
    required String classroomId,
    required String name,
    required String color,
    required bool canManageChannels,
    required bool canPinMessages,
    required bool canInvokeAi,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const ClassroomServiceException('Role name is required');
    }

    try {
      final row = await _supabase
          .from('classroom_roles')
          .insert({
            'classroom_id': classroomId,
            'name': normalizedName,
            'color': color,
            'can_manage_channels': canManageChannels,
            'can_pin_messages': canPinMessages,
            'can_invoke_ai': canInvokeAi,
          })
          .select(
            'id, classroom_id, name, color, can_manage_channels, can_pin_messages, can_invoke_ai',
          )
          .single();
      return Map<String, dynamic>.from(row);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<Map<String, dynamic>> updateClassroomRole({
    required String roleId,
    required String name,
    required String color,
    required bool canManageChannels,
    required bool canPinMessages,
    required bool canInvokeAi,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const ClassroomServiceException('Role name is required');
    }

    try {
      final row = await _supabase
          .from('classroom_roles')
          .update({
            'name': normalizedName,
            'color': color,
            'can_manage_channels': canManageChannels,
            'can_pin_messages': canPinMessages,
            'can_invoke_ai': canInvokeAi,
          })
          .eq('id', roleId)
          .select(
            'id, classroom_id, name, color, can_manage_channels, can_pin_messages, can_invoke_ai',
          )
          .single();
      return Map<String, dynamic>.from(row);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<void> assignClassroomRole({
    required String classroomId,
    required String userId,
    required String? roleId,
  }) async {
    try {
      await _supabase.rpc(
        'update_member_role',
        params: {
          'p_classroom_id': classroomId,
          'p_target_user_id': userId,
          'p_new_role_id': roleId,
        },
      );
      _invalidateClassroomData(classroomId);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<void> createChannel(
    String classId,
    String name,
    bool isPrivate,
    String allowedRoles, {
    String? targetRoleId,
    List<String> targetRoleIds = const [],
    String chatAccess = 'everyone',
    List<String> chatRoleIds = const [],
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const ClassroomServiceException('Channel name is required');
    }

    try {
      await _supabase.from('channels').insert({
        'classroom_id': classId,
        'name': normalizedName,
        'is_private': isPrivate,
        'allowed_roles': allowedRoles,
        'target_role_id': targetRoleId ?? targetRoleIds.firstOrNull,
        'target_role_ids': targetRoleIds,
        'chat_access': chatAccess,
        'chat_role_ids': chatRoleIds,
        'is_hidden': false,
      });
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<void> updateChannel({
    required String channelId,
    required String name,
    required List<String> targetRoleIds,
    required String chatAccess,
    required List<String> chatRoleIds,
    required bool isHidden,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const ClassroomServiceException('Channel name is required');
    }
    if (!const {'everyone', 'roles', 'teachers'}.contains(chatAccess)) {
      throw const ClassroomServiceException('Invalid channel chat access');
    }

    try {
      await _supabase
          .from('channels')
          .update({
            'name': normalizedName,
            'target_role_id': targetRoleIds.firstOrNull,
            'target_role_ids': targetRoleIds,
            'chat_access': chatAccess,
            'chat_role_ids': chatRoleIds,
            'is_hidden': isHidden,
          })
          .eq('id', channelId);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<void> deleteChannel(String channelId) async {
    try {
      await _supabase.from('channels').delete().eq('id', channelId);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<void> sendMessage(String channelId, String content) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');

    final normalizedContent = _validatedMessageContent(content);
    if (normalizedContent.isEmpty) return;

    await _supabase.from('messages').insert({
      'channel_id': channelId,
      'sender_id': user.id,
      'content': normalizedContent,
    });
  }

  static Future<void> sendTeacherStudentMessage(
    String conversationId,
    String content,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');

    final normalizedContent = _validatedMessageContent(content);
    if (normalizedContent.isEmpty) return;

    await _supabase.from('teacher_student_messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'content': normalizedContent,
    });
  }

  static Future<String> openDirectConversation(String otherUserId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    if (otherUserId == user.id) {
      throw ArgumentError.value(
        otherUserId,
        'otherUserId',
        'Must be another user',
      );
    }

    final participants = [user.id, otherUserId]..sort();
    final existing = await _supabase
        .from('direct_conversations')
        .select('id')
        .eq('participant_one_id', participants[0])
        .eq('participant_two_id', participants[1])
        .maybeSingle();
    if (existing != null) return existing['id'].toString();

    try {
      final created = await _supabase
          .from('direct_conversations')
          .insert({
            'participant_one_id': participants[0],
            'participant_two_id': participants[1],
          })
          .select('id')
          .single();
      return created['id'].toString();
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final conversation = await _supabase
          .from('direct_conversations')
          .select('id')
          .eq('participant_one_id', participants[0])
          .eq('participant_two_id', participants[1])
          .single();
      return conversation['id'].toString();
    }
  }

  static Future<void> sendDirectMessage(
    String conversationId,
    String content,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');

    final normalizedContent = _validatedMessageContent(content);
    if (normalizedContent.isEmpty) return;

    await _supabase.from('direct_messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'content': normalizedContent,
    });
  }
}

class ClassroomServiceException implements Exception {
  const ClassroomServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
