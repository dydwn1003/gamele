import React, { useMemo } from 'react';
import { StyleSheet, View } from 'react-native';

import type { PixelSprite } from './types';

interface Props {
  sprite: PixelSprite;
  pixelSize: number;
}

interface Cell {
  x: number;
  y: number;
  color: string;
}

function buildCells(sprite: PixelSprite): Cell[] {
  const cells: Cell[] = [];
  sprite.rows.forEach((row, y) => {
    for (let x = 0; x < row.length; x += 1) {
      const char = row[x];
      if (char === '.') continue;
      const color = sprite.palette[char];
      if (color) cells.push({ x, y, color });
    }
  });
  return cells;
}

export function PixelGrid({ sprite, pixelSize }: Props) {
  const cells = useMemo(() => buildCells(sprite), [sprite]);
  const width = (sprite.rows[0]?.length ?? 0) * pixelSize;
  const height = sprite.rows.length * pixelSize;

  return (
    <View style={{ width, height }}>
      {cells.map((cell) => (
        <View
          key={`${cell.x}-${cell.y}`}
          style={[
            styles.pixel,
            {
              left: cell.x * pixelSize,
              top: cell.y * pixelSize,
              width: pixelSize,
              height: pixelSize,
              backgroundColor: cell.color,
            },
          ]}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  pixel: {
    position: 'absolute',
  },
});
