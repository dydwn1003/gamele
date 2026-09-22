export type PixelPalette = Record<string, string>;

export interface PixelSprite {
  rows: string[];
  palette: PixelPalette;
}

export function spriteWidth(sprite: PixelSprite): number {
  return sprite.rows[0]?.length ?? 0;
}

export function spriteHeight(sprite: PixelSprite): number {
  return sprite.rows.length;
}
