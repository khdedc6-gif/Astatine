import 'package:supabase_flutter/supabase_flutter.dart';

class AssignmentClassroom {
  const AssignmentClassroom({required this.id, required this.name});

  final String id;
  final String name;
}

class AssignmentStudent {
  const AssignmentStudent({
    required this.id,
    required this.name,
    required this.email,
    required this.classroomId,
  });

  final String id;
  final String name;
  final String email;
  final String classroomId;
}

class TeacherStudentMessage {
  const TeacherStudentMessage({
    required this.id,
    required this.conversationId,
    required this.studentId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    required this.classroomId,
    required this.classroomName,
  });

  final String id;
  final String conversationId;
  final String studentId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime? createdAt;
  final String classroomId;
  final String classroomName;
}

class NewAssignmentQuestion {
  const NewAssignmentQuestion({
    required this.text,
    required this.options,
    required this.correctOption,
    this.points = 10,
    this.explanation,
  });

  final String text;
  final List<String> options;
  final int correctOption;
  final double points;
  final String? explanation;
}

class AssignmentRecord {
  const AssignmentRecord({
    required this.id,
    required this.classId,
    required this.teacherId,
    required this.title,
    required this.subject,
    required this.description,
    required this.assignType,
    required this.coinReward,
    required this.dueAt,
    required this.questionCount,
    required this.teacherName,
    required this.submission,
  });

  final String id;
  final String classId;
  final String teacherId;
  final String title;
  final String subject;
  final String description;
  final String assignType;
  final int coinReward;
  final DateTime? dueAt;
  final int questionCount;
  final String teacherName;
  final Map<String, dynamic>? submission;

  bool get isCompleted => submission != null;
}

class AssignmentQuestion {
  const AssignmentQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.correctOption,
    required this.explanation,
    required this.order,
    this.points = 10,
  });

  final String id;
  final String text;
  final List<dynamic> options;
  final dynamic correctOption;
  final String? explanation;
  final int order;
  final double points;
}

class DailyQuestRecord {
  const DailyQuestRecord({
    required this.id,
    required this.title,
    required this.pointsReward,
  });

  final String id;
  final String title;
  final int pointsReward;
}

class AssignmentDashboardData {
  const AssignmentDashboardData({
    required this.assignments,
    required this.classrooms,
    required this.quests,
    required this.completedQuestIds,
    required this.totalPoints,
    required this.claimedMilestones,
    required this.chatChannelId,
    required this.chatChannelName,
  });

  final List<AssignmentRecord> assignments;
  final List<AssignmentClassroom> classrooms;
  final List<DailyQuestRecord> quests;
  final Set<String> completedQuestIds;
  final int totalPoints;
  final List<int> claimedMilestones;
  final String? chatChannelId;
  final String? chatChannelName;

  List<AssignmentRecord> get pendingAssignments =>
      assignments.where((assignment) => !assignment.isCompleted).toList();

  List<AssignmentRecord> get completedAssignments =>
      assignments.where((assignment) => assignment.isCompleted).toList();
}

class AssignmentDataService {
  AssignmentDataService(this._client);

  final SupabaseClient _client;

  Future<Map<String, String>> _loadProfileNames(List<String> userIds) async {
    final uniqueIds = userIds.toSet().toList();
    if (uniqueIds.isEmpty) return const {};

    final profiles = await _client
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', uniqueIds);
    return {
      for (final profile in profiles)
        if (profile['full_name']?.toString().trim().isNotEmpty == true)
          profile['id'].toString(): profile['full_name'].toString().trim(),
    };
  }

