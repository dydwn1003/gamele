export interface ChapterPalette {
  body: string;
  accent: string;
  glow: string;
}

export const CHAPTER_PALETTES: ChapterPalette[] = [
  { body: '#6fcf73', accent: '#3f8f45', glow: '#bdf2c0' }, // 1 forest
  { body: '#5b9bd5', accent: '#2f5fa0', glow: '#bfe0ff' }, // 2 lake
  { body: '#a56bd6', accent: '#6b3fa0', glow: '#e6cdfb' }, // 3 arcane
  { body: '#e08a3c', accent: '#a85a1a', glow: '#ffd9ad' }, // 4 volcano
  { body: '#5cd6d0', accent: '#2a8a86', glow: '#c6fbf7' }, // 5 glacier
  { body: '#e0555f', accent: '#a02a34', glow: '#ffc9cd' }, // 6 abyss
];

export function paletteForChapter(chapter: number): ChapterPalette {
  const idx = Math.min(Math.max(chapter, 1), CHAPTER_PALETTES.length) - 1;
  return CHAPTER_PALETTES[idx];
}

export function chapterForStage(stageId: number): number {
  return Math.ceil(stageId / 10);
}
