import type { SupabaseClient } from '@supabase/supabase-js';
import type {
  Assignment,
  AssignmentTargetMatcher,
  AstWalletAdapter,
  DailyMilestone,
  DailyProgressSnapshot,
  Database,
  Json,
  MilestoneRewards,
  UserDailyProgress,
} from '../types/assignment';

const DAILY_MILESTONES = new Set<DailyMilestone>([20, 40, 60, 80, 100]);
const MAX_PROGRESS_WRITE_ATTEMPTS = 4;

export interface AssignmentServiceOptions {
  milestoneRewards: MilestoneRewards;
  /**
   * Override when the schema adds an assignment-recipient relation. The supplied
   * assignments columns only support class-wide targeting via class_id.
   */
  isAssignmentForStudent?: AssignmentTargetMatcher;
  now?: () => Date;
}

export interface AssignmentService {
  fetchStudentAssignments(
    classId: string,
    studentId: string,
  ): Promise<Assignment[]>;
  fetchDailyProgress(userId: string): Promise<DailyProgressSnapshot>;
  submitAssignment(
    assignmentId: string,
    studentId: string,
    score: number,
    totalQuestions: number,
    answers: Record<string, string>,
  ): Promise<number>;
  claimMilestoneReward(
    userId: string,
    milestone: DailyMilestone,
  ): Promise<number>;
  completeDailyQuest(
    userId: string,
    questId: string,
  ): Promise<DailyProgressSnapshot>;
}

function localDate(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function postgresIntArray(values: number[]): string {
  return `{${values.join(',')}}`;
}

function normalizeAssignmentType(assignType: string): string {
  return assignType.trim().toLowerCase().replaceAll('-', '_');
}

function defaultAssignmentTargetMatcher(input: {
  assignment: Assignment;
  classId: string;
  studentId: string;
}): boolean {
  const { assignment, classId } = input;
  if (assignment.class_id !== classId) return false;

  // Do not expose targeted work to every class member. The supplied schema has
  // no recipient ID/table, so only class-wide types can be resolved safely.
  const type = normalizeAssignmentType(assignment.assign_type);
  return !['individual', 'student', 'targeted', 'direct'].includes(type);
}

function requireRpcAstBalance(value: Json): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;

  if (Array.isArray(value) && value.length === 1) {
    return requireRpcAstBalance(value[0]);
  }

  if (value !== null && typeof value === 'object') {
    const record = value as Record<string, Json | undefined>;
    for (const key of ['ast_balance', 'wallet_balance', 'balance']) {
      const balance = record[key];
      if (typeof balance === 'number' && Number.isFinite(balance)) {
        return balance;
      }
    }
  }

  throw new Error(
    'submit_assignment_and_reward must return the updated AST balance as a number or { ast_balance: number }.',
  );
}

