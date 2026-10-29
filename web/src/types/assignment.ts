export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export interface Assignment {
  id: string;
  teacher_id: string;
  class_id: string;
  title: string;
  description: string | null;
  subject: string | null;
  ast_reward: number;
  assign_type: string;
  due_at: string | null;
}

export interface Question {
  id: string;
  assignment_id: string;
  question_text: string;
  options: Json;
  correct_option: Json;
  explanation: string | null;
  order_num: number;
}

export interface Submission {
  id: string;
  assignment_id: string;
  student_id: string;
  score: number;
  total_questions: number;
  answers_payload: Json;
  ast_earned: number;
  teacher_ast_awarded: boolean;
}

export interface DailyQuest {
  id: string;
  title: string;
  points_reward: number;
  role_target: string | null;
}

export interface UserDailyProgress {
  id: string;
  user_id: string;
  date: string;
  total_points: number;
  claimed_milestones: number[];
}

export interface UserQuestLog {
  user_id: string;
  quest_id: string;
  date: string;
}

export interface UserProfile {
  id: string;
  email: string | null;
  full_name: string | null;
  role: string | null;
}

export type DailyMilestone = 20 | 40 | 60 | 80 | 100;

export interface DailyProgressSnapshot {
  progress: UserDailyProgress;
  quests: DailyQuest[];
  completedQuestIds: string[];
}

export interface AssignmentTargetContext {
  assignment: Assignment;
  classId: string;
  studentId: string;
}

export type AssignmentTargetMatcher = (
  context: AssignmentTargetContext,
) => boolean;

/**
 * The app's wallet schema is not part of the supplied table list. Implement this
 * adapter against the existing AST ledger/RPC. Idempotency is required because
 * a client can retry a milestone claim after a network timeout.
 */
export interface AstWalletAdapter {
  awardAst(input: {
    userId: string;
    amount: number;
    idempotencyKey: string;
  }): Promise<number>;
  getBalance?(userId: string): Promise<number>;
  subscribeBalance?(
    userId: string,
    onBalanceChanged: (balance: number) => void,
  ): () => void;
}

export type MilestoneRewards = Readonly<Record<DailyMilestone, number>>;

export type TableDefinition<
  Row,
  RequiredInsert extends keyof Row = never,
> = {
  Row: Row;
  Insert: Pick<Row, RequiredInsert> & Partial<Omit<Row, RequiredInsert>>;
  Update: Partial<Row>;
  Relationships: [];
};

export interface Database {
  public: {
    Tables: {
      assignments: TableDefinition<
        Assignment,
        'teacher_id' | 'class_id' | 'title' | 'assign_type'
      >;
      questions: TableDefinition<
        Question,
        | 'assignment_id'
        | 'question_text'
        | 'options'
        | 'correct_option'
        | 'order_num'
      >;
      submissions: TableDefinition<
        Submission,
        | 'assignment_id'
        | 'student_id'
        | 'score'
        | 'total_questions'
        | 'answers_payload'
      >;
      daily_quests: TableDefinition<DailyQuest, 'title' | 'points_reward'>;
      user_daily_progress: TableDefinition<
        UserDailyProgress,
        'user_id' | 'date'
      >;
      user_quest_logs: TableDefinition<
        UserQuestLog,
        'user_id' | 'quest_id' | 'date'
      >;
      users: TableDefinition<UserProfile, 'id'>;
    };
    Views: Record<string, never>;
    Functions: {
      submit_assignment_and_reward: {
        Args: {
          p_assignment_id: string;
          p_student_id: string;
          p_score: number;
          p_total_questions: number;
          p_answers: Json;
        };
        Returns: Json;
      };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}
