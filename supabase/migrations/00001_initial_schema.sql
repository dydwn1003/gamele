-- =====================================================================
-- 뭐하지 (What To Do Today) — 초기 스키마
-- Supabase CLI: `supabase db push` 또는 `supabase migration up`
-- =====================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "postgis" WITH SCHEMA extensions;

SET search_path = public, extensions;

-- ---------------------------------------------------------------------
-- 1. Enum 타입
-- ---------------------------------------------------------------------
CREATE TYPE companion_type AS ENUM ('SOLO', 'COUPLE', 'FRIEND', 'FAMILY');
CREATE TYPE indoor_outdoor_type AS ENUM ('INDOOR', 'OUTDOOR', 'MIXED');
CREATE TYPE data_source_type AS ENUM ('TOUR_API', 'SEOUL_DATA', 'KAKAO', 'MANUAL');

-- ---------------------------------------------------------------------
-- 2. 장소 Master (places)
-- ---------------------------------------------------------------------
CREATE TABLE public.places (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL, -- FOOD, CAFE, BAR, EXHIBITION, PARK, POPUP, ACTIVITY
    subcategory VARCHAR(50),
    description TEXT,
    address TEXT NOT NULL,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    phone VARCHAR(50),
    website_url TEXT,
    image_urls TEXT[] DEFAULT '{}',
    price_min INT DEFAULT 0,
    price_max INT DEFAULT 0,
    duration_minutes INT DEFAULT 60,
    indoor_outdoor indoor_outdoor_type DEFAULT 'INDOOR',
    tags VARCHAR(50)[] DEFAULT '{}',
    rating NUMERIC(2, 1) DEFAULT 0.0,
    review_count INT DEFAULT 0,
    opening_hours JSONB DEFAULT '{}'::jsonb, -- {"mon": {"open": "10:00", "close": "22:00"}}
    reservation_required BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE, -- 90일 미검증 시 FALSE (4.3 Staleness)
    source data_source_type NOT NULL,
    source_id VARCHAR(255) NOT NULL,
    last_verified_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_source_place UNIQUE (source, source_id)
);

-- ---------------------------------------------------------------------
-- 3. 실시간 행사/팝업 (events)
-- ---------------------------------------------------------------------
CREATE TABLE public.events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    place_id UUID REFERENCES public.places(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    price INT DEFAULT 0,
    reservation_url TEXT,
    image_url TEXT,
    source data_source_type NOT NULL,
    source_id VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_source_event UNIQUE (source, source_id)
);

