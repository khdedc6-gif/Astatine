import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { createAssignmentService } from '../services/assignmentService';
import type {
  Assignment,
  AssignmentTargetMatcher,
  AstWalletAdapter,
  Database,
  MilestoneRewards,
} from '../types/assignment';

const assignmentCache = new Map<string, Assignment[]>();

export interface UseAssignmentsOptions {
  client: SupabaseClient<Database>;
  wallet: AstWalletAdapter;
  milestoneRewards: MilestoneRewards;
  classId: string | null;
  studentId: string | null;
  isAssignmentForStudent?: AssignmentTargetMatcher;
}

export function useAssignments({
  client,
  wallet,
  milestoneRewards,
  classId,
  studentId,
  isAssignmentForStudent,
}: UseAssignmentsOptions) {
  const service = useMemo(
    () =>
      createAssignmentService(client, wallet, {
        milestoneRewards,
        isAssignmentForStudent,
      }),
    [client, wallet, milestoneRewards, isAssignmentForStudent],
  );
  const cacheKey = `${classId ?? 'no-class'}:${studentId ?? 'no-student'}`;
  const requestSequence = useRef(0);
  const [assignments, setAssignments] = useState<Assignment[]>(
    () => assignmentCache.get(cacheKey) ?? [],
  );
  const [astBalance, setAstBalance] = useState<number | null>(null);
  const [loading, setLoading] = useState(() => !assignmentCache.has(cacheKey));
  const [submittingId, setSubmittingId] = useState<string | null>(null);
  const [error, setError] = useState<Error | null>(null);

  const refresh = useCallback(async () => {
    const requestId = ++requestSequence.current;
    if (!classId || !studentId) {
      assignmentCache.set(cacheKey, []);
      setAssignments([]);
      setLoading(false);
      setError(null);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const result = await service.fetchStudentAssignments(classId, studentId);
      if (requestId !== requestSequence.current) return;
      assignmentCache.set(cacheKey, result);
      setAssignments(result);
    } catch (cause) {
      if (requestId === requestSequence.current) {
        setError(cause instanceof Error ? cause : new Error(String(cause)));
      }
    } finally {
      if (requestId === requestSequence.current) setLoading(false);
    }
  }, [cacheKey, classId, service, studentId]);

  useEffect(() => {
    void refresh();
    if (!classId || !studentId) return;

    const channel = client
      .channel(`student-assignments:${classId}:${studentId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'assignments',
          filter: `class_id=eq.${classId}`,
        },
        () => void refresh(),
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'submissions',
          filter: `student_id=eq.${studentId}`,
        },
        () => void refresh(),
      )
      .subscribe();

    return () => {
      requestSequence.current += 1;
      void client.removeChannel(channel);
    };
  }, [classId, client, refresh, studentId]);

  const submitAssignment = useCallback(
    async (input: {
      assignmentId: string;
      score: number;
      totalQuestions: number;
      answers: Record<string, string>;
    }) => {
      if (!studentId) throw new Error('A signed-in student is required.');
      const previousAssignments = assignments;
      setSubmittingId(input.assignmentId);
      setError(null);

      // Hide the submitted card immediately; restore it if the RPC rejects.
      const optimisticAssignments = assignments.filter(
        (assignment) => assignment.id !== input.assignmentId,
      );
      assignmentCache.set(cacheKey, optimisticAssignments);
      setAssignments(optimisticAssignments);

      try {
        const balance = await service.submitAssignment(
          input.assignmentId,
          studentId,
          input.score,
          input.totalQuestions,
          input.answers,
        );
        setAstBalance(balance);
        void refresh();
        return balance;
      } catch (cause) {
        assignmentCache.set(cacheKey, previousAssignments);
        setAssignments(previousAssignments);
        const normalized =
          cause instanceof Error ? cause : new Error(String(cause));
        setError(normalized);
        throw normalized;
      } finally {
        setSubmittingId(null);
      }
    },
    [assignments, cacheKey, refresh, service, studentId],
  );

  return {
    assignments,
    astBalance,
    loading,
    submittingId,
    error,
    refresh,
    submitAssignment,
  };
}
