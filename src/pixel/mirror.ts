/**
 * Sprites are authored as one left half per row (columns 0..n, where the
 * last column is the vertical centerline) and mirrored here to build the
 * full symmetric row. This keeps hand-authored pixel art short and
 * guarantees every row ends up the same width.
 */
export function mirrorRow(leftHalf: string): string {
  const tail = leftHalf.slice(0, -1).split('').reverse().join('');
  return leftHalf + tail;
}

export function mirrorRows(leftHalves: string[]): string[] {
  return leftHalves.map(mirrorRow);
}