export function createAssignmentService(
  supabase: SupabaseClient<Database>,
  wallet: AstWalletAdapter,
  options: AssignmentServiceOptions,
): AssignmentService {
  const now = options.now ?? (() => new Date());
  const matchesTarget =
    options.isAssignmentForStudent ?? defaultAssignmentTargetMatcher;

  async function assertAuthenticatedUser(userId: string): Promise<void> {
    const { data, error } = await supabase.auth.getUser();
    if (error) throw new Error(error.message);
    if (!data.user || data.user.id !== userId) {
      throw new Error('The requested user does not match the active session.');
    }
  }

  async function getOrCreateProgress(
    userId: string,
    date: string,
  ): Promise<UserDailyProgress> {
    const { data: existing, error: readError } = await supabase
      .from('user_daily_progress')
      .select('*')
      .eq('user_id', userId)
      .eq('date', date)
      .maybeSingle();

    if (readError) throw new Error(readError.message);
    if (existing) return existing;

    // Requires a unique constraint on (user_id, date) so concurrent first loads
    // converge on one daily progress row.
    const { data: created, error: createError } = await supabase
      .from('user_daily_progress')
      .upsert(
        {
          user_id: userId,
          date,
          total_points: 0,
          claimed_milestones: [],
        },
        { onConflict: 'user_id,date' },
      )
      .select('*')
      .single();

    if (createError) throw new Error(createError.message);
    return created;
  }

  async function readDailyProgress(
    userId: string,
    date: string,
  ): Promise<DailyProgressSnapshot> {
    const [progress, profileResult, questResult, logResult] = await Promise.all([
      getOrCreateProgress(userId, date),
      supabase.from('users').select('role').eq('id', userId).maybeSingle(),
      supabase.from('daily_quests').select('*').order('title'),
      supabase
        .from('user_quest_logs')
        .select('quest_id')
        .eq('user_id', userId)
        .eq('date', date),
    ]);

    if (profileResult.error) throw new Error(profileResult.error.message);
    if (questResult.error) throw new Error(questResult.error.message);
    if (logResult.error) throw new Error(logResult.error.message);

    const role = profileResult.data?.role ?? null;
    const quests = (questResult.data ?? []).filter(
      (quest) => quest.role_target === null || quest.role_target === role,
    );
    const visibleQuestIds = new Set(quests.map((quest) => quest.id));
    const completedQuestIds = (logResult.data ?? [])
      .map((log) => log.quest_id)
      .filter((questId) => visibleQuestIds.has(questId));

    return { progress, quests, completedQuestIds };
  }

  async function recalculateProgress(
    userId: string,
    date: string,
  ): Promise<DailyProgressSnapshot> {
    for (let attempt = 0; attempt < MAX_PROGRESS_WRITE_ATTEMPTS; attempt += 1) {
      const snapshot = await readDailyProgress(userId, date);
      const rewardsByQuestId = new Map(
        snapshot.quests.map((quest) => [quest.id, quest.points_reward]),
      );
      const totalPoints = Math.min(
        100,
        snapshot.completedQuestIds.reduce(
          (sum, questId) => sum + (rewardsByQuestId.get(questId) ?? 0),
          0,
        ),
      );

      if (snapshot.progress.total_points === totalPoints) return snapshot;

      // Compare-and-set prevents concurrent quest completions from overwriting
      // one another. Retry after a competing update and recompute from the logs.
      const { data: updated, error } = await supabase
        .from('user_daily_progress')
        .update({ total_points: totalPoints })
        .eq('id', snapshot.progress.id)
        .eq('total_points', snapshot.progress.total_points)
        .select('*')
        .maybeSingle();

      if (error) throw new Error(error.message);
      if (updated) return readDailyProgress(userId, date);
    }

    throw new Error('Daily progress changed concurrently. Please retry.');
  }

  return {
    async fetchStudentAssignments(classId, studentId) {
      await assertAuthenticatedUser(studentId);
      const { data: rows, error } = await supabase
        .from('assignments')
        .select('*')
        .eq('class_id', classId)
        .order('due_at', { ascending: true, nullsFirst: false });

      if (error) throw new Error(error.message);
      const assignments = (rows ?? []).filter((assignment) =>
        matchesTarget({ assignment, classId, studentId }),
      );
      if (assignments.length === 0) return [];

      const { data: submissions, error: submissionError } = await supabase
        .from('submissions')
        .select('assignment_id')
        .eq('student_id', studentId)
        .in(
          'assignment_id',
          assignments.map((assignment) => assignment.id),
        );

      if (submissionError) throw new Error(submissionError.message);
      const submittedIds = new Set(
        (submissions ?? []).map((submission) => submission.assignment_id),
      );
      return assignments.filter((assignment) => !submittedIds.has(assignment.id));
    },

    async fetchDailyProgress(userId) {
      await assertAuthenticatedUser(userId);
      return readDailyProgress(userId, localDate(now()));
    },

    async submitAssignment(
      assignmentId,
      studentId,
      score,
      totalQuestions,
      answers,
    ) {
      await assertAuthenticatedUser(studentId);
      if (!Number.isInteger(totalQuestions) || totalQuestions <= 0) {
        throw new Error('totalQuestions must be a positive integer.');
      }
      if (!Number.isFinite(score) || score < 0 || score > totalQuestions) {
        throw new Error('score must be between 0 and totalQuestions.');
      }

      const { data, error } = await supabase.rpc(
        'submit_assignment_and_reward',
        {
          p_assignment_id: assignmentId,
          p_student_id: studentId,
          p_score: score,
          p_total_questions: totalQuestions,
          p_answers: answers as Json,
        },
      );

      if (error) throw new Error(error.message);
      return requireRpcAstBalance(data);
    },

    async claimMilestoneReward(userId, milestone) {
      await assertAuthenticatedUser(userId);
      if (!DAILY_MILESTONES.has(milestone)) {
        throw new Error('Unsupported daily activity milestone.');
      }

      const date = localDate(now());
      const snapshot = await readDailyProgress(userId, date);
      if (snapshot.progress.total_points < milestone) {
        throw new Error(`Reach ${milestone} daily points before claiming this chest.`);
      }
      if (snapshot.progress.claimed_milestones.includes(milestone)) {
        throw new Error('This milestone reward has already been claimed.');
      }

      const amount = options.milestoneRewards[milestone];
      if (!Number.isFinite(amount) || amount <= 0) {
        throw new Error(`No positive AST reward is configured for ${milestone} points.`);
      }

      // The idempotency key prevents double AST credit if the client retries
      // after the wallet service succeeds but the progress update times out.
      const idempotencyKey = `daily-milestone:${userId}:${date}:${milestone}`;
      const balance = await wallet.awardAst({
        userId,
        amount,
        idempotencyKey,
      });

      // Compare the full current array so simultaneous claims for different
      // milestones cannot replace one another. The wallet key makes retries safe.
      for (let attempt = 0; attempt < MAX_PROGRESS_WRITE_ATTEMPTS; attempt += 1) {
        const latest = await readDailyProgress(userId, date);
        if (latest.progress.claimed_milestones.includes(milestone)) return balance;
        if (latest.progress.total_points < milestone) {
          throw new Error(`Reach ${milestone} daily points before claiming this chest.`);
        }

        const claims = latest.progress.claimed_milestones;
        const nextClaims = [...claims, milestone].sort((left, right) => left - right);
        const { data: updated, error } = await supabase
          .from('user_daily_progress')
          .update({ claimed_milestones: nextClaims })
          .eq('id', latest.progress.id)
          .gte('total_points', milestone)
          .filter('claimed_milestones', 'eq', postgresIntArray(claims))
          .select('id')
          .maybeSingle();

        if (error) throw new Error(error.message);
        if (updated) return balance;
      }

      throw new Error('Milestone claims changed concurrently. Please retry.');
    },

    async completeDailyQuest(userId, questId) {
      await assertAuthenticatedUser(userId);
      const date = localDate(now());
      const snapshot = await readDailyProgress(userId, date);
      const quest = snapshot.quests.find((item) => item.id === questId);
      if (!quest) throw new Error('This quest is unavailable for your role.');
      if (snapshot.completedQuestIds.includes(questId)) return snapshot;

      // Requires a unique constraint on (user_id, quest_id, date) to make daily
      // quest completion idempotent across tabs and retried requests.
      const { data: insertedLog, error: logError } = await supabase
        .from('user_quest_logs')
        .upsert(
          { user_id: userId, quest_id: questId, date },
          {
            onConflict: 'user_id,quest_id,date',
            ignoreDuplicates: true,
          },
        )
        .select('quest_id')
        .maybeSingle();

      if (logError) throw new Error(logError.message);
      if (!insertedLog) return readDailyProgress(userId, date);
      return recalculateProgress(userId, date);
    },
  };
}
