# 달빛장터 — Tripo 3D 에셋 프롬프트

Tripo(텍스트/이미지 → 3D)로 에셋을 만들 때 쓰는 프롬프트 모음입니다.
Tripo는 영어 프롬프트가 가장 안정적이므로 프롬프트는 영어, 설명은 한국어로 적었습니다.

## 0. 작업 방식 (2D 게임에 쓰는 법)

지금 게임은 2D입니다. Tripo로 만든 3D 모델은 이렇게 씁니다.

1. 모델 생성 → GLB로 내려받기
2. Blender(또는 Godot 3D 씬)에서 **같은 카메라**로 렌더링
   - 정면 살짝 위에서 내려보는 각도 (카메라 X축 회전 약 −20°, 직교(Orthographic) 카메라)
   - 배경 투명 PNG, 조명은 위쪽 따뜻한 주황 키 라이트 + 약한 남색 보조광
3. PNG를 `assets/textures/`에 넣고 현재 도형 그리기를 스프라이트로 교체
   - 캐릭터는 대기/걷기/앉기/먹기 포즈를 각각 렌더링 (Tripo 리깅·애니메이션 기능 사용 가능)

> 모든 에셋은 아래 **공통 스타일**을 붙여서 생성해야 한 게임처럼 보입니다.
> 특정 게임·브랜드·캐릭터 이름은 프롬프트에 넣지 마세요 (저작권).

## 1. 공통 스타일 (모든 프롬프트 끝에 붙이기)

```
stylized low-poly game asset, cute but not childish, soft rounded shapes, chunky proportions,
hand-painted texture look, warm Korean night market atmosphere, orange lantern light,
clean readable silhouette for mobile game, single object, centered, no background
```

### 네거티브 프롬프트 (지원되는 경우)

```
photorealistic, realistic skin, horror, gore, text, watermark, logo, brand name,
pixel art, voxel, overly detailed, noisy texture, multiple objects, cluttered, broken mesh
```

### 색 기준 (게임 UI와 맞추기)
- 밤 배경: 남색 #171A23 / 포인트 주황 #FFB45C / 산호 #E97858 / 성공 초록 #65C99A / 크림 #FFF5E9
- 포차 천막: 주황 #E8742E + 노랑 줄무늬 #F7C04A

---

## 2. 내 포차 (가장 중요)

### 2-1. 포장마차 외관 (천막 + 입구)
```
Korean pojangmacha street food tent, bright orange tarp tent with yellow striped valance,
clear plastic curtain flaps at the entrance, warm light glowing from inside, string of round light bulbs,
small wooden sign board on top, front view
```

### 2-2. ㄱ자 바 테이블 (L자 카운터)
```
L-shaped wooden bar counter for a small Korean street pub, long straight section with a shorter section
turning toward the viewer on the right, warm honey-colored wood top, dark brown plank front panel,
brass foot rail, slightly worn edges
```

### 2-3. 바 의자 / 플라스틱 의자
```
round red plastic stool used at Korean street food stalls, simple four legs, slightly glossy
```
```
round wooden bar stool with metal legs, padded red seat
```

### 2-4. 화구 (철판 그릴)
```
small gas grill station for a Korean street food stall, black iron griddle with two round burners,
blue gas flames, metal frame, a few grill marks
```

### 2-5. 서빙대 (완성 음식 놓는 곳)
```
stainless steel pass shelf for a small restaurant kitchen, long low counter with white plate spots,
heat lamp above, clean
```

### 2-6. 술 냉장고 + 생맥주 탭
```
small glass-door drink refrigerator filled with green soju bottles, white makgeolli bottles and beer bottles,
cool blue inner light, rounded corners
```
```
single draft beer tap tower, chrome finish, black handle, drip tray
```

### 2-7. 뒷벽 메뉴판
```
hanging wooden menu tag for a Korean street pub, cream paper on a wooden board, blank area for text,
string hanger, slightly tilted
```

---

## 3. 사장님 (플레이어 캐릭터)

```
cute chibi Korean street food chef, young adult, red headband, white t-shirt, navy blue apron,
short dark hair, friendly smile, holding a small round serving tray, full body, T-pose ready for rigging
```
포즈 추가: `walking pose`, `holding tray with both hands`, `flipping skewers on a grill`

---

## 4. 손님 (일반 4종)

