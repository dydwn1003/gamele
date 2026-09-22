import { BONE_SPRITE, CAT_SPRITE, DOG_SPRITE, FISH_SPRITE, HAMSTER_SPRITE, ROCK_SPRITE, SEED_SPRITE } from './sprites';
import type { PixelSprite } from './types';
import type { ItemKind, Species } from '../game/types';

export const SPECIES_SPRITE: Record<Species, PixelSprite> = {
  cat: CAT_SPRITE,
  dog: DOG_SPRITE,
  hamster: HAMSTER_SPRITE,
};

export const ITEM_SPRITE: Record<ItemKind, PixelSprite> = {
  fish: FISH_SPRITE,
  bone: BONE_SPRITE,
  seed: SEED_SPRITE,
  rock: ROCK_SPRITE,
};