  String get _today {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<AssignmentDashboardData> loadDashboard() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Vui lòng đăng nhập để xem nhiệm vụ.');

    final memberships = await _client
        .from('classroom_members')
        .select('classroom_id, classrooms(id, name)')
        .eq('user_id', user.id);
    final classrooms = <AssignmentClassroom>[];
    for (final membership in memberships) {
      final classroomValue = membership['classrooms'];
      final classroom = classroomValue is Map
          ? Map<String, dynamic>.from(classroomValue)
          : null;
      final id = classroom?['id']?.toString();
      if (id == null) continue;
      classrooms.add(
        AssignmentClassroom(id: id, name: classroom?['name']?.toString() ?? ''),
      );
    }

    final roleRow = await _client
        .from('users')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    final role = roleRow?['role']?.toString();
    final dailyData = await _loadDailyData(user.id, role);

    if (classrooms.isEmpty) {
      return AssignmentDashboardData(
        assignments: const [],
        classrooms: const [],
        quests: dailyData.quests,
        completedQuestIds: dailyData.completedQuestIds,
        totalPoints: dailyData.totalPoints,
        claimedMilestones: dailyData.claimedMilestones,
        chatChannelId: null,
        chatChannelName: null,
      );
    }

    final classIds = classrooms.map((classroom) => classroom.id).toList();
    final assignmentRows = await _client
        .from('assignments')
        .select(
          'id, teacher_id, class_id, title, description, subject, coin_reward, assign_type, due_at',
        )
        .inFilter('class_id', classIds)
        .order('due_at', ascending: true, nullsFirst: false);

    final rawAssignmentIds = assignmentRows
        .map((row) => row['id'].toString())
        .toList();
    final recipientRows = rawAssignmentIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('assignment_recipients')
              .select('assignment_id')
              .eq('student_id', user.id)
              .inFilter('assignment_id', rawAssignmentIds);
    final assignedToStudent = recipientRows
        .map((row) => row['assignment_id'].toString())
        .toSet();

    // Class-wide assignments are shared; selected-student assignments require
    // an explicit recipient row and are not exposed to other classmates.
    final visibleRows = assignmentRows.where((row) {
      final type = (row['assign_type']?.toString() ?? '')
          .trim()
          .toLowerCase()
          .replaceAll('-', '_');
      final targeted = const {
        'individual',
        'student',
        'targeted',
        'direct',
        'selected_students',
        'specific_students',
      }.contains(type);
      return !targeted || assignedToStudent.contains(row['id'].toString());
    }).toList();

    final assignmentIds = visibleRows
        .map((row) => row['id'].toString())
        .toList();
    final teacherIds = visibleRows
        .map((row) => row['teacher_id'].toString())
        .toSet()
        .toList();

    final legacySubmissionRows = assignmentIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('submissions')
              .select(
                'id, assignment_id, student_id, score, total_questions, answers_payload, ast_earned, teacher_ast_awarded',
              )
              .eq('student_id', user.id)
              .inFilter('assignment_id', assignmentIds);
    final examSubmissionRows = assignmentIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('assignment_submissions')
              .select(
                'assignment_id, student_id, answers, answered_count, total_questions, flagged_questions, time_spent_seconds, status',
              )
              .eq('student_id', user.id)
              .inFilter('assignment_id', assignmentIds);
    final questionRows = assignmentIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('questions')
              .select('assignment_id')
              .inFilter('assignment_id', assignmentIds);
    final teacherNames = await _loadProfileNames(teacherIds);

    final submissionsByAssignment = <String, Map<String, dynamic>>{
      for (final submission in legacySubmissionRows)
        submission['assignment_id'].toString(): submission,
    };
    for (final submission in examSubmissionRows) {
      if (submission['status']?.toString().toUpperCase() == 'SUBMITTED') {
        submissionsByAssignment[submission['assignment_id'].toString()] =
            submission;
      }
    }
    final questionsByAssignment = <String, int>{};
    for (final question in questionRows) {
      final assignmentId = question['assignment_id'].toString();
      questionsByAssignment.update(
        assignmentId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final assignments = visibleRows.map((row) {
      final assignmentId = row['id'].toString();
      final teacherId = row['teacher_id'].toString();
      return AssignmentRecord(
        id: assignmentId,
        classId: row['class_id'].toString(),
        teacherId: teacherId,
        title: row['title']?.toString() ?? '',
        subject: row['subject']?.toString() ?? '',
        description: row['description']?.toString() ?? '',
        assignType: row['assign_type']?.toString() ?? '',
        coinReward: (row['coin_reward'] as num?)?.toInt() ?? 0,
        dueAt: DateTime.tryParse(row['due_at']?.toString() ?? '')?.toLocal(),
        questionCount: questionsByAssignment[assignmentId] ?? 0,
        teacherName: teacherNames[teacherId] ?? 'Giáo viên',
        submission: submissionsByAssignment[assignmentId],
      );
    }).toList();

    final chatContext = await _loadChatContext(assignments);
    return AssignmentDashboardData(
      assignments: assignments,
      classrooms: classrooms,
      quests: dailyData.quests,
      completedQuestIds: dailyData.completedQuestIds,
      totalPoints: dailyData.totalPoints,
      claimedMilestones: dailyData.claimedMilestones,
      chatChannelId: chatContext?.$1,
      chatChannelName: chatContext?.$2,
    );
  }

  Future<List<AssignmentQuestion>> fetchQuestions(String assignmentId) async {
    final rows = await _client
        .from('questions')
        .select(
          'id, question_text, options, correct_option, explanation, order_num, question_points',
        )
        .eq('assignment_id', assignmentId)
        .order('order_num');
    return rows
        .map(
          (row) => AssignmentQuestion(
            id: row['id'].toString(),
            text: row['question_text']?.toString() ?? '',
            options: row['options'] is List
                ? List<dynamic>.from(row['options'] as List)
                : const [],
            correctOption: row['correct_option'],
            explanation: row['explanation']?.toString(),
            order: (row['order_num'] as num?)?.toInt() ?? 0,
            points: (row['question_points'] as num?)?.toDouble() ?? 10,
          ),
        )
        .toList();
  }

  Future<List<AssignmentStudent>> fetchStudentsForClass(
    String classroomId,
  ) async {
    final rows = await _client
        .from('classroom_members')
        .select('user_id, role_in_class')
        .eq('classroom_id', classroomId);
    final studentRows = rows.where((row) {
      final role = row['role_in_class']?.toString().toLowerCase();
      return !const {'teacher', 'owner', 'developer'}.contains(role);
    }).toList();
    final names = await _loadProfileNames(
      studentRows.map((row) => row['user_id'].toString()).toList(),
    );
    final students = <AssignmentStudent>[];
    for (final row in studentRows) {
      final userId = row['user_id'].toString();
      final name = names[userId];
      students.add(
        AssignmentStudent(
          id: userId,
          name: name ?? 'Học sinh',
          email: '',
          classroomId: classroomId,
        ),
      );
    }
    return students;
  }

  Future<List<TeacherStudentMessage>> loadStudentMessages(
    List<AssignmentClassroom> classrooms,
  ) async {
    final teacherId = _client.auth.currentUser?.id;
    if (classrooms.isEmpty || teacherId == null) return const [];

    final classroomsById = {
      for (final classroom in classrooms) classroom.id: classroom,
    };
    final conversations = await _client
        .from('teacher_student_conversations')
        .select('id, classroom_id, student_id')
        .eq('teacher_id', teacherId)
        .inFilter('classroom_id', classroomsById.keys.toList());
    if (conversations.isEmpty) return const [];

    final conversationById = {
      for (final conversation in conversations)
        conversation['id'].toString(): Map<String, dynamic>.from(conversation),
    };
    final conversationIds = conversationById.keys.toList();
    final memberships = await _client
        .from('classroom_members')
        .select('classroom_id, user_id, role_in_class')
        .inFilter('classroom_id', classroomsById.keys.toList());
    final studentMemberships = memberships.where((membership) {
      final role = membership['role_in_class']?.toString().toLowerCase();
      return !const {'teacher', 'owner', 'developer'}.contains(role);
    }).toList();
    final studentNames = await _loadProfileNames(
      studentMemberships.map((row) => row['user_id'].toString()).toList(),
    );
    final studentsByMembership = <String, (String, String)>{};
    for (final membership in studentMemberships) {
      final classroomId = membership['classroom_id'].toString();
      final userId = membership['user_id'].toString();
      studentsByMembership['$classroomId:$userId'] = (
        studentNames[userId] ?? 'Học sinh',
        classroomsById[classroomId]?.name ?? '',
      );
    }

    final messages = await _client
        .from('teacher_student_messages')
        .select('id, conversation_id, sender_id, content, created_at')
        .inFilter('conversation_id', conversationIds)
        .order('created_at');
    final studentMessages = <TeacherStudentMessage>[];
    for (final message in messages) {
      final conversationId = message['conversation_id']?.toString();
      final conversation = conversationById[conversationId];
      final classroomId = conversation?['classroom_id']?.toString();
      final senderId = message['sender_id']?.toString();
      if (classroomId == null || senderId == null) continue;
      final studentId = conversation?['student_id']?.toString();
      if (studentId == null) continue;
      final student = studentsByMembership['$classroomId:$studentId'];
      if (student == null) continue;

      studentMessages.add(
        TeacherStudentMessage(
          id: message['id'].toString(),
          conversationId: conversationId!,
          studentId: studentId,
          senderId: senderId,
          senderName: student.$1,
          content: message['content']?.toString() ?? '',
          createdAt: DateTime.tryParse(message['created_at']?.toString() ?? '')
              ?.toLocal(),
          classroomId: classroomId,
          classroomName: student.$2,
        ),
      );
    }
    return studentMessages;
  }

  Future<String> openTeacherConversation({
    required String classroomId,
    required String teacherId,
  }) async {
    final studentId = _client.auth.currentUser?.id;
    if (studentId == null) throw StateError('Not authenticated');

    final existing = await _client
        .from('teacher_student_conversations')
        .select('id')
        .eq('classroom_id', classroomId)
        .eq('student_id', studentId)
        .eq('teacher_id', teacherId)
        .maybeSingle();
    if (existing != null) return existing['id'].toString();

    final created = await _client
        .from('teacher_student_conversations')
        .insert({
          'classroom_id': classroomId,
          'student_id': studentId,
          'teacher_id': teacherId,
        })
        .select('id')
        .single();
    return created['id'].toString();
  }

  Future<void> submitExam({
    required String assignmentId,
    required Map<String, String> answers,
    required int totalQuestions,
    required List<String> flaggedQuestions,
    required int timeSpentSeconds,
  }) async {
    final response = await _client.auth.getUser();
    final studentId = response.user?.id;
    if (studentId == null) {
      throw StateError('Vui lòng đăng nhập để nộp bài.');
    }

    await _client.from('assignment_submissions').upsert({
      'assignment_id': assignmentId,
      'student_id': studentId,
      'answers': answers,
      'answered_count': answers.values
          .where((answer) => answer.trim().isNotEmpty)
          .length,
      'total_questions': totalQuestions,
      'flagged_questions': flaggedQuestions,
      'time_spent_seconds': timeSpentSeconds,
      'status': 'SUBMITTED',
    }, onConflict: 'assignment_id,student_id');
    await _client.rpc(
      'award_assignment_coin_reward',
      params: {'p_assignment_id': assignmentId},
    );
  }

  Future<void> createAssignment({
    required String classId,
    required String title,
    String description = '',
    required String subject,
    required int coinReward,
    required DateTime dueAt,
    required List<NewAssignmentQuestion> questions,
    required List<String> recipients,
    double passingScore = 5,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Vui lòng đăng nhập để tạo nhiệm vụ.');
    if (questions.isEmpty ||
        recipients.toSet().length != recipients.length ||
        !passingScore.isFinite ||
        passingScore < 0 ||
        passingScore > 10) {
      throw ArgumentError('A quiz requires questions and unique recipients.');
    }
    for (final question in questions) {
      if (question.text.trim().isEmpty ||
          question.options.length < 2 ||
          question.options.any((option) => option.trim().isEmpty) ||
          question.correctOption < 0 ||
          question.correctOption >= question.options.length ||
          !question.points.isFinite ||
          question.points <= 0 ||
          question.points > 10) {
        throw ArgumentError(
          'Every question requires text, options, and a valid correct answer.',
        );
      }
    }

    final assignType = recipients.isEmpty ? 'whole_class' : 'selected_students';
    final assignTypeForDb = assignType == 'selected_students'
        ? 'SPECIFIC_STUDENTS'
        : 'WHOLE_CLASS';

    final assignment = await _client
        .from('assignments')
        .insert({
          'teacher_id': user.id,
          'class_id': classId,
          'title': title.trim(),
          'description': description.trim(),
          'subject': subject,
          'coin_reward': coinReward,
          'passing_score': passingScore,
          'assign_type': assignTypeForDb,
          'due_at': dueAt.toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    final assignmentId = assignment['id'].toString();
    try {
      await _client.from('questions').insert([
        for (var index = 0; index < questions.length; index++)
          {
            'assignment_id': assignmentId,
            'question_text': questions[index].text.trim(),
            'options': questions[index].options
                .map((option) => option.trim())
                .toList(),
            'correct_option': questions[index].correctOption,
            'question_points': questions[index].points,
            'explanation': questions[index].explanation,
            'order_num': index + 1,
          },
      ]);
      if (recipients.isNotEmpty) {
        await _client.from('assignment_recipients').insert([
          for (final studentId in recipients)
            {'assignment_id': assignmentId, 'student_id': studentId},
        ]);
      }
    } catch (_) {
      // Avoid leaving an assignment that cannot be started if question insert fails.
      await _client.from('assignments').delete().eq('id', assignmentId);
      rethrow;
    }
  }

  Future<void> completeQuest(String questId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Vui lòng đăng nhập để nhận nhiệm vụ.');
    final date = _today;
    await _client
        .from('user_quest_logs')
        .upsert(
          {'user_id': user.id, 'quest_id': questId, 'date': date},
          onConflict: 'user_id,quest_id,date',
          ignoreDuplicates: true,
        );
    await _recalculateDailyPoints(user.id, date);
  }

  bool _matchesRoleTarget(String? target, String? role) {
    final normalizedTarget = target?.trim();
    if (normalizedTarget == null || normalizedTarget.isEmpty) return true;

    final normalizedRole = role?.trim();
    final targetLower = normalizedTarget.toLowerCase();
    final roleLower = normalizedRole?.toLowerCase();

    return targetLower == 'all' ||
        targetLower == 'everyone' ||
        (roleLower != null && targetLower == roleLower);
  }

  Future<
    ({
      List<DailyQuestRecord> quests,
      Set<String> completedQuestIds,
      int totalPoints,
      List<int> claimedMilestones,
    })
  >
  _loadDailyData(String userId, String? role) async {
    final date = _today;
    var progress = await _client
        .from('user_daily_progress')
        .select('id, total_points, claimed_milestones')
        .eq('user_id', userId)
        .eq('date', date)
        .maybeSingle();
    progress ??= await _client
        .from('user_daily_progress')
        .upsert({
          'user_id': userId,
          'date': date,
          'total_points': 0,
          'claimed_milestones': <int>[],
        }, onConflict: 'user_id,date')
        .select('id, total_points, claimed_milestones')
        .single();

    final questRows = await _client
        .from('daily_quests')
        .select('id, title, points_reward, role_target')
        .order('title');
    final quests = questRows
        .where(
          (row) => _matchesRoleTarget(row['role_target']?.toString(), role),
        )
        .map(
          (row) => DailyQuestRecord(
            id: row['id'].toString(),
            title: row['title']?.toString() ?? '',
            pointsReward: (row['points_reward'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
    final logRows = await _client
        .from('user_quest_logs')
        .select('quest_id')
        .eq('user_id', userId)
        .eq('date', date);
    final allowedQuestIds = quests.map((quest) => quest.id).toSet();
    final completedQuestIds = logRows
        .map((row) => row['quest_id'].toString())
        .where(allowedQuestIds.contains)
        .toSet();
    final claimedValue = progress['claimed_milestones'];
    final claimed = claimedValue is List
        ? claimedValue.map((value) => (value as num).toInt()).toList()
        : <int>[];

    return (
      quests: quests,
      completedQuestIds: completedQuestIds,
      totalPoints: (progress['total_points'] as num?)?.toInt() ?? 0,
      claimedMilestones: claimed,
    );
  }

  Future<void> _recalculateDailyPoints(String userId, String date) async {
    final user = await _client
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    final role = user?['role']?.toString();
    final logs = await _client
        .from('user_quest_logs')
        .select('quest_id')
        .eq('user_id', userId)
        .eq('date', date);
    final quests = await _client
        .from('daily_quests')
        .select('id, points_reward, role_target');
    final progress = await _client
        .from('user_daily_progress')
        .select('id')
        .eq('user_id', userId)
        .eq('date', date)
        .single();
    final pointsByQuest = <String, int>{
      for (final quest in quests)
        if (_matchesRoleTarget(quest['role_target']?.toString(), role))
          quest['id'].toString():
              (quest['points_reward'] as num?)?.toInt() ?? 0,
    };
    final total = logs
        .fold<int>(
          0,
          (sum, log) => sum + (pointsByQuest[log['quest_id'].toString()] ?? 0),
        )
        .clamp(0, 100);
    await _client
        .from('user_daily_progress')
        .update({'total_points': total})
        .eq('id', progress['id']);
  }

  Future<(String, String)?> _loadChatContext(
    List<AssignmentRecord> assignments,
  ) async {
    if (assignments.isEmpty) return null;
    final classIds = assignments
        .map((assignment) => assignment.classId)
        .toSet();
    for (final classId in classIds) {
      final channels = await _client
          .from('channels')
          .select('id, name, is_private, is_hidden')
          .eq('classroom_id', classId)
          .eq('is_hidden', false)
          .order('name');
      if (channels.isEmpty) continue;
      final channel = Map<String, dynamic>.from(channels.first);
      return (channel['id'].toString(), channel['name']?.toString() ?? '');
    }
    return null;
  }
}
