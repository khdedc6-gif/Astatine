import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class StudyGroupClassroom {
  const StudyGroupClassroom({required this.id, required this.name});

  final String id;
  final String name;
}

class StudyGroupMember {
  const StudyGroupMember({required this.id, required this.name});

  final String id;
  final String name;
}

class StudyGroupWorkspace {
  const StudyGroupWorkspace({
    required this.group,
    required this.membershipStatus,
    required this.members,
  });

  final Map<String, dynamic> group;
  final String membershipStatus;
  final List<Map<String, dynamic>> members;
}

abstract interface class StudyGroupDataSource {
  Future<List<StudyGroupClassroom>> loadClassrooms(String userId);

  Future<List<StudyGroupMember>> loadClassroomMembers(String classroomId);

  Future<List<StudyGroupWorkspace>> loadWorkspaces(String userId);

  Future<String> createGroup({
    required String classroomId,
    required String groupName,
    required String className,
    required String subject,
    required String topic,
    required String deadline,
    required bool aiDetectionEnabled,
    required List<String> invitedUserIds,
    required List<Map<String, dynamic>> taskAssignments,
  });

  Future<void> updateInviteStatus({
    required String groupId,
    required String status,
  });

  Future<List<Map<String, dynamic>>> loadGroupFiles(String groupId);

  Future<Map<String, dynamic>> uploadGroupFile({
    required String groupId,
    required String uploaderUserId,
    required String? assigneeUserId,
    required String fileName,
    required String? mimeType,
    required Uint8List bytes,
  });

  Future<Uint8List> downloadGroupFile(String storagePath);
}

class StudyGroupRepository implements StudyGroupDataSource {
  StudyGroupRepository(this._client);

  static const _fileBucket = 'study-group-files';
  static const maximumFileSizeBytes = 50 * 1024 * 1024;
  final SupabaseClient _client;

  @override
  Future<List<StudyGroupClassroom>> loadClassrooms(String userId) async {
    final rows = await _client
        .from('classroom_members')
        .select('classroom_id, classrooms!inner(id, name)')
        .eq('user_id', userId);
    return rows
        .map((row) {
          final classroomValue = row['classrooms'];
          final classroomRecord = classroomValue is List
              ? classroomValue.firstOrNull
              : classroomValue;
          final classroom = classroomRecord is Map
              ? Map<String, dynamic>.from(classroomRecord)
              : null;
          final id = classroom?['id']?.toString();
          final name = classroom?['name']?.toString().trim();
          if (id == null || name == null || name.isEmpty) return null;
          return StudyGroupClassroom(id: id, name: name);
        })
        .whereType<StudyGroupClassroom>()
        .toList();
  }

  @override
  Future<List<StudyGroupMember>> loadClassroomMembers(
    String classroomId,
  ) async {
    final memberRows = await _client
        .from('classroom_members')
        .select('user_id')
        .eq('classroom_id', classroomId);
    final userIds = memberRows
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (userIds.isEmpty) return const [];

    final profiles = await _client
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', userIds);
    final namesById = {
      for (final profile in profiles)
        profile['id'].toString():
            (profile['full_name'] as String?)?.trim() ?? '',
    };
    final baseNames = {
      for (final id in userIds)
        id: namesById[id]?.isNotEmpty == true
            ? namesById[id]!
            : 'User ${id.substring(0, id.length < 8 ? id.length : 8)}',
    };
    final counts = <String, int>{};
    for (final name in baseNames.values) {
      counts.update(name, (count) => count + 1, ifAbsent: () => 1);
    }
    return userIds.map((id) {
      final name = baseNames[id]!;
      return StudyGroupMember(
        id: id,
        name: counts[name]! > 1 ? '$name (${id.substring(0, 4)})' : name,
      );
    }).toList();
  }