```
cute chibi Korean office worker, white shirt, loose navy tie, tired but kind face, small briefcase,
full body, T-pose
```
```
cute chibi Korean high school student, green hoodie, baseball cap, small backpack, cheerful face,
full body, T-pose
```
```
cute chibi Korean family trio, mother, father and small child holding hands, casual clothes,
warm colors, full body
```
```
cute chibi tourist, wide straw sun hat, camera hanging on neck, colorful casual outfit, excited face,
full body, T-pose
```
앉은 포즈: 각 프롬프트 끝에 `sitting on a stool, hands on the table` 추가

## 5. 특별 손님 4종

```
cute chibi food critic, round black glasses, beret, dark turtleneck, small notebook and pen,
serious expression, full body
```
```
group of three cute chibi Korean office coworkers celebrating after work, raising glasses,
ties loosened, happy faces, sitting together
```
```
cute chibi tipsy office worker, red cheeks, necktie tied around forehead, sleepy happy face,
holding a small green bottle, full body
```
```
cute chibi social media influencer, pink outfit, holding a smartphone for a selfie, ring light clip,
bright smile, full body
```

---

## 6. 경쟁 노점 가게 정면 (5곳)

공통 앞부분:
```
small Korean night market storefront, front view, striped awning, glowing neon sign board (blank),
open counter window with warm light, owner silhouette inside,
```
뒤에 하나씩 붙이기:
- 분식집: `pink and orange theme, tteokbokki pan and fried snacks on the counter`
- 음료 가게: `teal and white theme, lemonade and bubble tea cups on the counter`
- 호떡집: `pink and cream theme, sweet pancakes and ice cream on the counter`
- 꼬치 라이벌: `red and charcoal theme, flaming skewer grill, smoke`
- 국숫집: `beige and brown theme, big noodle pot with steam, old traditional look`

## 7. 거리 소품

```
blue metal drum barrel used as a standing table at a Korean street market, round top, a few dents
```
```
red Korean traditional lantern (cheongsachorong style), glowing from inside, hanging hook
```
```
string of colorful round light bulbs hanging between two poles, warm glow
```
```
small wooden bench for a night market, simple slats, warm wood
```

---

## 8. 음식 · 음료 (아이콘용, 각각 단독 생성)

공통 뒷부분: `, served on a small white plate, appetizing, cute stylized food, top three-quarter view`

| 메뉴 | 프롬프트 |
|---|---|
| 닭꼬치 | `Korean chicken skewer with glossy sweet soy glaze and green onion pieces` |
| 삼겹살 꼬치 | `grilled pork belly skewer, crispy edges, sesame seeds` |
| 어묵탕 | `Korean fish cake soup in a small bowl, skewered fish cakes, clear broth, steam` |
| 계란말이 | `Korean rolled omelette slices, yellow with green and orange vegetable bits` |
| 해물파전 | `Korean seafood green onion pancake, golden crispy, squid and shrimp visible` |
| 떡볶이 | `spicy red rice cakes tteokbokki with fish cake, glossy sauce` |
| 튀김 | `assorted Korean fried snacks, golden batter` |
| 호떡 | `Korean sweet pancake hotteok, golden, cut open with brown sugar filling` |

음료 (공통 뒷부분: `, single glass, condensation drops, cute stylized`):

| 메뉴 | 프롬프트 |
|---|---|
| 생맥주 | `mug of draft beer with thick white foam` |
| 소맥 | `Korean beer mixed with soju in a small beer glass, golden with light foam` |
| 막걸리 | `Korean makgeolli in a shallow metal bowl, milky white` |
| 하이볼 | `whisky highball in a tall glass with ice and lemon slice` |
| 사이다 | `clear lemon-lime soda in a glass with bubbles and ice` |

---

## 9. 장식 (구매 아이템)

```
cute potted flowers in a terracotta pot, pink and yellow blooms
```
```
small pink neon sign on a pole, glowing, blank sign face
```
```
large round moon-shaped lamp on a tall pole, soft yellow glow
```

## 10. 이미지 → 3D 쓸 때 팁
- 컨셉 이미지를 먼저 만들 경우: 같은 공통 스타일 문장 + `front view, plain gray background, full body`
- 캐릭터는 팔을 몸에서 살짝 띄운 **T-포즈/A-포즈** 이미지가 리깅이 잘 됩니다.
- 한 번에 하나의 오브젝트만 생성하고, 크기 비율은 Blender에서 맞춥니다
  (기준: 사장님 키 = 의자 높이의 약 2.2배, 바 높이 = 사장님 허리).
