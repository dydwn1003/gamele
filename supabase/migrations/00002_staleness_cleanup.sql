-- 명세 4.3 폐업/만료 데이터 Clean-up Policy
--  - events: end_at < NOW() 인 레코드 삭제 (매일 자정)
--  - places: last_verified_at 90일 경과 시 추천 후보에서 제외 (is_active = false)

CREATE OR REPLACE FUNCTION public.cleanup_stale_data()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    deleted_events INT;
    deactivated_places INT;
BEGIN
    DELETE FROM public.events WHERE end_at < NOW();
    GET DIAGNOSTICS deleted_events = ROW_COUNT;

    UPDATE public.places
       SET is_active = FALSE
     WHERE is_active
       AND last_verified_at < NOW() - INTERVAL '90 days'
       AND source <> 'MANUAL';
    GET DIAGNOSTICS deactivated_places = ROW_COUNT;

    RETURN jsonb_build_object('deleted_events', deleted_events, 'deactivated_places', deactivated_places);
END;
$$;

REVOKE ALL ON FUNCTION public.cleanup_stale_data() FROM PUBLIC, anon, authenticated;

-- pg_cron (Supabase Dashboard > Database > Extensions 에서 pg_cron 활성화 후)
-- 매일 자정(KST = 15:00 UTC) 실행
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron') THEN
        CREATE EXTENSION IF NOT EXISTS pg_cron;
        PERFORM cron.schedule('mwohaji-cleanup', '0 15 * * *', 'SELECT public.cleanup_stale_data();');
    END IF;
END;
$$;
