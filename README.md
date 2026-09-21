# 영웅 키우기 (gamele)

자동전투 방치형 RPG. 솔로 플레이 + Google 로그인 기반 랭킹.

## 스택

- Expo (React Native, TypeScript) — 모바일 앱(Android/iOS), 향후 EAS Build로 스토어 배포
- Zustand + AsyncStorage — 로컬 게임 저장(재화, 레벨, 장비, 스테이지 진행도)
- Firebase Auth(Google 로그인) + Firestore(랭킹) — `src/services/firebase.ts`, `src/services/googleAuth.ts`, `src/services/leaderboard.ts`

## 게임 루프

- `src/game/`: 스테이지 60개(`stages.ts`), 캐릭터 성장 공식(`hero.ts`), 자동전투 시뮬레이션(`combat.ts`), 장비 등급/스탯(`equipment.ts`), 뽑기 확률(`gacha.ts`)
- `src/state/useGameStore.ts`: 전투 실행, 뽑기, 장착, 오프라인(자리비움) 보상 계산 등 핵심 액션
- 화면: 홈 / 전투(자동전투 토글) / 뽑기(장비 가챠) / 랭킹 — `src/screens/`

## 실행하기

```bash
npm install
npx expo start
```

- `w`를 눌러 웹으로 빠르게 UI 확인 가능 (실제 배포 타깃은 모바일)
- 실기기/에뮬레이터 테스트는 Expo Go 또는 `npx expo run:android` / `run:ios` (Mac 필요) 사용

## 실서비스 전 반드시 채워야 할 것

`app.json`의 `expo.extra` 값은 전부 `REPLACE_ME` 플레이스홀더입니다. 이 값들이 없으면
로그인/랭킹 화면이 "설정 필요" 안내만 보여주고 동작하지 않습니다.

1. **Firebase 프로젝트 생성** → Authentication에서 Google 로그인 활성화, Firestore 생성
   - `app.json` → `expo.extra.firebase`에 프로젝트 설정값 입력
2. **Google Cloud OAuth 클라이언트** (Firebase 콘솔의 Google 로그인 활성화 시 자동 생성되는
   웹 클라이언트 ID 포함, 안드로이드/iOS용 클라이언트는 Google Cloud Console에서 별도 생성)
   - `app.json` → `expo.extra.googleAuth`에 각 플랫폼 client ID 입력
   - 안드로이드는 SHA-1 지문 등록 필요 (`eas credentials`로 확인 가능)
3. **Firestore 보안 규칙**: `leaderboard` 컬렉션은 문서 소유자(uid)만 자신의 랭킹을
   쓸 수 있도록 규칙을 설정하세요 (현재 코드는 클라이언트에서 자기 점수만 `setDoc`).

## 아직 스텁(Stub)인 기능

결제/광고는 실제 계정·심사가 필요해 지금은 껍데기만 만들어뒀습니다. 실제 연동 전까지는
버튼을 눌러도 콘솔 경고만 뜨고 즉시 보상을 지급하는 목업입니다.

- `src/services/ads.ts` — 리워드 광고. `react-native-google-mobile-ads` + AdMob 앱/광고 단위 ID 필요
- `src/services/iap.ts` — 젬 패키지 구매. RevenueCat 또는 `react-native-iap` + 스토어 인앱상품 등록 필요

두 기능 모두 네이티브 모듈이라 Expo Go에서는 동작하지 않고, EAS 개발 빌드(dev client)부터
테스트 가능합니다.

## 다음 단계 제안

- EAS Build로 개발 클라이언트 만들어서 실기기에서 로그인/전투 루프 확인
- AdMob·IAP 연동 후 실제 보상 지급 로직 연결
- 장비 강화/합성처럼 "돈 쓸 이유"를 늘리는 시스템 추가
- 친구 초대 보상 등 바이럴 유도 기능
