import { useEffect, useRef } from 'react';

const FRAME_MS = 1000 / 60;
const MAX_DT = 0.05;

export function useGameLoop(onTick: (dtSeconds: number) => void, active: boolean) {
  const callbackRef = useRef(onTick);
  callbackRef.current = onTick;

  useEffect(() => {
    if (!active) return undefined;

    let lastTime = Date.now();
    const interval = setInterval(() => {
      const now = Date.now();
      const dt = Math.min(MAX_DT, (now - lastTime) / 1000);
      lastTime = now;
      callbackRef.current(dt);
    }, FRAME_MS);

    return () => clearInterval(interval);
  }, [active]);
}
