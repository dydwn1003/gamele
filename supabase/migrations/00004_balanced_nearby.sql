-- 데이터가 많아지면 가까운 식당·카페만으로 결과가 가득 차서 공원·전시가 빠진다.
-- 카테고리별로 가까운 순 최대 70곳씩 돌려주도록 바꾼다. (시그니처·반환 형식은 그대로)
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
    WITH origin AS (
        SELECT ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography AS g
    ),
    near AS (
        SELECT
            p.*,
            ST_Distance(p.location, o.g) AS dist,
            ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY ST_Distance(p.location, o.g)) AS rn
        FROM public.places p, origin o
        WHERE p.is_active
          AND ST_DWithin(p.location, o.g, radius_meters)
          AND (category_filter IS NULL OR p.category = ANY (category_filter))
    )
    SELECT
        n.id, n.name, n.category, n.subcategory, n.description, n.address,
        n.latitude, n.longitude, n.phone, n.website_url, n.image_urls,
        n.price_min, n.price_max, n.duration_minutes, n.indoor_outdoor,
        n.tags, n.rating, n.review_count, n.opening_hours,
        n.reservation_required, n.source,
        EXISTS (
            SELECT 1 FROM public.events e
            WHERE e.place_id = n.id AND NOW() BETWEEN e.start_at AND e.end_at
        ) AS is_event,
        n.created_at,
        n.dist AS distance_meters
    FROM near n
    WHERE n.rn <= 70
    ORDER BY n.dist ASC;
$$;
