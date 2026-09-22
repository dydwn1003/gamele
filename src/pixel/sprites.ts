import { mirrorRows } from './mirror';
import type { PixelSprite } from './types';

function buildSprite(rows: string[], palette: Record<string, string>): PixelSprite {
  const width = rows[0].length;
  rows.forEach((row, i) => {
    if (row.length !== width) {
      throw new Error(`Sprite row ${i} has width ${row.length}, expected ${width}`);
    }
  });
  return { rows, palette };
}

function buildMirroredSprite(leftHalves: string[], palette: Record<string, string>): PixelSprite {
  return buildSprite(mirrorRows(leftHalves), palette);
}

/**
 * Side-view chibi cat, facing right: big round head + eye on top of a
 * smaller pudgy body with a curled tail. The head/body/tail (top 13 rows)
 * stay fixed while the two leg rows swap between CAT_WALK_1 and
 * CAT_WALK_2 to make a simple diagonal-gait walk cycle. Flip horizontally
 * (scaleX: -1) to face left.
 */
const CAT_BODY = [
  '............k....k..',
  '...........kok..kok.',
  '..........koookooook',
  '.........koooooooook',
  '.........koooooehook',
  '.........koooooeoook',
  '.........kooopoooowk',
  '.........kooooowwwpk',
  '.........kkkkkkkkkkk',
  '...ko.kooooooooooook',
  '..kokkoooooooooooook',
  '.kok.kwwwwwwwwwwwwwk',
  '......kkkkkkkkkkkkkk',
];

const CAT_PALETTE = {
  k: '#5b3d28',
  o: '#ffcd9a',
  w: '#fff3e0',
  p: '#ff9fb0',
  e: '#241a12',
  h: '#ffffff',
};

const LEG_A = ['.......kw......kw...', '.......kk......kk...'];
const LEG_B = ['........kw...kw.....', '........kk...kk.....'];

export const CAT_WALK_1 = buildSprite([...CAT_BODY, ...LEG_A], CAT_PALETTE);
export const CAT_WALK_2 = buildSprite([...CAT_BODY, ...LEG_B], CAT_PALETTE);
export const CAT_IDLE = CAT_WALK_1;

export const FISH_SPRITE = buildSprite(
  ['.....', '..k..', '.kfk.', 'kffff', 'kffff', 'kwfff', '.kfff', '..kff', '...kk'],
  { k: '#1d3a52', f: '#4fa3d1', w: '#ffffff' },
);

const FLOWER_LEFT = ['..p', 'p.c', '..p'];

export const FLOWER_PINK = buildMirroredSprite(FLOWER_LEFT, { p: '#ff8fb3', c: '#ffe066' });
export const FLOWER_WHITE = buildMirroredSprite(FLOWER_LEFT, { p: '#ffffff', c: '#ffc94d' });
export const FLOWER_PURPLE = buildMirroredSprite(FLOWER_LEFT, { p: '#c199ff', c: '#ffe066' });

export const BUSH_SPRITE = buildMirroredSprite(['..b.', '.bbb', 'bbbb', '.bbb', '..b.'], {
  b: '#5f9c4c',
});
