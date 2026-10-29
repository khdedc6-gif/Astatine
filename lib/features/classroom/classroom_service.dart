import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class ClassroomService {
  ClassroomService._();

  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _classCodeCharacters =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

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

  static Future<String?> getUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final profile = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return profile?['role'] as String?;
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static Future<List<Map<String, dynamic>>> getMyClassrooms() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const ClassroomServiceException('Not authenticated');
    }

    try {
      final rows = await _supabase
          .from('classroom_members')
          .select(
            'classroom_id, role_in_class, custom_role_id, classrooms(id, name, code, created_by)',
          )
          .eq('user_id', user.id);
      return rows.map((row) => Map<String, dynamic>.from(row)).toList();
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
    String classroomId,
  ) async {
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
      if (userIds.isEmpty) return memberRows;

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

      return memberRows.map((member) {
        final profile = profilesById[member['user_id']?.toString()];
        final role = rolesById[member['custom_role_id']?.toString()];
        return {...member, 'users': profile, 'classroom_role': role};
      }).toList();
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(error.message);
    } catch (error) {
      throw ClassroomServiceException(error.toString());
    }
  }

  static String _defaultSeatingColumnName(int index) {
    return 'Cột ${index + 1}';
  }

  static Future<Map<String, dynamic>> getClassroomSeatingChart(
    String classroomId,
  ) async {
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
      return {
        'row_count': rowCount,
        'column_count': columnCount,
        'columns': columns,
        'seats': seats,
      };
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
