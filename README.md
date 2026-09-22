# 도트 펫 캐치 (gamele)

고양이, 강아지, 햄스터 중 하나를 골라 하늘에서 떨어지는 간식을 받아먹는
2D 도트(픽셀 아트) 아케이드 게임입니다.

## 스택

- Expo (React Native, TypeScript) — 모바일/웹 공용
- `@react-native-async-storage/async-storage` — 최고 점수 로컬 저장
- `expo-linear-gradient` — 배경 그라디언트
- 순수 React state + `setInterval` 기반 게임 루프 (별도 게임 엔진/캔버스 라이브러리 없이 View만으로 구현)

## 게임 방식

1. 홈 화면에서 고양이/강아지/햄스터 중 하나를 선택하고 시작합니다.
2. 화면을 좌우로 드래그해 캐릭터를 움직여 떨어지는 아이템을 받습니다.
   - 캐릭터가 좋아하는 간식(고양이=생선, 강아지=뼈다귀, 햄스터=씨앗)을 받으면 +10점
   - 다른 동물의 간식을 받으면 +2점
   - 돌(장애물)을 받으면 목숨 1개 감소
3. 목숨 3개를 모두 잃으면 게임 종료, 점수와 최고 기록이 표시됩니다.
4. 시간이 지날수록 아이템이 더 빠르고 자주 떨어집니다.

## 코드 구조

- `src/pixel/` — 도트 스프라이트 시스템. `mirror.ts`가 좌우 대칭 스프라이트를
  절반만 손으로 작성해 자동으로 완성해줍니다. `sprites.ts`에 고양이/강아지/
  햄스터/생선/뼈다귀/씨앗/돌 도트 데이터가 있고, `PixelGrid.tsx`가 이를
  실제 픽셀 사각형들로 렌더링합니다.
- `src/game/` — 게임 규칙. `types.ts`(타입), `engine.ts`(순수 함수 기반
  상태 전이: 스폰/이동/충돌/점수), `useGameLoop.ts`(60fps 틱 훅),
  `highScore.ts`(AsyncStorage 저장/불러오기).
- `src/screens/` — `HomeScreen`(캐릭터 선택), `GameScreen`(플레이 화면,
  드래그 컨트롤 + HUD), `GameOverScreen`(결과).
- `App.tsx` — 홈/플레이/게임오버 화면 전환을 담당하는 최상위 상태 머신.

## 실행하기

```bash
npm install
npx expo start
```

- `w`를 눌러 웹으로 빠르게 확인 가능
- 실기기/에뮬레이터는 Expo Go 또는 `npx expo run:android` / `run:ios` 사용
