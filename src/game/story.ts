import { NPCS, TREASURES } from './world';

const INTRO =
  '어느 날, 작은 고양이 한 마리가 낯선 마당에 나타났어요. 이 마당 곳곳에는 새로운 친구들과 반짝이는 보물이 숨어있대요...';

export function buildStoryLog(metNpcIds: string[], collectedTreasureIds: number[]): string[] {
  const entries: string[] = [INTRO];

  for (const npc of NPCS) {
    if (metNpcIds.includes(npc.id)) {
      entries.push(`${npc.name}와 친구가 되었어요! "${npc.greeting}"`);
    }
  }

  if (collectedTreasureIds.length > 0) {
    entries.push(`반짝이는 보물을 ${collectedTreasureIds.length}/${TREASURES.length}개 찾았어요.`);
  }

  if (collectedTreasureIds.length === TREASURES.length) {
    entries.push('모든 보물을 찾아 고양이가 예쁜 리본을 갖게 되었어요! 마당의 모든 비밀을 풀었어요 🎉');
  }

  return entries;
}
