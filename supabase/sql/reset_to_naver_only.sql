-- 네이버 수집 데이터만 남기고 기존 장소(관광공사·소상공인·샘플)를 지운다.
-- ingest-naver-places 로 네이버 데이터를 먼저 채운 뒤 SQL Editor 에서 실행한다.

-- 1) 기존 출처의 행사 삭제
DELETE FROM public.events
 WHERE place_id IN (SELECT id FROM public.places WHERE source <> 'NAVER');

-- 2) 저장된 플랜이 참조하지 않는 기존 장소 삭제
DELETE FROM public.places p
 WHERE p.source <> 'NAVER'
   AND NOT EXISTS (SELECT 1 FROM public.plan_items i WHERE i.place_id = p.id)
   AND NOT EXISTS (SELECT 1 FROM public.user_feedback f WHERE f.best_place_id = p.id);

-- 3) 플랜이 참조하고 있어 지울 수 없는 장소는 추천 후보에서만 제외
UPDATE public.places SET is_active = FALSE WHERE source <> 'NAVER';

-- 확인
SELECT source, category, count(*) FROM public.places WHERE is_active GROUP BY 1, 2 ORDER BY 1, 3 DESC;
