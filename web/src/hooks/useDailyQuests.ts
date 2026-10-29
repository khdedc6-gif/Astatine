import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { createAssignmentService } from '../services/assignmentService';
import type {
  AstWalletAdapter,
  DailyMilestone,
  DailyProgressSnapshot,
  Database,
  MilestoneRewards,
} from '../types/assignment';

const dailyProgressCache = new Map<string, DailyProgressSnapshot>();

export interface UseDailyQuestsOptions {
  client: SupabaseClient<Database>;
  wallet: AstWalletAdapter;
  milestoneRewards: MilestoneRewards;
  userId: string | null;
  initialAstBalance?: number;
}

export function useDailyQuests({
  client,
  wallet,
  milestoneRewards,
  userId,
  initialAstBalance,
}: UseDailyQuestsOptions) {
  const service = useMemo(
    () => createAssignmentService(client, wallet, { milestoneRewards }),
    [client, wallet, milestoneRewards],
  );
  const requestSequence = useRef(0);
  const [snapshot, setSnapshot] = useState<DailyProgressSnapshot | null>(
    () => (userId ? dailyProgressCache.get(userId) ?? null : null),
  );
  const [astBalance, setAstBalance] = useState<number | null>(
    initialAstBalance ?? null,
  );
  const [loading, setLoading] = useState(() =>
    userId ? !dailyProgressCache.has(userId) : false,
  );
  const [error, setError] = useState<Error | null>(null);

  const refresh = useCallback(async () => {
    const requestId = ++requestSequence.current;
    if (!userId) {
      setSnapshot(null);
      setLoading(false);
      setError(null);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const result = await service.fetchDailyProgress(userId);
      if (requestId !== requestSequence.current) return;
      dailyProgressCache.set(userId, result);
      setSnapshot(result);
    } catch (cause) {
      if (requestId === requestSequence.current) {
        setError(cause instanceof Error ? cause : new Error(String(cause)));
      }
    } finally {
      if (requestId === requestSequence.current) setLoading(false);
    }
  }, [service, userId]);

  useEffect(() => {
    void refresh();
    if (!userId) return;

    const channel = client
      .channel(`daily-quests:${userId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_daily_progress',
          filter: `user_id=eq.${userId}`,
        },
        () => void refresh(),
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_quest_logs',
          filter: `user_id=eq.${userId}`,
        },
        () => void refresh(),
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'daily_quests' },
        () => void refresh(),
      )
      .subscribe();

    const unsubscribeWallet = wallet.subscribeBalance?.(userId, setAstBalance);
    if (wallet.getBalance) {
      void wallet
        .getBalance(userId)
        .then(setAstBalance)
        .catch((cause: unknown) => {
          setError(cause instanceof Error ? cause : new Error(String(cause)));
        });
    }

    return () => {
      requestSequence.current += 1;
      unsubscribeWallet?.();
      void client.removeChannel(channel);
    };
  }, [client, refresh, userId, wallet]);

  const completeDailyQuest = useCallback(
    async (questId: string) => {
      if (!userId) throw new Error('A signed-in user is required.');
      if (!snapshot) throw new Error('Daily progress has not loaded yet.');
      if (snapshot.completedQuestIds.includes(questId)) return snapshot;

      const quest = snapshot.quests.find((item) => item.id === questId);
      if (!quest) throw new Error('This quest is unavailable for your role.');

      const previous = snapshot;
      const optimistic: DailyProgressSnapshot = {
        ...snapshot,
        progress: {
          ...snapshot.progress,
          total_points: Math.min(100, snapshot.progress.total_points + quest.points_reward),
        },
        completedQuestIds: [...snapshot.completedQuestIds, questId],
      };
      dailyProgressCache.set(userId, optimistic);
      setSnapshot(optimistic);
      setError(null);

      try {
        const result = await service.completeDailyQuest(userId, questId);
        dailyProgressCache.set(userId, result);
        setSnapshot(result);
        return result;
      } catch (cause) {
        dailyProgressCache.set(userId, previous);
        setSnapshot(previous);
        const normalized =
          cause instanceof Error ? cause : new Error(String(cause));
        setError(normalized);
        throw normalized;
      }
    },
    [service, snapshot, userId],
  );

  const claimMilestoneReward = useCallback(
    async (milestone: DailyMilestone) => {
      if (!userId) throw new Error('A signed-in user is required.');
      if (!snapshot) throw new Error('Daily progress has not loaded yet.');
      if (snapshot.progress.total_points < milestone) {
        throw new Error(`Reach ${milestone} points before claiming this reward.`);
      }
      if (snapshot.progress.claimed_milestones.includes(milestone)) {
        throw new Error('This milestone has already been claimed.');
      }

      const previousSnapshot = snapshot;
      const previousBalance = astBalance;
      const optimistic: DailyProgressSnapshot = {
        ...snapshot,
        progress: {
          ...snapshot.progress,
          claimed_milestones: [
            ...snapshot.progress.claimed_milestones,
            milestone,
          ].sort((left, right) => left - right),
        },
      };
      dailyProgressCache.set(userId, optimistic);
      setSnapshot(optimistic);
      const configuredReward = milestoneRewards[milestone];
      if (astBalance !== null) setAstBalance(astBalance + configuredReward);
      setError(null);

      try {
        const balance = await service.claimMilestoneReward(userId, milestone);
        setAstBalance(balance);
        const updated = await service.fetchDailyProgress(userId);
        dailyProgressCache.set(userId, updated);
        setSnapshot(updated);
        return balance;
      } catch (cause) {
        dailyProgressCache.set(userId, previousSnapshot);
        setSnapshot(previousSnapshot);
        setAstBalance(previousBalance);
        const normalized =
          cause instanceof Error ? cause : new Error(String(cause));
        setError(normalized);
        throw normalized;
      }
    },
    [astBalance, milestoneRewards, service, snapshot, userId],
  );

  return {
    progress: snapshot?.progress ?? null,
    quests: snapshot?.quests ?? [],
    completedQuestIds: snapshot?.completedQuestIds ?? [],
    astBalance,
    loading,
    error,
    refresh,
    completeDailyQuest,
    claimMilestoneReward,
  };
}
