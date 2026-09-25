-- 네이버 수집 장소의 영업시간을 세부 업종별 '보통' 영업시간으로 다듬는다.
-- 네이버 검색 API는 영업시간을 주지 않으므로 추정치이며, 앱에서도 '예상'으로 표시한다.
-- (ingest-naver-places의 TYPICAL_HOURS와 같은 규칙, 위에서부터 처음 맞는 규칙)
UPDATE public.places p
   SET opening_hours = jsonb_build_object('daily', jsonb_build_object('open', r.open, 'close', r.close))
  FROM (
    SELECT id,
           CASE
             WHEN category = 'FOOD' AND t ~ '브런치' THEN '09:00|17:00'
             WHEN category = 'FOOD' AND t ~ '(오마카세|스시|초밥)' THEN '12:00|22:00'
             WHEN category = 'FOOD' AND t ~ '(고기|육류|삼겹|갈비|곱창|구이)' THEN '11:30|23:00'
             WHEN category = 'CAFE' AND t ~ '(베이커리|제과|베이글|도넛)' THEN '08:00|21:00'
             WHEN category = 'BAR' AND t ~ '(와인|칵테일|위스키|바\(BAR\))' THEN '18:00|02:00'
             WHEN category = 'BAR' AND t ~ '(이자카야|포장마차|포차|호프|요리주점)' THEN '17:00|02:00'
             WHEN category = 'ACTIVITY' AND t ~ '방탈출' THEN '10:00|24:00'
             WHEN category = 'ACTIVITY' AND t ~ '(보드게임|보드카페|만화카페|만화방)' THEN '11:00|24:00'
             WHEN category = 'ACTIVITY' AND t ~ '노래' THEN '13:00|02:00'
             WHEN category = 'ACTIVITY' AND t ~ '(셀프사진|포토부스|스티커사진)' THEN '10:00|24:00'
             WHEN category = 'ACTIVITY' AND t ~ '(사진관|포토스튜디오)' THEN '11:00|20:00'
             WHEN category = 'ACTIVITY' AND t ~ '(공방|공예|클래스|도자기|향수|캔들)' THEN '11:00|21:00'
             WHEN category = 'ACTIVITY' AND t ~ '볼링' THEN '11:00|24:00'
             WHEN category = 'ACTIVITY' AND t ~ '(클라이밍|볼더링)' THEN '10:00|23:00'
             WHEN category = 'EXHIBITION' AND t ~ '(미술관|박물관|기념관)' THEN '10:00|18:00'
             WHEN category = 'EXHIBITION' AND t ~ '갤러리' THEN '11:00|19:00'
           END AS hours
      FROM (SELECT id, category::text AS category, coalesce(description, '') || ' ' || name AS t
              FROM public.places
             WHERE source = 'NAVER') s
  ) m
  CROSS JOIN LATERAL (SELECT split_part(m.hours, '|', 1) AS open, split_part(m.hours, '|', 2) AS close) r
 WHERE p.id = m.id AND m.hours IS NOT NULL;
