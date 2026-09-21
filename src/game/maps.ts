export const MAP_NAMES: Record<number, string> = {
  1: '초원 지대',
  2: '이끼 호수',
  3: '비전 유적',
  4: '화염 협곡',
  5: '빙하 설원',
  6: '심연 폐허',
};

export function mapName(chapter: number): string {
  return MAP_NAMES[chapter] ?? `${chapter}번 지역`;
}