-- ---------------------------------------------------------------------
-- 4. 사용자 선호도 (user_preferences)
-- ---------------------------------------------------------------------
CREATE TABLE public.user_preferences (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    preferred_categories VARCHAR(50)[] DEFAULT '{}',
    preferred_budget_max INT DEFAULT 50000,
    preferred_companions companion_type[] DEFAULT '{}',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 5. 추천 플랜 (plans)
-- ---------------------------------------------------------------------
CREATE TABLE public.plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- 비회원 허용
    session_id VARCHAR(255),                                   -- 비회원 식별자
    title VARCHAR(255),
    companion companion_type NOT NULL,
    total_budget INT NOT NULL,
    total_duration_minutes INT NOT NULL,
    total_cost INT NOT NULL,
    total_distance_meters INT NOT NULL,
    area_name VARCHAR(100) NOT NULL,
    plan_type VARCHAR(20) NOT NULL, -- BEST, NOVELTY, CHEAP
    ai_summary TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 6. 추천 플랜 세부 항목 (plan_items)
-- ---------------------------------------------------------------------
CREATE TABLE public.plan_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id UUID REFERENCES public.plans(id) ON DELETE CASCADE,
    place_id UUID REFERENCES public.places(id) ON DELETE RESTRICT,
    sequence INT NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    estimated_cost INT DEFAULT 0,
    travel_minutes_from_previous INT DEFAULT 0,
    travel_distance_meters INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 7. 사용자 피드백 (user_feedback)
-- ---------------------------------------------------------------------
CREATE TABLE public.user_feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id UUID REFERENCES public.plans(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    session_id VARCHAR(255),
    rating VARCHAR(10) NOT NULL CHECK (rating IN ('LIKE', 'NEUTRAL', 'DISLIKE')),
    best_place_id UUID REFERENCES public.places(id),
    next_preference VARCHAR(50), -- MORE_ACTIVE, CHEAPER, QUIETER
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 인덱스
-- ---------------------------------------------------------------------
CREATE INDEX idx_places_geo ON public.places USING GIST (location);
CREATE INDEX idx_places_category ON public.places (category);
CREATE INDEX idx_places_active ON public.places (is_active);
CREATE INDEX idx_events_dates ON public.events (start_at, end_at);
CREATE INDEX idx_plans_user_session ON public.plans (user_id, session_id);
CREATE INDEX idx_plan_items_plan ON public.plan_items (plan_id, sequence);

-- updated_at 자동 갱신
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_places_updated_at
    BEFORE UPDATE ON public.places
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
ALTER TABLE public.places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plan_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_feedback ENABLE ROW LEVEL SECURITY;

-- 비회원 세션 식별: 앱이 모든 요청에 `x-session-id` 헤더를 붙인다.
-- 명세의 `session_id IS NOT NULL` 조건은 모든 비회원 플랜을 누구나 읽을 수 있게 되므로,
-- 요청 헤더의 세션 ID와 일치하는 행만 읽을 수 있도록 강화했다.
CREATE OR REPLACE FUNCTION public.request_session_id()
RETURNS TEXT LANGUAGE sql STABLE AS $$
    SELECT NULLIF(current_setting('request.headers', true)::json ->> 'x-session-id', '');
$$;

-- 장소 및 이벤트: 누구나 조회
CREATE POLICY "Places are viewable by everyone"
    ON public.places FOR SELECT USING (true);
CREATE POLICY "Events are viewable by everyone"
    ON public.events FOR SELECT USING (true);

-- 사용자 선호도: 본인만
CREATE POLICY "Users manage their own preferences"
    ON public.user_preferences FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 플랜: 본인(회원) 또는 동일 세션(비회원)
CREATE POLICY "Users can insert their own plans"
    ON public.plans FOR INSERT WITH CHECK (
        (user_id IS NULL OR auth.uid() = user_id)
    );
CREATE POLICY "Users can view their own plans"
    ON public.plans FOR SELECT USING (
        (user_id IS NOT NULL AND auth.uid() = user_id)
        OR (session_id IS NOT NULL AND session_id = public.request_session_id())
    );

-- 플랜 항목: 볼 수 있는 플랜의 항목만
CREATE POLICY "Plan items viewable with plan"
    ON public.plan_items FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.plans p WHERE p.id = plan_id)
    );
CREATE POLICY "Plan items insertable with plan"
    ON public.plan_items FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.plans p WHERE p.id = plan_id)
    );

-- 피드백: 누구나 작성
CREATE POLICY "Users can insert feedback"
    ON public.user_feedback FOR INSERT WITH CHECK (true);

-- ---------------------------------------------------------------------
-- RPC: 주변 N m 이내 장소 조회
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_places_near_location(
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    radius_meters INT DEFAULT 3000,
    category_filter TEXT[] DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    name VARCHAR,
    category VARCHAR,
    subcategory VARCHAR,
    description TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    phone VARCHAR,
    website_url TEXT,
    image_urls TEXT[],
    price_min INT,
    price_max INT,
    duration_minutes INT,
    indoor_outdoor indoor_outdoor_type,
    tags VARCHAR[],
    rating NUMERIC,
    review_count INT,
    opening_hours JSONB,
    reservation_required BOOLEAN,
    source data_source_type,
    is_event BOOLEAN,
    created_at TIMESTAMPTZ,
    distance_meters DOUBLE PRECISION
)
LANGUAGE sql STABLE
SET search_path = public, extensions
AS $$
    SELECT
        p.id, p.name, p.category, p.subcategory, p.description, p.address,
        p.latitude, p.longitude, p.phone, p.website_url, p.image_urls,
        p.price_min, p.price_max, p.duration_minutes, p.indoor_outdoor,
        p.tags, p.rating, p.review_count, p.opening_hours,
        p.reservation_required, p.source,
        EXISTS (
            SELECT 1 FROM public.events e
            WHERE e.place_id = p.id AND NOW() BETWEEN e.start_at AND e.end_at
        ) AS is_event,
        p.created_at,
        ST_Distance(p.location, ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography) AS distance_meters
    FROM public.places p
    WHERE p.is_active
      AND ST_DWithin(p.location, ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography, radius_meters)
      AND (category_filter IS NULL OR p.category = ANY (category_filter))
    ORDER BY distance_meters ASC
    LIMIT 400;
$$;

GRANT EXECUTE ON FUNCTION public.get_places_near_location(DOUBLE PRECISION, DOUBLE PRECISION, INT, TEXT[])
    TO anon, authenticated;