  @override
  Future<List<StudyGroupWorkspace>> loadWorkspaces(String userId) async {
    final ownMemberships = await _client
        .from('study_group_members')
        .select('group_id, status')
        .eq('user_id', userId)
        .inFilter('status', ['pending', 'accepted']);
    final groupIds = ownMemberships
        .map((row) => row['group_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    if (groupIds.isEmpty) return const [];

    final groupRowsFuture = _client
        .from('study_groups')
        .select(
          'id, classroom_id, class_name, created_by, group_name, subject, topic, deadline, task_assignments, ai_detection_enabled, created_at',
        )
        .inFilter('id', groupIds)
        .order('created_at', ascending: false);
    final membershipsFuture = _client
        .from('study_group_members')
        .select('group_id, user_id, status')
        .inFilter('group_id', groupIds);
    final groupRows = await groupRowsFuture;
    final allMemberships = await membershipsFuture;
    final memberIds = allMemberships
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final profiles = memberIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('profiles')
              .select('id, full_name')
              .inFilter('id', memberIds);
    final namesById = {
      for (final profile in profiles)
        profile['id'].toString():
            (profile['full_name'] as String?)?.trim() ?? '',
    };
    final statusByGroupId = {
      for (final row in ownMemberships)
        row['group_id'].toString(): row['status'].toString(),
    };
    final membersByGroupId = <String, List<Map<String, dynamic>>>{};
    for (final membership in allMemberships) {
      final groupId = membership['group_id'].toString();
      final memberId = membership['user_id'].toString();
      final displayName = namesById[memberId];
      membersByGroupId.putIfAbsent(groupId, () => []).add({
        'user_id': memberId,
        'name': displayName?.isNotEmpty == true
            ? displayName
            : 'User ${memberId.substring(0, memberId.length < 8 ? memberId.length : 8)}',
        'status': membership['status'].toString(),
      });
    }

    return groupRows.map((row) {
      final group = Map<String, dynamic>.from(row);
      final groupId = group['id'].toString();
      return StudyGroupWorkspace(
        group: group,
        membershipStatus: statusByGroupId[groupId] ?? 'pending',
        members: membersByGroupId[groupId] ?? const [],
      );
    }).toList();
  }

  @override
  Future<String> createGroup({
    required String classroomId,
    required String groupName,
    required String className,
    required String subject,
    required String topic,
    required String deadline,
    required bool aiDetectionEnabled,
    required List<String> invitedUserIds,
    required List<Map<String, dynamic>> taskAssignments,
  }) async {
    final result = await _client.rpc(
      'create_study_group',
      params: {
        'p_classroom_id': classroomId,
        'p_group_name': groupName,
        'p_class_name': className,
        'p_subject': subject,
        'p_topic': topic,
        'p_deadline': deadline,
        'p_ai_detection_enabled': aiDetectionEnabled,
        'p_invited_user_ids': invitedUserIds,
        'p_task_assignments': taskAssignments,
      },
    );
    return result.toString();
  }

  @override
  Future<void> updateInviteStatus({
    required String groupId,
    required String status,
  }) async {
    await _client.rpc(
      'respond_to_study_group_invite',
      params: {'p_group_id': groupId, 'p_status': status},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadGroupFiles(String groupId) async {
    final rows = await _client
        .from('study_group_files')
        .select(
          'id, group_id, uploaded_by, assignee_user_id, storage_path, file_name, mime_type, size_bytes, created_at',
        )
        .eq('group_id', groupId)
        .order('created_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  @override
  Future<Map<String, dynamic>> uploadGroupFile({
    required String groupId,
    required String uploaderUserId,
    required String? assigneeUserId,
    required String fileName,
    required String? mimeType,
    required Uint8List bytes,
  }) async {
    final authenticatedUserId = _client.auth.currentUser?.id;
    if (authenticatedUserId == null) {
      throw StateError('Sign in before uploading a group file');
    }
    if (authenticatedUserId != uploaderUserId) {
      throw ArgumentError.value(
        uploaderUserId,
        'uploaderUserId',
        'Must match the authenticated user',
      );
    }
    if (bytes.length > maximumFileSizeBytes) {
      throw ArgumentError.value(
        bytes.length,
        'bytes',
        'File exceeds the 50 MB upload limit',
      );
    }
    final safeName = fileName
        .replaceAll(RegExp(r'[/\\]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F]'), '_');
    final storagePath =
        '$groupId/$authenticatedUserId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final storage = _client.storage.from(_fileBucket);
    await storage.uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: false),
    );

    try {
      final row = await _client
          .from('study_group_files')
          .insert({
            'group_id': groupId,
            'uploaded_by': uploaderUserId,
            'assignee_user_id': assigneeUserId,
            'storage_path': storagePath,
            'file_name': fileName,
            'mime_type': mimeType,
            'size_bytes': bytes.length,
          })
          .select(
            'id, group_id, uploaded_by, assignee_user_id, storage_path, file_name, mime_type, size_bytes, created_at',
          )
          .single();
      return Map<String, dynamic>.from(row);
    } catch (_) {
      await storage.remove([storagePath]);
      rethrow;
    }
  }

  @override
  Future<Uint8List> downloadGroupFile(String storagePath) async {
    final bytes = await _client.storage.from(_fileBucket).download(storagePath);
    return bytes;
  }
}
