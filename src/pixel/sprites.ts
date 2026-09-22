import { mirrorRows } from './mirror';
import type { PixelSprite } from './types';

/**
 * Every animal/item below is authored as its LEFT half only (one string per
 * row, the last character is the vertical centerline) and mirrored into a
 * full symmetric sprite by `mirrorRows`. Palette keys map a character to a
 * color; '.' is always transparent.
 */

function buildSprite(leftHalves: string[], palette: Record<string, string>): PixelSprite {
  const rows = mirrorRows(leftHalves);
  const width = rows[0].length;
  rows.forEach((row, i) => {
    if (row.length !== width) {
      throw new Error(`Sprite row ${i} has width ${row.length}, expected ${width}`);
    }
  });
  return { rows, palette };
}

export const CAT_SPRITE = buildSprite(
  [
    '..k....',
    '.kok...',
    '.koookk',
    'koooook',
    'kokoooo',
    'koooooo',
    'koooopp',
    '.kooook',
    '.kwwwww',
    'kowwwww',
    'kowwwww',
    '.kkwwkk',
    '..kkkkk',
  ],
  { k: '#3a2a1d', o: '#f6a94a', w: '#fff8ec', p: '#ff9db0' },
);

export const DOG_SPRITE = buildSprite(
  [
    '.......',
    '..k....',
    '.kbk...',
    'kbbbbbk',
    'kbkbbbb',
    'kbbbbbb',
    'kbbbbkk',
    '.kbbbbk',
    '.kwwwww',
    'kbwwwww',
    'kbwwwww',
    '.kkwwkk',
    '..kkkkk',
  ],
  { k: '#2b1d12', b: '#b17a44', w: '#fff8ec' },
);

export const HAMSTER_SPRITE = buildSprite(
  [
    '.......',
    '..hp...',
    '.hhhhh.',
    'khhhhhk',
    'khkhhhh',
    'khhhhhh',
    'khhhhpp',
    '.khhhhk',
    '.khwwww',
    'khwwwww',
    'khwwwww',
    '.kkwwkk',
    '..kkkkk',
  ],
  { k: '#5c4632', h: '#eec488', w: '#fff8ec', p: '#ffb6c9' },
);

export const FISH_SPRITE = buildSprite(
  ['.....', '..k..', '.kfk.', 'kffff', 'kffff', 'kwfff', '.kfff', '..kff', '...kk'],
  { k: '#1d3a52', f: '#4fa3d1', w: '#ffffff' },
);

export const BONE_SPRITE = buildSprite(
  ['.....', 'n....', 'nk...', 'nkk..', '.nnnn', 'nkk..', 'nk...', 'n....', '.....'],
  { k: '#d8c48a', n: '#fff9e6' },
);

export const SEED_SPRITE = buildSprite(
  ['.....', '..s..', '.sss.', 'sssss', 'sssss', 'sssss', '.sss.', '..s..', '.....'],
  { s: '#caa25e' },
);

export const ROCK_SPRITE = buildSprite(
  ['.....', '..r..', '.rrr.', 'rrrrk', 'rrrrr', 'krrrr', '.rrr.', '..r..', '.....'],
  { r: '#9a9a9a', k: '#6e6e6e' },
);
